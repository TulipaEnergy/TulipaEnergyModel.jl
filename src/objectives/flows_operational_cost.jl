function _add_flows_operational_cost!(connection, model, expressions, objective_expr, lambda)
    expr = expressions[:flows_operational_cost_per_scenario]

    @expression(
        model,
        flows_operational_cost,
        sum(row.probability * expr.expressions[:cost][row.id::Int64] for row in expr.indices),
    )
    _add_to_objective!(
        connection,
        objective_expr,
        "flows_operational_cost",
        (1 - lambda) * flows_operational_cost,
    )

    return nothing
end
