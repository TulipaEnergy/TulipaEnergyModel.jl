function _add_flows_investment_cost!(connection, model, variables, objective_expr, lambda)
    flows_investment = variables[:flows_investment]

    indices = DuckDB.query(
        connection,
        "SELECT
            var.id,
            obj.weight_for_flow_investment_discount
                * obj.investment_cost
                * obj.capacity
                AS cost,
        FROM var_flows_investment AS var
        LEFT JOIN t_objective_flows as obj
            ON var.from_asset = obj.from_asset
            AND var.to_asset = obj.to_asset
            AND var.milestone_year = obj.milestone_year
        ORDER BY var.id
        ",
    )

    @expression(
        model,
        flows_investment_cost,
        sum(
            row.cost * flow_investment for
            (row, flow_investment) in zip(indices, flows_investment.container)
        )
    )
    _add_to_objective!(
        connection,
        objective_expr,
        "flows_investment_cost",
        (1 - lambda) * flows_investment_cost,
    )

    return
end
