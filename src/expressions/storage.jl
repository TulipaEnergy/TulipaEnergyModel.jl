function add_storage_expressions!(connection, model, expressions)
    DuckDB.query(
        connection,
        "CREATE OR REPLACE TEMP SEQUENCE id START 1;
        CREATE OR REPLACE TABLE expr_available_energy_capacity_simple_method AS
        SELECT
            nextval('id') AS id,
            asset_milestone.asset,
            asset_milestone.milestone_year,
            asset.capacity AS capacity,
            asset.capacity_storage_energy AS capacity_storage_energy,
            asset.energy_to_power_ratio AS energy_to_power_ratio,
            asset.storage_method_energy AS storage_method_energy,
            expr_avail_energy.initial_storage_units AS available_initial_storage_units,
            expr_avail_energy.id AS avail_energy_id,
            expr_avail_assets.initial_units AS available_initial_units,
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

    expr_avail_simple_method =
        expressions[:available_energy_units_simple_method].expressions[:energy]
    expr_avail_assets_simple_method =
        expressions[:available_asset_units_simple_method].expressions[:assets]

    let table_name = :available_energy_capacity_simple_method, expr = expressions[table_name]
        indices = DuckDB.query(connection, "FROM expr_$table_name")
        energy_capacity_expressions = JuMP.AffExpr[]
        for row in indices
            capacity_for_initial = row.capacity_storage_energy
            if row.storage_method_energy == "optimize_storage_capacity"
                push!(
                    energy_capacity_expressions,
                    @expression(
                        model,
                        # We remove row.available_initial_storage_units from the sum of the expression
                        # because it is added separately with a different coefficient (capacity_for_initial).
                        # We need to keep the available_initial_storage_units
                        # inside the expression for the general expression
                        # (file src/expressions/multi-year.jl) to be used in
                        # the fixed cost in the objective function
                        capacity_for_initial * row.available_initial_storage_units +
                        row.capacity_storage_energy * (
                            expr_avail_simple_method[row.avail_energy_id] -
                            row.available_initial_storage_units
                        )
                    ),
                )
            elseif row.storage_method_energy == "use_fixed_energy_to_power_ratio"
                push!(
                    energy_capacity_expressions,
                    @expression(
                        model,
                        capacity_for_initial * row.available_initial_storage_units +
                        row.energy_to_power_ratio *
                        row.capacity *
                        (
                            expr_avail_assets_simple_method[row.avail_assets_id] -
                            row.available_initial_units
                        )
                    ),
                )
            else
                push!(
                    energy_capacity_expressions,
                    @expression(model, capacity_for_initial * row.available_initial_storage_units),
                )
            end
        end

        attach_expression!(expr, :energy_capacity, energy_capacity_expressions)
    end
end
