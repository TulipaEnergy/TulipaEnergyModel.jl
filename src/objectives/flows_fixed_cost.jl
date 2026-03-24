function _add_flows_fixed_cost!(connection, model, expressions, objective_expr)
    expr_available_flow_units_simple_method = expressions[:available_flow_units_simple_method]

    indices = DuckDB.query(
        connection,
        "SELECT
            expr.id,
            obj.weight_for_operation_discounts
                * flow_commission.fixed_cost / 2
                * obj.capacity
                AS cost,
        FROM expr_available_flow_units_simple_method AS expr
        LEFT JOIN flow_commission
            ON expr.from_asset = flow_commission.from_asset
            AND expr.to_asset = flow_commission.to_asset
            AND expr.commission_year = flow_commission.commission_year
        LEFT JOIN t_objective_flows as obj
            ON expr.from_asset = obj.from_asset
            AND expr.to_asset = obj.to_asset
            AND expr.milestone_year = obj.milestone_year
        ORDER BY expr.id
        ",
    )

    flows_fixed_cost = @expression(
        model,
        sum(
            row.cost * (avail_export_unit + avail_import_unit) for
            (row, avail_export_unit, avail_import_unit) in zip(
                indices,
                expr_available_flow_units_simple_method.expressions[:export],
                expr_available_flow_units_simple_method.expressions[:import],
            )
        )
    )
    _add_to_objective!(connection, model, objective_expr, "flows_fixed_cost", flows_fixed_cost)

    return
end
