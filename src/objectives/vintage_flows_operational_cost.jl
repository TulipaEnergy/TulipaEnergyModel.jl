function _add_vintage_flows_operational_cost!(
    connection,
    model,
    expressions,
    objective_expr,
    lambda,
)
    expr = expressions[:vintage_flows_operational_cost_per_scenario]

    @expression(
        model,
        vintage_flows_operational_cost,
        sum(row.probability * expr.expressions[:cost][row.id::Int64] for row in expr.indices),
    )
    _add_to_objective!(
        connection,
        objective_expr,
        "vintage_flows_operational_cost",
        (1 - lambda) * vintage_flows_operational_cost,
    )

    return nothing
end
