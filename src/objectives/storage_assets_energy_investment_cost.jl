function _add_storage_assets_energy_investment_cost!(
    connection,
    model,
    variables,
    objective_expr,
    lambda,
)
    assets_investment_energy = variables[:assets_investment_energy]

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
        (1 - lambda) * storage_assets_energy_investment_cost,
    )

    return
end
