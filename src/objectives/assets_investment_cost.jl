function _add_assets_investment_cost!(connection, model, variables, objective_expr)
    assets_investment = variables[:assets_investment]

    costs = _query_costs(
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

    @expression(
        model,
        assets_investment_cost,
        _cost_weighted_sum(costs, assets_investment.container)
    )
    _add_to_objective!(connection, objective_expr, "assets_investment_cost", assets_investment_cost)

    return
end
