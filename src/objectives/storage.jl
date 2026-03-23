function _add_storage_costs!(connection, model, variables, expressions, objective_expr)
    assets_investment_energy = variables[:assets_investment_energy]
    expr_available_energy_units_simple_method = expressions[:available_energy_units_simple_method]

    indices = DuckDB.query(
        connection,
        "SELECT
            var.id,
            obj.weight_for_asset_investment_discount
                * obj.investment_cost_storage_energy
                * obj.capacity_storage_energy
                AS cost,
        FROM var_assets_investment_energy AS var
        LEFT JOIN t_objective_assets as obj
            ON var.asset = obj.asset
            AND var.milestone_year = obj.milestone_year
        ORDER BY var.id
        ",
    )

    storage_assets_energy_investment_cost = @expression(
        model,
        sum(
            row.cost * assets_investment_energy for
            (row, assets_investment_energy) in zip(indices, assets_investment_energy.container)
        )
    )
    _add_to_objective!(
        connection,
        model,
        objective_expr,
        "storage_assets_energy_investment_cost",
        storage_assets_energy_investment_cost,
    )

    indices = DuckDB.query(
        connection,
        "SELECT
            expr.id,
            obj.weight_for_operation_discounts
                * asset_commission.fixed_cost_storage_energy
                * obj.capacity_storage_energy
                AS cost,
        FROM expr_available_energy_units_simple_method AS expr
        LEFT JOIN asset_commission
            ON expr.asset = asset_commission.asset
            AND expr.commission_year = asset_commission.commission_year
        LEFT JOIN t_objective_assets as obj
            ON expr.asset = obj.asset
            AND expr.milestone_year = obj.milestone_year
        ORDER BY expr.id
        ",
    )

    storage_assets_energy_fixed_cost = @expression(
        model,
        sum(
            row.cost * expr_avail for (row, expr_avail) in
            zip(indices, expr_available_energy_units_simple_method.expressions[:energy])
        )
    )
    _add_to_objective!(
        connection,
        model,
        objective_expr,
        "storage_assets_energy_fixed_cost",
        storage_assets_energy_fixed_cost,
    )

    return
end
