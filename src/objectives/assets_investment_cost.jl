function _add_assets_investment_cost!(connection, model, variables, objective_expr)
    assets_investment = variables[:assets_investment]

    indices = DuckDB.query(
        connection,
        "SELECT
            var.id,
            obj.weight_for_asset_investment_discount
                * obj.investment_cost
                * obj.capacity
                AS cost,
        FROM var_assets_investment AS var
        LEFT JOIN t_objective_assets as obj
            ON var.asset = obj.asset
            AND var.milestone_year = obj.milestone_year
        ORDER BY var.id
        ",
    )

    assets_investment_cost = @expression(
        model,
        sum(
            row.cost * asset_investment for
            (row, asset_investment) in zip(indices, assets_investment.container)
        )
    )
    _add_to_objective!(
        connection,
        model,
        objective_expr,
        "assets_investment_cost",
        assets_investment_cost,
    )

    return
end
