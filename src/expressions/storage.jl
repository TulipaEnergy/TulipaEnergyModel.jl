function add_storage_expressions!(connection, model, expressions)
    DuckDB.query(
        connection,
        "CREATE OR REPLACE TEMP SEQUENCE id START 1;
        CREATE OR REPLACE TABLE expr_available_energy_capacity_simple_method AS
        SELECT
            nextval('id') AS id,
            asset_milestone.asset,
            asset_milestone.milestone_year,
            asset.capacity AS capacity_asset,
            asset.capacity_storage_energy AS capacity_storage_energy,
            asset.energy_to_power_ratio AS energy_to_power_ratio,
            asset.storage_method_energy AS storage_method_energy,
            expr_avail_energy.initial_storage_units AS initial_storage_units,
            expr_avail_energy.id AS avail_energy_id,
            expr_avail_assets.initial_units AS initial_asset_units,
            expr_avail_assets.id AS avail_assets_id,
        FROM asset_milestone
        LEFT JOIN asset
            ON asset_milestone.asset = asset.asset
        LEFT JOIN expr_available_energy_units_simple_method AS expr_avail_energy
            ON asset_milestone.asset = expr_avail_energy.asset
            AND asset_milestone.milestone_year = expr_avail_energy.milestone_year
        LEFT JOIN expr_available_asset_units_simple_method AS expr_avail_assets
            ON asset_milestone.asset = expr_avail_assets.asset
            AND asset_milestone.milestone_year = expr_avail_assets.milestone_year
        WHERE
            asset.type = 'storage'
        ORDER BY id
        ",
    )

    expressions[:available_energy_capacity_simple_method] =
        TulipaExpression(connection, "expr_available_energy_capacity_simple_method")

    avail_storage_units = expressions[:available_energy_units_simple_method].expressions[:energy]
    avail_asset_units = expressions[:available_asset_units_simple_method].expressions[:assets]

    let table_name = :available_energy_capacity_simple_method, expr = expressions[table_name]
        indices = DuckDB.query(connection, "FROM expr_$table_name")
        attach_expression!(
            expr,
            :energy_capacity,
            JuMP.AffExpr[
                if row.storage_method_energy == "optimize_storage_capacity"
                    @expression(
                        model,
                        row.capacity_storage_energy * row.initial_storage_units +
                        row.capacity_storage_energy *
                        (avail_storage_units[row.avail_energy_id] - row.initial_storage_units)
                    )
                elseif row.storage_method_energy == "use_fixed_energy_to_power_ratio"
                    @expression(
                        model,
                        row.capacity_storage_energy * row.initial_storage_units +
                        row.energy_to_power_ratio *
                        row.capacity_asset *
                        (avail_asset_units[row.avail_assets_id] - row.initial_asset_units)
                    )
                else
                    @expression(model, row.capacity_storage_energy * row.initial_storage_units)
                end for row in indices
            ],
        )
    end
end
