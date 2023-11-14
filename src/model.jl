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
    # K_rp = sets.rp_time_steps
    # K_A = sets.rp_partitions_assets
    K_F = sets.rp_partitions_flows
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
            params.rp_weight[rp] * params.flows_variable_cost[f] * flow[f, rp, B_flow]
            for f ∈ F, rp ∈ RP, B_flow ∈ K_F[(f, rp)]
        )
    )

    # Objective function
    @objective(
        model,
        Min,
        assets_investment_cost + flows_investment_cost + flows_variable_cost
    )

    # Constraints
    # Computes the duration of the `block` that is within the `period`, and
    # multiply by the resolution of the representative period `rp`.
    # It is equivalent to finding the indexes of these values in the matrix.
    function duration(B1, B2, rp)
        return length(B1 ∩ B2) * params.rp_resolution[rp]
    end

    @expression(
        model,
        incoming_flow[a ∈ A, rp ∈ RP, B ∈ P[(a, rp)]],
        sum(
            duration(B, B_flow, rp) * flow[f, rp, B_flow] for
            f in F, B_flow ∈ sets.rp_partitions_flows[(f, rp)] if
            f[2] == a && B_flow[end] ≥ B[1] && B[end] ≥ B_flow[1]
        )
    )
    @expression(
        model,
        outgoing_flow[a ∈ A, rp ∈ RP, B ∈ P[(a, rp)]],
        sum(
            duration(B, B_flow, rp) * flow[f, rp, B_flow] for
            f in F, B_flow ∈ sets.rp_partitions_flows[(f, rp)] if
            f[1] == a && B_flow[end] ≥ B[1] && B[end] ≥ B_flow[1]
        )
    )
    @expression(
        model,
        incoming_flow_w_efficiency[a ∈ A, rp ∈ RP, B ∈ P[(a, rp)]],
        sum(
            duration(B, B_flow, rp) * flow[f, rp, B_flow] * params.flows_efficiency[f] for
            f in F, B_flow ∈ sets.rp_partitions_flows[(f, rp)] if
            f[2] == a && B_flow[end] ≥ B[1] && B[end] ≥ B_flow[1]
        )
    )
    @expression(
        model,
        outgoing_flow_w_efficiency[a ∈ A, rp ∈ RP, B ∈ P[(a, rp)]],
        sum(
            duration(B, B_flow, rp) * flow[f, rp, B_flow] / params.flows_efficiency[f] for
            f in F, B_flow ∈ sets.rp_partitions_flows[(f, rp)] if
            f[1] == a && B_flow[end] ≥ B[1] && B[end] ≥ B_flow[1]
        )
    )

    @expression(
        model,
        assets_profile_sum[a ∈ A, rp ∈ RP, B ∈ P[(a, rp)]],
        sum(get(params.assets_profile, (a, rp, k), 1.0) for k ∈ B)
    )

    @expression(
        model,
        assets_profile_times_capacity[a ∈ A, rp ∈ RP, B ∈ P[(a, rp)]],
        assets_profile_sum[a, rp, B] * (
            params.assets_init_capacity[a] +
            (a ∈ Ai ? (params.assets_unit_capacity[a] * assets_investment[a]) : 0.0)
        )
    )

    @expression(
        model,
        energy_limit[a ∈ As∩Ai],
        params.energy_to_power_ratio[a] *
        params.assets_unit_capacity[a] *
        assets_investment[a]
    )

    @expression(
        model,
        storage_inflows[a ∈ As, rp ∈ RP, T ∈ P[(a, rp)]],
        sum(get(params.assets_profile, (a, rp, k), 0.0) for k ∈ T) *
        (params.initial_storage_capacity[a] + (a ∈ Ai ? energy_limit[a] : 0.0))
    )

    # Balance equations
    # - consumer balance equation
    @constraint(
        model,
        consumer_balance[a ∈ Ac, rp ∈ RP, B ∈ P[(a, rp)]],
        incoming_flow[(a, rp, B)] - outgoing_flow[(a, rp, B)] ==
        assets_profile_sum[a, rp, B] * params.peak_demand[a]
    )

    # - storage balance equation
    @constraint(
        model,
        storage_balance[a ∈ As, rp ∈ RP, (k, B) ∈ enumerate(P[(a, rp)])],
        storage_level[a, rp, B] ==
        (k > 1 ? storage_level[a, rp, P[(a, rp)][k-1]] : params.initial_storage_level[a]) +
        storage_inflows[a, rp, B] +
        incoming_flow_w_efficiency[(a, rp, B)] - outgoing_flow_w_efficiency[(a, rp, B)]
    )

    # - hub balance equation
    @constraint(
        model,
        hub_balance[a ∈ Ah, rp ∈ RP, B ∈ P[(a, rp)]],
        incoming_flow[(a, rp, B)] == outgoing_flow[(a, rp, B)]
    )

    # - conversion balance equation
    @constraint(
        model,
        conversion_balance[a ∈ Acv, rp ∈ RP, B ∈ P[(a, rp)]],
        incoming_flow_w_efficiency[(a, rp, B)] == outgoing_flow_w_efficiency[(a, rp, B)]
    )

    # Constraints that define bounds of flows related to energy assets A
    # - overall output flows
    @constraint(
        model,
        overall_output_flows[a ∈ Acv∪As∪Ap, rp ∈ RP, B ∈ P[(a, rp)]],
        outgoing_flow[(a, rp, B)] ≤ assets_profile_times_capacity[a, rp, B]
    )
    #
    # # - overall input flows
    @constraint(
        model,
        overall_input_flows[a ∈ As, rp ∈ RP, B ∈ P[(a, rp)]],
        incoming_flow[(a, rp, B)] ≤ assets_profile_times_capacity[a, rp, B]
    )
    #
    # # - upper bound associated with asset
    @constraint(
        model,
        upper_bound_asset[
            a ∈ A,
            f ∈ F,
            rp ∈ RP,
            B ∈ P[(a, rp)];
            !(a ∈ Ah ∪ Ac) && f[1] == a && f ∉ Ft,
        ],
        sum(
            duration(B, B_flow, rp) * flow[f, rp, B_flow] for
            B_flow ∈ sets.rp_partitions_flows[(f, rp)] if
            B_flow[end] ≥ B[1] && B[end] ≥ B_flow[1]
        ) ≤ assets_profile_times_capacity[a, rp, B]
    )

    # Define lower bounds for flows that are not transport assets
    for f ∈ F, rp ∈ RP, B_flow ∈ K_F[(f, rp)]
        if f ∉ Ft
            set_lower_bound(flow[f, rp, B_flow], 0.0)
        end
    end

    # Constraints that define bounds for a transport flow Ft
    @expression(
        model,
        upper_bound_transport_flow[f ∈ F, rp ∈ RP, B_flow ∈ K_F[(f, rp)]],
        get(params.flows_profile, (f, rp, B_flow), 1.0) * (
            params.flows_init_capacity[f] +
            (f ∈ Fi ? (params.flows_export_capacity[f] * flows_investment[f]) : 0.0)
        )
    )
    @constraint(
        model,
        transport_flow_upper_bound[f ∈ Ft, rp ∈ RP, B_flow ∈ K_F[(f, rp)]],
        flow[f, rp, B_flow] ≤ upper_bound_transport_flow[f, rp, B_flow]
    )
    @expression(
        model,
        lower_bound_transport_flow[f ∈ F, rp ∈ RP, B_flow ∈ K_F[(f, rp)]],
        get(params.flows_profile, (f, rp, B_flow), 1.0) * (
            params.flows_init_capacity[f] +
            (f ∈ Fi ? (params.flows_import_capacity[f] * flows_investment[f]) : 0.0)
        )
    )
    @constraint(
        model,
        transport_flow_lower_bound[f ∈ Ft, rp ∈ RP, B_flow ∈ K_F[(f, rp)]],
        flow[f, rp, B_flow] ≥ -lower_bound_transport_flow[f, rp, B_flow]
    )

    # Extra constraints
    # - upper bound constraints for storage level
    @constraint(
        model,
        upper_bound_for_storage_level[a ∈ As, rp ∈ RP, B ∈ P[(a, rp)]],
        storage_level[a, rp, B] ≤
        params.initial_storage_capacity[a] + (a ∈ Ai ? energy_limit[a] : 0.0)
    )

    # - cycling condition for storage level
    for a ∈ As, rp ∈ RP
        set_lower_bound(
            storage_level[a, rp, P[(a, rp)][end]],
            params.initial_storage_level[a],
        )
    end

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
