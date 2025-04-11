function add_storage_expressions!(connection, model, expressions)
    DuckDB.query(
        connection,
        "CREATE OR REPLACE TEMP SEQUENCE id START 1;
        CREATE OR REPLACE TABLE expressions.available_energy_capacity_simple_method AS
        SELECT
            nextval('id') AS id,
            asset_milestone.asset,
            asset_milestone.milestone_year,
            asset.capacity AS capacity,
            asset.capacity_storage_energy AS capacity_storage_energy,
            asset.energy_to_power_ratio AS energy_to_power_ratio,
            asset.storage_method_energy AS storage_method_energy,
            expr_avail.initial_storage_units AS available_initial_storage_units,
            expr_avail.id AS avail_id,
        FROM input.asset_milestone as asset_milestone
        LEFT JOIN input.asset as asset
            ON asset_milestone.asset = asset.asset
        LEFT JOIN expressions.available_energy_units_simple_method AS expr_avail
            ON asset_milestone.asset = expr_avail.asset
            AND asset_milestone.milestone_year = expr_avail.milestone_year
        WHERE
            asset.type = 'storage'
        ORDER BY id
        ",
    )

    expressions[:available_energy_capacity_simple_method] =
        TulipaExpression(connection, "available_energy_capacity_simple_method")

    expr_avail_simple_method =
        expressions[:available_energy_units_simple_method].expressions[:energy]

    let table_name = :available_energy_capacity_simple_method, expr = expressions[table_name]
        indices = DuckDB.query(connection, "FROM expressions.$table_name")
        attach_expression!(
            expr,
            :energy_capacity,
            [
                begin
                    capacity_for_initial = row.capacity_storage_energy
                    capacity_for_variation = if row.storage_method_energy
                        row.capacity_storage_energy
                    else
                        row.energy_to_power_ratio * row.capacity
                    end
                    @expression(
                        model,
                        # We remove row.available_initial_storage_units from the sum of the expression
                        # because it is added separately with a different coefficient (capacity_for_initial).
                        # We need to keep the available_initial_storage_units
                        # inside the expression for the general expression
                        # (file src/expressions/multi-year.jl) to be used in
                        # the fixed cost in the objective function
                        capacity_for_initial * row.available_initial_storage_units +
                        capacity_for_variation * (
                            expr_avail_simple_method[row.avail_id] -
                            row.available_initial_storage_units
                        )
                    )
                end for row in indices
            ],
        )
    end
end
