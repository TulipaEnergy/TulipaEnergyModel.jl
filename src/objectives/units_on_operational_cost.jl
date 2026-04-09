function _add_units_on_operational_cost!(connection, model, expressions, objective_expr, lambda)
    expr = expressions[:units_on_operational_cost_per_scenario]

    @expression(
        model,
        units_on_operational_cost,
        sum(row.probability * expr.expressions[:cost][row.id::Int64] for row in expr.indices),
    )
    _add_to_objective!(
        connection,
        objective_expr,
        "units_on_operational_cost",
        (1 - lambda) * units_on_operational_cost,
    )

    return nothing
end
