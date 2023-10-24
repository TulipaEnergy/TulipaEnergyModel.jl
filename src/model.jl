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
    K   = sets.time_steps
    RP  = sets.rep_periods

    # Model
    model = Model(HiGHS.Optimizer)
    set_attribute(model, "output_flag", verbose)

    # Variables
    @variable(model, flow[F, RP, K])         #flow from asset a to asset aa [MW]
    @variable(model, 0 ≤ assets_investment[Ai], Int)  #number of installed asset units [N]
    @variable(model, 0 ≤ flows_investment[Fi], Int)
    @variable(model, 0 ≤ storage_level[As, RP, K])

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
            params.rep_weight[rp] * params.flows_variable_cost[f] * flow[f, rp, k] for
            f ∈ F, rp ∈ RP, k ∈ K
        )
    )

    # Objective function
    @objective(
        model,
        Min,
        assets_investment_cost + flows_investment_cost + flows_variable_cost
    )

    # Constraints

    # Balance equations
    # - consumer balance equation
    @constraint(
        model,
        c_consumer_balance[a ∈ Ac, rp ∈ RP, k ∈ K],
        sum(flow[f, rp, k] for f ∈ F if f[2] == a) -
        sum(flow[f, rp, k] for f ∈ F if f[1] == a) ==
        get(params.assets_profile, (a, rp, k), 1.0) * params.peak_demand[a]
    )

    # - storage balance equation
    # TODO: Add p^{inflow}
    # TODO: Fix the initial storage_level
    @constraint(
        model,
        c_storage_balance[a ∈ As, rp ∈ RP, k ∈ K],
        storage_level[a, rp, k] ==
        (k ≥ 2 ? storage_level[a, rp, k-1] : 0.0) +
        sum(flow[f, rp, k] * params.flows_efficiency[f] for f ∈ F if f[2] == a) -
        sum(flow[f, rp, k] / params.flows_efficiency[f] for f ∈ F if f[1] == a)
    )

    # - hub balance equation
    @constraint(
        model,
        c_hub_balance[a ∈ Ah, rp ∈ RP, k ∈ K],
        sum(flow[f, rp, k] for f ∈ F if f[2] == a) ==
        sum(flow[f, rp, k] for f ∈ F if f[1] == a)
    )

    # - conversion balance equation
    @constraint(
        model,
        c_conversion_balance[a ∈ Acv, rp ∈ RP, k ∈ K],
        sum(flow[f, rp, k] * params.flows_efficiency[f] for f ∈ F if f[2] == a) ==
        sum(flow[f, rp, k] / params.flows_efficiency[f] for f ∈ F if f[1] == a)
    )

    # Constraints that define bounds of flows related to energy assets A
    # - overall output flows
    @constraint(
        model,
        c_overall_output_flows[a ∈ Acv∪As∪Ap, rp ∈ RP, k ∈ K],
        sum(flow[f, rp, k] for f ∈ F if f[1] == a) ≤
        get(params.assets_profile, (a, rp, k), 1.0) * (
            params.assets_init_capacity[a] +
            (a ∈ Ai ? (params.assets_unit_capacity[a] * assets_investment[a]) : 0.0)
        )
    )

    # - overall input flows
    @constraint(
        model,
        c_overall_input_flows[a ∈ As, rp ∈ RP, k ∈ K],
        sum(flow[f, rp, k] for f ∈ F if f[2] == a) ≤
        get(params.assets_profile, (a, rp, k), 1.0) * (
            params.assets_init_capacity[a] +
            (a ∈ Ai ? (params.assets_unit_capacity[a] * assets_investment[a]) : 0.0)
        )
    )

    # - upper bound associated with asset
    @constraint(
        model,
        c_upper_bound_asset[a ∈ A, f ∈ F, rp ∈ RP, k ∈ K; !(a ∈ Ah) && f[1] == a],
        flow[f, rp, k] ≤
        get(params.assets_profile, (a, rp, k), 1.0) * (
            params.assets_init_capacity[a] +
            (a ∈ Ai ? (params.assets_unit_capacity[a] * assets_investment[a]) : 0.0)
        )
    )

    # Constraints that define a lower bound for flows that are not transport assets
    @constraint(
        model,
        c_lower_bound_asset_flow[f ∈ F, rp ∈ RP, k ∈ K; f ∉ Ft],
        flow[f, rp, k] ≥ 0
    )

    # Constraints that define bounds for a transport flow Ft
    @expression(
        model,
        e_upper_bound_transport_flow[f ∈ F, rp ∈ RP, k ∈ K],
        get(params.flows_profile, (f, rp, k), 1.0) * (
            params.flows_init_capacity[f] +
            (f ∈ Fi ? (params.flows_export_capacity[f] * flows_investment[f]) : 0.0)
        )
    )
    @constraint(
        model,
        c_transport_flow_upper_bound[f ∈ Ft, rp ∈ RP, k ∈ K],
        flow[f, rp, k] ≤ e_upper_bound_transport_flow[f, rp, k]
    )
    @expression(
        model,
        e_lower_bound_transport_flow[f ∈ F, rp ∈ RP, k ∈ K],
        get(params.flows_profile, (f, rp, k), 1.0) * (
            params.flows_init_capacity[f] +
            (f ∈ Fi ? (params.flows_import_capacity[f] * flows_investment[f]) : 0.0)
        )
    )
    @constraint(
        model,
        c_transport_flow_lower_bound[f ∈ Ft, rp ∈ RP, k ∈ K],
        flow[f, rp, k] ≥ -e_lower_bound_transport_flow[f, rp, k]
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
        upper_bound_for_storage_level[a ∈ As, rp ∈ RP, k ∈ K],
        storage_level[a, rp, k] ≤
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
