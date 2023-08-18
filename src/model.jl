export optimise_investments

"""
    optimise_investments

This is a doc for optimise_investments.
It should probably be improved.
"""
function optimise_investments(params, sets; verbose = false)
    # Sets unpacking
    A = sets.s_assets
    Ac = sets.s_assets_consumer
    # Ap = sets.s_assets_producer
    Ai = sets.s_assets_investment
    F = sets.s_combinations_of_flows
    K = sets.s_time_steps
    RP = sets.s_representative_periods

    # Model
    model = Model(HiGHS.Optimizer)
    set_attribute(model, "output_flag", verbose)

    # Variables
    @variable(model, 0 ≤ v_flow[F, RP, K])         #flow from asset a to asset aa [MW]
    @variable(model, 0 ≤ v_investment[Ai], Int)  #number of installed asset units [N]

    # Expressions
    e_investment_cost = @expression(
        model,
        sum(
            params.p_investment_cost[a] * params.p_unit_capacity[a] * v_investment[a]
            for a in Ai
        )
    )

    e_variable_cost = @expression(
        model,
        sum(
            params.p_rp_weight[rp] * params.p_variable_cost[a] * v_flow[f, rp, k] for
            a in A, f in F, rp in RP, k in K if f[1] == a
        )
    )

    # Objective function
    @objective(model, Min, e_investment_cost + e_variable_cost)

    # Constraints
    # - balance equation
    @constraint(
        model,
        c_balance[a in Ac, rp in RP, k in K],
        sum(v_flow[f, rp, k] for f in F if f[2] == a) ==
        params.p_profile[a, rp, k] * params.p_peak_demand[a]
    )

    # - maximum generation
    @constraint(
        model,
        c_max_prod[a in Ai, f in F, rp in RP, k in K; f[1] == a],
        v_flow[f, rp, k] <=
        get(params.p_profile, (a, rp, k), 1.0) *
        (params.p_init_capacity[a] + params.p_unit_capacity[a] * v_investment[a])
    )

    # print lp file
    write_to_file(model, "model.lp")

    # Solve model
    optimize!(model)

    return (
        objective_value = objective_value(model),
        v_flow = value.(v_flow),
        v_investment = value.(v_investment),
    )
end
