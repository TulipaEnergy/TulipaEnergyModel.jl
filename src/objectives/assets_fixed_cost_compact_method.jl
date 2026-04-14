function _add_assets_fixed_cost_compact_method!(
    connection,
    model,
    expressions,
    objective_expr,
    lambda,
)
    expr_available_asset_units_compact_method = expressions[:available_asset_units_compact_method]

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

    @expression(
        model,
        assets_fixed_cost_compact_method,
        sum(
            row.cost * expr_avail for (row, expr_avail) in
            zip(indices, expr_available_asset_units_compact_method.expressions[:assets])
        )
    )
    _add_to_objective!(
        connection,
        objective_expr,
        "assets_fixed_cost_compact_method",
        (1 - lambda) * assets_fixed_cost_compact_method,
    )

    return
end
