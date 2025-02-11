function add_storage_expressions!(connection, model, expressions)
    DuckDB.query(
        connection,
        "CREATE OR REPLACE TEMP SEQUENCE id START 1;
        CREATE OR REPLACE TABLE expr_accumulated_energy_capacity AS
        SELECT
            nextval('id') AS index,
            asset_milestone.asset,
            asset_milestone.milestone_year,
            ANY_VALUE(asset.capacity) AS capacity,
            ANY_VALUE(asset.capacity_storage_energy) AS capacity_storage_energy,
            ANY_VALUE(asset.energy_to_power_ratio) AS energy_to_power_ratio,
            ANY_VALUE(asset.storage_method_energy) AS storage_method_energy,
            SUM(expr_acc.initial_storage_units) AS accumulated_initial_storage_units,
            ARRAY_AGG(expr_acc.index) AS acc_indices,
        FROM asset_milestone
        LEFT JOIN asset
            ON asset_milestone.asset = asset.asset
        LEFT JOIN expr_accumulated_energy_units AS expr_acc
            ON asset_milestone.asset = expr_acc.asset
            AND asset_milestone.milestone_year = expr_acc.milestone_year
        WHERE
            asset.type = 'storage'
        GROUP BY
            asset_milestone.asset,
            asset_milestone.milestone_year
        ORDER BY index
        ",
    )

    expressions[:accumulated_energy_capacity] =
        TulipaExpression(connection, "expr_accumulated_energy_capacity")

    expr_acc = expressions[:accumulated_energy_units].expressions[:energy]

    # TODO: Reevaluate the accumulated_energy_capacity definition
    let table_name = :accumulated_energy_capacity, expr = expressions[table_name]
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
                        # We remove row.accumulated_initial_storage_units from the sum of the expression
                        # because it is added separately with a different coefficient (capacity_for_initial).
                        # We need to keep the accumulated_initial_storage_units
                        # inside the expression for the general expression
                        # (file src/expressions/multi-year.jl) to be used in
                        # the fixed cost in the objective function
                        capacity_for_initial * row.accumulated_initial_storage_units +
                        capacity_for_variation * (
                            sum(expr_acc[acc_index] for acc_index in row.acc_indices) -
                            row.accumulated_initial_storage_units
                        )
                    )
                end for row in indices
            ],
        )
    end
end
