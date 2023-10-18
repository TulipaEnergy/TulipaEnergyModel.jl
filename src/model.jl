export optimise_investments

"""
    optimise_investments(graph, params, sets; verbose = false)

Create and solve the model using the `graph` structure, the parameters and sets.
"""
function optimise_investments(graph, params, sets; verbose = false)
    # Sets unpacking
    A = sets.assets
    Ac = sets.assets_consumer
    # Ap = sets.assets_producer
    Ai = sets.assets_investment
    F = [(A[e.src], A[e.dst]) for e in edges(graph)]
    K = sets.time_steps
    RP = sets.rep_periods

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
            params.investment_cost[a] * params.unit_capacity[a] * v_investment[a] for
            a in Ai
        )
    )

    e_variable_cost = @expression(
        model,
        sum(
            params.rep_weight[rp] * params.variable_cost[a] * v_flow[f, rp, k] for
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
        params.profile[a, rp, k] * params.peak_demand[a]
    )

    # - maximum generation
    @constraint(
        model,
        c_max_prod[a in Ai, f in F, rp in RP, k in K; f[1] == a],
        v_flow[f, rp, k] <=
        get(params.profile, (a, rp, k), 1.0) *
        (params.init_capacity[a] + params.unit_capacity[a] * v_investment[a])
    )

    # print lp file
    write_to_file(model, "model.lp")

    # Solve model
    optimize!(model)

    # Check solution status
    if termination_status(model) != OPTIMAL
        @warn("Model status different from optimal")
        return nothing
    end

    return (
        objective_value = objective_value(model),
        v_flow = value.(v_flow),
        v_investment = value.(v_investment),
    )
end
