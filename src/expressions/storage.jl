function add_storage_expressions!(connection, model, expressions)
    DuckDB.query(
        connection,
        "CREATE OR REPLACE TEMP SEQUENCE id START 1;
        CREATE OR REPLACE TABLE expr_accumulated_energy_capacity AS
        SELECT
            nextval('id') AS index,
            asset_milestone.asset,
            asset_milestone.milestone_year,
            ANY_VALUE(asset.capacity_storage_energy) AS capacity_storage_energy,
            ARRAY_AGG(expr_acc.index) AS acc_indices,
        FROM asset_milestone
        LEFT JOIN asset
            ON asset_milestone.asset = asset.asset
        LEFT JOIN expr_accumulated_units AS expr_acc
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

    expr_acc = expressions[:accumulated_units].expressions[:assets_energy]

    # TODO: Reevaluate the accumulated_energy_capacity definition
    let table_name = :accumulated_energy_capacity, expr = expressions[table_name]
        indices = DuckDB.query(connection, "FROM expr_$table_name")
        attach_expression!(
            expr,
            :energy_capacity,
            JuMP.AffExpr[
                @expression(
                    model,
                    row.capacity_storage_energy *
                    sum(expr_acc[acc_index] for acc_index in row.acc_indices)
                ) for row in indices
            ],
        )
    end

    # assets_investment_energy = variables[:assets_investment_energy].lookup
    # assets_decommission_energy_simple_method =
    #     variables[:assets_decommission_energy_simple_method].lookup
    # accumulated_investment_units_using_simple_method =
    #     model[:accumulated_investment_units_using_simple_method]
    # accumulated_decommission_units_using_simple_method =
    #     model[:accumulated_decommission_units_using_simple_method]
    #
    # @expression(
    #     model,
    #     accumulated_energy_units_simple_method[
    #         y ∈ sets.Y,
    #         a ∈ sets.Ase[y]∩sets.decommissionable_assets_using_simple_method,
    #     ],
    #     sum(values(graph[a].initial_storage_units[y])) + sum(
    #         assets_investment_energy[yy, a] for
    #         yy in sets.Y if a ∈ (sets.Ase[yy] ∩ sets.investable_assets_using_simple_method[yy]) &&
    #         sets.starting_year_using_simple_method[(y, a)] ≤ yy ≤ y
    #     ) - sum(
    #         assets_decommission_energy_simple_method[yy, a] for yy in sets.Y if
    #         a ∈ sets.Ase[yy] && sets.starting_year_using_simple_method[(y, a)] ≤ yy ≤ y
    #     )
    # )
    # @expression(
    #     model,
    #     accumulated_energy_capacity[y ∈ sets.Y, a ∈ sets.As],
    #     if graph[a].storage_method_energy &&
    #        a ∈ sets.Ase ∩ sets.decommissionable_assets_using_simple_method
    #         graph[a].capacity_storage_energy * accumulated_energy_units_simple_method[y, a]
    #     else
    #         (
    #             graph[a].capacity_storage_energy * sum(values(graph[a].initial_storage_units[y])) +
    #             if a ∈ sets.Ai[y] ∩ sets.decommissionable_assets_using_simple_method
    #                 graph[a].energy_to_power_ratio *
    #                 graph[a].capacity *
    #                 (
    #                     accumulated_investment_units_using_simple_method[a, y] -
    #                     accumulated_decommission_units_using_simple_method[a, y]
    #                 )
    #             else
    #                 0.0
    #             end
    #         )
    #     end
    # )
end
