export create_model, solve_model

"""
    create_model(graph, params, sets; verbose = false)

Create the model using the `graph` structure, the parameters and sets.
"""

function create_model(graph, params, sets; verbose = false, write_lp_file = false)
    # Sets unpacking
    A   = sets.assets
    Ac  = sets.assets_consumer
    Ap  = sets.assets_producer
    Ai  = sets.assets_investment
    As  = sets.assets_storage
    Ah  = sets.assets_hub
    Acv = sets.assets_conversion
    F   = [(A[e.src], A[e.dst]) for e ∈ edges(graph)] # f[1] -> source, f[2] -> destination
    Fi  = [f for f ∈ F if params.flows_investable[f]]
    Ft  = [f for f ∈ F if params.flows_is_transport[f]]
    # K_rp = sets.time_steps
    # K_A = sets.time_intervals_per_asset
    K_F = sets.time_intervals_per_flow
    P = sets.constraints_time_periods
    RP = sets.rep_periods

    # Model
    model = Model(HiGHS.Optimizer)
    set_attribute(model, "output_flag", verbose)

    # Variables
    @variable(model, flow[f ∈ F, rp ∈ RP, K_F[(f, rp)]])         #flow from asset a to asset aa [MW]
    @variable(model, 0 ≤ assets_investment[Ai], Int)  #number of installed asset units [N]
    @variable(model, 0 ≤ flows_investment[Fi], Int)
    @variable(model, 0 ≤ storage_level[a ∈ As, rp ∈ RP, P[(a, rp)]])

    # TODO: Fix storage_level[As, RP, 0] = 0

    # Expressions
    assets_investment_cost = @expression(
        model,
        sum(
            params.assets_investment_cost[a] *
            params.assets_unit_capacity[a] *
            assets_investment[a] for a ∈ Ai
        )
    )

    flows_investment_cost = @expression(
        model,
        sum(
            params.flows_investment_cost[f] *
            params.flows_unit_capacity[f] *
            flows_investment[f] for f ∈ Fi
        )
    )

    flows_variable_cost = @expression(
        model,
        sum(
            params.rep_weight[rp] * params.flows_variable_cost[f] * flow[f, rp, I] for
            f ∈ F, rp ∈ RP, I ∈ K_F[(f, rp)]
        )
    )

    # Objective function
    @objective(
        model,
        Min,
        assets_investment_cost + flows_investment_cost + flows_variable_cost
    )

    # Constraints
    # Computes the duration of the `interval` that is within the `period`, and multiply by the
    # scale of the representative period `rp`.
    # It is equivalent to finding the indexes of these values in the matrix.
    function duration(T, I, rp)
        return length(T ∩ I) * params.time_scale[rp]
    end

    @expression(
        model,
        incoming_flow[a ∈ A, rp ∈ RP, T ∈ P[(a, rp)]],
        sum(
            duration(T, I, rp) * flow[f, rp, I] for
            f in F, I ∈ sets.time_intervals_per_flow[(f, rp)] if f[2] == a
        )
    )
    @expression(
        model,
        outgoing_flow[a ∈ A, rp ∈ RP, T ∈ P[(a, rp)]],
        sum(
            duration(T, I, rp) * flow[f, rp, I] for
            f in F, I ∈ sets.time_intervals_per_flow[(f, rp)] if f[1] == a
        )
    )
    @expression(
        model,
        incoming_flow_w_efficiency[a ∈ A, rp ∈ RP, T ∈ P[(a, rp)]],
        sum(
            duration(T, I, rp) * flow[f, rp, I] * params.flows_efficiency[f] for
            f in F, I ∈ sets.time_intervals_per_flow[(f, rp)] if f[2] == a
        )
    )
    @expression(
        model,
        outgoing_flow_w_efficiency[a ∈ A, rp ∈ RP, T ∈ P[(a, rp)]],
        sum(
            duration(T, I, rp) * flow[f, rp, I] / params.flows_efficiency[f] for
            f in F, I ∈ sets.time_intervals_per_flow[(f, rp)] if f[1] == a
        )
    )

    @expression(
        model,
        assets_profile_sum[a ∈ A, rp ∈ RP, T ∈ P[(a, rp)]],
        sum(get(params.assets_profile, (a, rp, k), 1.0) for k ∈ T)
    )

    @expression(
        model,
        assets_profile_times_capacity[a ∈ A, rp ∈ RP, T ∈ P[(a, rp)]],
        assets_profile_sum[a, rp, T] * (
            params.assets_init_capacity[a] +
            (a ∈ Ai ? (params.assets_unit_capacity[a] * assets_investment[a]) : 0.0)
        )
    )

    # Balance equations
    # - consumer balance equation
    @constraint(
        model,
        c_consumer_balance[a ∈ Ac, rp ∈ RP, T ∈ P[(a, rp)]],
        incoming_flow[(a, rp, T)] - outgoing_flow[(a, rp, T)] ==
        assets_profile_sum[a, rp, T] * params.peak_demand[a]
    )

    # - storage balance equation
    # TODO: Add p^{inflow}
    @constraint(
        model,
        c_storage_balance[a ∈ As, rp ∈ RP, (k, T) ∈ enumerate(P[(a, rp)])],
        storage_level[a, rp, T] ==
        (k > 1 ? storage_level[a, rp, P[(a, rp)][k-1]] : 0.0) +
        incoming_flow_w_efficiency[(a, rp, T)] - outgoing_flow_w_efficiency[(a, rp, T)]
    )

    # - hub balance equation
    @constraint(
        model,
        c_hub_balance[a ∈ Ah, rp ∈ RP, T ∈ P[(a, rp)]],
        incoming_flow[(a, rp, T)] == outgoing_flow[(a, rp, T)]
    )

    # - conversion balance equation
    @constraint(
        model,
        c_conversion_balance[a ∈ Acv, rp ∈ RP, T ∈ P[(a, rp)]],
        incoming_flow_w_efficiency[(a, rp, T)] == outgoing_flow_w_efficiency[(a, rp, T)]
    )

    # Constraints that define bounds of flows related to energy assets A
    # - overall output flows
    @constraint(
        model,
        c_overall_output_flows[a ∈ Acv∪As∪Ap, rp ∈ RP, T ∈ P[(a, rp)]],
        outgoing_flow[(a, rp, T)] ≤ assets_profile_times_capacity[a, rp, T]
    )
    #
    # # - overall input flows
    @constraint(
        model,
        c_overall_input_flows[a ∈ As, rp ∈ RP, T ∈ P[(a, rp)]],
        incoming_flow[(a, rp, T)] ≤ assets_profile_times_capacity[a, rp, T]
    )
    #
    # # - upper bound associated with asset
    @constraint(
        model,
        c_upper_bound_asset[
            a ∈ A,
            f ∈ F,
            rp ∈ RP,
            T ∈ P[(a, rp)];
            !(a ∈ Ah ∪ Ac) && f[1] == a && f ∉ Ft,
        ],
        sum(
            duration(T, I, rp) * flow[f, rp, I] for
            I ∈ sets.time_intervals_per_flow[(f, rp)]
        ) ≤ assets_profile_times_capacity[a, rp, T]
    )

    # Constraints that define a lower bound for flows that are not transport assets
    # TODO: set lower bound via JuMP API
    @constraint(
        model,
        c_lower_bound_asset_flow[f ∈ F, rp ∈ RP, I ∈ K_F[(f, rp)]; f ∉ Ft],
        flow[f, rp, I] ≥ 0
    )

    # Constraints that define bounds for a transport flow Ft
    @expression(
        model,
        e_upper_bound_transport_flow[f ∈ F, rp ∈ RP, I ∈ K_F[(f, rp)]],
        get(params.flows_profile, (f, rp, I), 1.0) * (
            params.flows_init_capacity[f] +
            (f ∈ Fi ? (params.flows_export_capacity[f] * flows_investment[f]) : 0.0)
        )
    )
    @constraint(
        model,
        c_transport_flow_upper_bound[f ∈ Ft, rp ∈ RP, I ∈ K_F[(f, rp)]],
        flow[f, rp, I] ≤ e_upper_bound_transport_flow[f, rp, I]
    )
    @expression(
        model,
        e_lower_bound_transport_flow[f ∈ F, rp ∈ RP, I ∈ K_F[(f, rp)]],
        get(params.flows_profile, (f, rp, I), 1.0) * (
            params.flows_init_capacity[f] +
            (f ∈ Fi ? (params.flows_import_capacity[f] * flows_investment[f]) : 0.0)
        )
    )
    @constraint(
        model,
        c_transport_flow_lower_bound[f ∈ Ft, rp ∈ RP, I ∈ K_F[(f, rp)]],
        flow[f, rp, I] ≥ -e_lower_bound_transport_flow[f, rp, I]
    )

    # Extra constraints
    # - upper bound constraints for storage level
    @expression(
        model,
        energy_limit[a ∈ As∩Ai],
        params.energy_to_power_ratio[a] *
        params.assets_unit_capacity[a] *
        assets_investment[a]
    )
    @constraint(
        model,
        upper_bound_for_storage_level[a ∈ As, rp ∈ RP, T ∈ P[(a, rp)]],
        storage_level[a, rp, T] ≤
        params.initial_storage_capacity[a] + (a ∈ Ai ? energy_limit[a] : 0.0)
    )

    if write_lp_file
        write_to_file(model, "model.lp")
    end

    return model
end

"""
    solve_model(model)

Solve the model.
"""
function solve_model(model)

    # Solve model
    optimize!(model)

    # Check solution status
    if termination_status(model) != OPTIMAL
        @warn("Model status different from optimal")
        return nothing
    end

    return (
        objective_value = objective_value(model),
        flow = value.(model[:flow]),
        assets_investment = value.(model[:assets_investment]),
    )
end
