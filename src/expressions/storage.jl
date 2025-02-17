function add_storage_expressions!(connection, model, expressions)
    DuckDB.query(
        connection,
        "CREATE OR REPLACE TEMP SEQUENCE id START 1;
        CREATE OR REPLACE TABLE expr_available_energy_capacity AS
        SELECT
            nextval('id') AS index,
            asset_milestone.asset,
            asset_milestone.milestone_year,
            ANY_VALUE(asset.capacity) AS capacity,
            ANY_VALUE(asset.capacity_storage_energy) AS capacity_storage_energy,
            ANY_VALUE(asset.energy_to_power_ratio) AS energy_to_power_ratio,
            ANY_VALUE(asset.storage_method_energy) AS storage_method_energy,
            SUM(expr_avail.initial_storage_units) AS available_initial_storage_units,
            ARRAY_AGG(expr_avail.index) AS avail_indices,
        FROM asset_milestone
        LEFT JOIN asset
            ON asset_milestone.asset = asset.asset
        LEFT JOIN expr_available_energy_units AS expr_avail
            ON asset_milestone.asset = expr_avail.asset
            AND asset_milestone.milestone_year = expr_avail.milestone_year
        WHERE
            asset.type = 'storage'
        GROUP BY
            asset_milestone.asset,
            asset_milestone.milestone_year
        ORDER BY index
        ",
    )

    expressions[:available_energy_capacity] =
        TulipaExpression(connection, "expr_available_energy_capacity")

    expr_avail = expressions[:available_energy_units].expressions[:energy]

    let table_name = :available_energy_capacity, expr = expressions[table_name]
        indices = DuckDB.query(connection, "FROM expr_$table_name")
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
                            sum(expr_avail[avail_index] for avail_index in row.avail_indices) -
                            row.available_initial_storage_units
                        )
                    )
                end for row in indices
            ],
        )
    end
end
