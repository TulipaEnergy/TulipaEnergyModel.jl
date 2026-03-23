function _add_assets_costs!(connection, model, variables, expressions, objective_expr)
    assets_investment = variables[:assets_investment]
    expr_available_asset_units_compact_method = expressions[:available_asset_units_compact_method]
    expr_available_asset_units_simple_method = expressions[:available_asset_units_simple_method]

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

    # Select expressions for compact method
    indices = DuckDB.query(
        connection,
        "SELECT
            expr.id,
            obj.weight_for_operation_discounts
                * asset_commission.fixed_cost
                * obj.capacity
                AS cost,
        FROM expr_available_asset_units_compact_method AS expr
        LEFT JOIN asset_commission
            ON expr.asset = asset_commission.asset
            AND expr.commission_year = asset_commission.commission_year
        LEFT JOIN t_objective_assets as obj
            ON expr.asset = obj.asset
            AND expr.milestone_year = obj.milestone_year
        ORDER BY expr.id
        ",
    )

    assets_fixed_cost_compact_method = @expression(
        model,
        sum(
            row.cost * expr_avail for (row, expr_avail) in
            zip(indices, expr_available_asset_units_compact_method.expressions[:assets])
        )
    )
    _add_to_objective!(
        connection,
        model,
        objective_expr,
        "assets_fixed_cost_compact_method",
        assets_fixed_cost_compact_method,
    )

    # Select expressions for simple method
    indices = DuckDB.query(
        connection,
        "SELECT
            expr.id,
            obj.weight_for_operation_discounts
                * asset_commission.fixed_cost
                * obj.capacity
                AS cost,
        FROM expr_available_asset_units_simple_method AS expr
        LEFT JOIN asset_commission
            ON expr.asset = asset_commission.asset
            AND expr.commission_year = asset_commission.commission_year
        LEFT JOIN t_objective_assets as obj
            ON expr.asset = obj.asset
            AND expr.milestone_year = obj.milestone_year
        ORDER BY expr.id
        ",
    )

    assets_fixed_cost_simple_method = @expression(
        model,
        sum(
            row.cost * expr_avail for (row, expr_avail) in
            zip(indices, expr_available_asset_units_simple_method.expressions[:assets])
        )
    )
    _add_to_objective!(
        connection,
        model,
        objective_expr,
        "assets_fixed_cost_simple_method",
        assets_fixed_cost_simple_method,
    )

    return
end
