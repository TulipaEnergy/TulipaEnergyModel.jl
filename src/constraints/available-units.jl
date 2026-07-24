"""
    add_available_asset_units_constraints!(connection, model, expressions, constraints)

Adds optional maximum and minimum constraints on available asset units.
"""
function add_available_asset_units_constraints!(connection, model, expressions, constraints)
    expr_available_asset_units_aggregated =
        expressions[:available_asset_units_aggregated_vintage_method].expressions[:assets]
    expr_available_asset_units_compact =
        expressions[:available_asset_units_compact_vintage_method].expressions[:assets]

    for (table_name, constraint_sense) in (
        (:max_available_asset_units, MathOptInterface.LessThan(0.0)),
        (:min_available_asset_units, MathOptInterface.GreaterThan(0.0)),
    )
        cons = constraints[table_name]
        indices = _append_available_asset_units_data_to_indices!(connection, "cons_$table_name")
        attach_constraint!(
            model,
            cons,
            table_name,
            [
                begin
                    available_units =
                        sum(
                            (
                                expr_available_asset_units_aggregated[id] for
                                id in row.available_asset_units_aggregated_ids
                            );
                            init = JuMP.AffExpr(0.0),
                        ) + sum(
                            (
                                expr_available_asset_units_compact[id] for
                                id in row.available_asset_units_compact_ids
                            );
                            init = JuMP.AffExpr(0.0),
                        )

                    @constraint(
                        model,
                        available_units - row.rhs in constraint_sense,
                        base_name = "$table_name[$(row.asset),$(row.milestone_year)]"
                    )
                end for row in indices
            ],
        )
    end

    return
end

function _append_available_asset_units_data_to_indices!(connection, cons_table_name)
    return DuckDB.query(
        connection,
        """
        WITH
            cte_available_asset_units_aggregated AS (
                SELECT
                    cons.id,
                    COALESCE(
                        ARRAY_AGG(expr.id ORDER BY expr.id) FILTER (expr.id IS NOT NULL),
                        []::BIGINT[]
                    ) AS available_asset_units_aggregated_ids,
                FROM $cons_table_name AS cons
                LEFT JOIN expr_available_asset_units_aggregated_vintage_method AS expr
                    ON cons.asset = expr.asset
                    AND cons.milestone_year = expr.milestone_year
                GROUP BY cons.id
            ),
            cte_available_asset_units_compact AS (
                SELECT
                    cons.id,
                    COALESCE(
                        ARRAY_AGG(expr.id ORDER BY expr.commission_year, expr.id) FILTER (expr.id IS NOT NULL),
                        []::BIGINT[]
                    ) AS available_asset_units_compact_ids,
                FROM $cons_table_name AS cons
                LEFT JOIN expr_available_asset_units_compact_vintage_method AS expr
                    ON cons.asset = expr.asset
                    AND cons.milestone_year = expr.milestone_year
                GROUP BY cons.id
            )
        SELECT
            cons.*,
            cte_available_asset_units_aggregated.available_asset_units_aggregated_ids,
            cte_available_asset_units_compact.available_asset_units_compact_ids,
        FROM $cons_table_name AS cons
        LEFT JOIN cte_available_asset_units_aggregated
            ON cons.id = cte_available_asset_units_aggregated.id
        LEFT JOIN cte_available_asset_units_compact
            ON cons.id = cte_available_asset_units_compact.id
        ORDER BY cons.id
        """,
    )
end
