"""
    add_investment_group_constraints!(connection, model, variables, expressions, constraints)

Adds group constraints for assets that share a common limits or bounds.
"""
function add_investment_group_constraints!(connection, model, variables, expressions, constraints)
    assets_investment = variables[:assets_investment].container
    expr_available_asset_units_aggregated =
        expressions[:available_asset_units_aggregated_vintage_method].expressions[:assets]
    expr_available_asset_units_compact =
        expressions[:available_asset_units_compact_vintage_method].expressions[:assets]

    let table_name = :group_investment
        cons = constraints[table_name]
        indices = _append_group_data_to_indices!(connection, "cons_$table_name")
        attach_constraint!(
            model,
            cons,
            :investment_group,
            [
                begin
                    constraint_sense = if row.constraint_sense == "=="
                        MathOptInterface.EqualTo(0.0)
                    elseif row.constraint_sense == ">="
                        MathOptInterface.GreaterThan(0.0)
                    else
                        MathOptInterface.LessThan(0.0)
                    end

                    group_expression = if row.invest_method == "use_only_investment_units"
                        sum(
                            coefficient * assets_investment[id] for (id, coefficient) in zip(
                                row.var_assets_investment_ids,
                                row.var_assets_investment_coefficients,
                            );
                            init = JuMP.AffExpr(0.0),
                        )
                    else
                        sum(
                            coefficient * expr_available_asset_units_aggregated[id] for
                            (id, coefficient) in zip(
                                row.available_asset_units_aggregated_ids,
                                row.available_asset_units_aggregated_coefficients,
                            );
                            init = JuMP.AffExpr(0.0),
                        ) + sum(
                            coefficient * expr_available_asset_units_compact[id] for
                            (id, coefficient) in zip(
                                row.available_asset_units_compact_ids,
                                row.available_asset_units_compact_coefficients,
                            );
                            init = JuMP.AffExpr(0.0),
                        )
                    end

                    @constraint(
                        model,
                        group_expression - row.rhs in constraint_sense,
                        base_name = "investment_group[$(row.name),$(row.milestone_year)]"
                    )
                end for row in indices
            ],
        )
    end

    return
end

function _append_group_data_to_indices!(connection, cons_table_name)
    return DuckDB.query(
        connection,
        """
        WITH
            cte_group_investment_expression AS (
                SELECT
                    group_asset.name AS name,
                    group_asset.milestone_year AS milestone_year,
                    COALESCE(
                        ARRAY_AGG(var.id ORDER BY group_membership.asset, var.id) FILTER (var.id IS NOT NULL),
                        []::BIGINT[]
                    ) AS var_assets_investment_ids,
                    COALESCE(
                        ARRAY_AGG(group_membership.coefficient ORDER BY group_membership.asset, var.id) FILTER (var.id IS NOT NULL),
                        []::DOUBLE[]
                    ) AS var_assets_investment_coefficients,
                FROM investment_group_asset AS group_asset
                LEFT JOIN investment_group_asset_membership AS group_membership
                    ON group_asset.name = group_membership.group_name
                    AND group_asset.milestone_year = group_membership.milestone_year
                LEFT JOIN var_assets_investment AS var
                    ON group_membership.asset = var.asset
                    AND group_asset.milestone_year = var.milestone_year
                WHERE group_asset.invest_method = 'use_only_investment_units'
                GROUP BY group_asset.name, group_asset.milestone_year
            ),
            cte_group_available_asset_units_aggregated AS (
                SELECT
                    group_asset.name AS name,
                    group_asset.milestone_year AS milestone_year,
                    COALESCE(
                        ARRAY_AGG(expr.id ORDER BY group_membership.asset, expr.commission_year, expr.id) FILTER (expr.id IS NOT NULL),
                        []::BIGINT[]
                    ) AS available_asset_units_aggregated_ids,
                    COALESCE(
                        ARRAY_AGG(group_membership.coefficient ORDER BY group_membership.asset, expr.commission_year, expr.id) FILTER (expr.id IS NOT NULL),
                        []::DOUBLE[]
                    ) AS available_asset_units_aggregated_coefficients,
                FROM investment_group_asset AS group_asset
                LEFT JOIN investment_group_asset_membership AS group_membership
                    ON group_asset.name = group_membership.group_name
                    AND group_asset.milestone_year = group_membership.milestone_year
                LEFT JOIN expr_available_asset_units_aggregated_vintage_method AS expr
                    ON group_membership.asset = expr.asset
                    AND group_asset.milestone_year = expr.milestone_year
                WHERE group_asset.invest_method = 'use_available_units'
                GROUP BY group_asset.name, group_asset.milestone_year
            ),
            cte_group_available_asset_units_compact AS (
                SELECT
                    group_asset.name AS name,
                    group_asset.milestone_year AS milestone_year,
                    COALESCE(
                        ARRAY_AGG(expr.id ORDER BY group_membership.asset, expr.commission_year, expr.id) FILTER (expr.id IS NOT NULL),
                        []::BIGINT[]
                    ) AS available_asset_units_compact_ids,
                    COALESCE(
                        ARRAY_AGG(group_membership.coefficient ORDER BY group_membership.asset, expr.commission_year, expr.id) FILTER (expr.id IS NOT NULL),
                        []::DOUBLE[]
                    ) AS available_asset_units_compact_coefficients,
                FROM investment_group_asset AS group_asset
                LEFT JOIN investment_group_asset_membership AS group_membership
                    ON group_asset.name = group_membership.group_name
                    AND group_asset.milestone_year = group_membership.milestone_year
                LEFT JOIN expr_available_asset_units_compact_vintage_method AS expr
                    ON group_membership.asset = expr.asset
                    AND group_asset.milestone_year = expr.milestone_year
                WHERE group_asset.invest_method = 'use_available_units'
                GROUP BY group_asset.name, group_asset.milestone_year
            )
        SELECT
            cons.*,
            COALESCE(
                cte_group_investment_expression.var_assets_investment_ids,
                []::BIGINT[]
            ) AS var_assets_investment_ids,
            COALESCE(
                cte_group_investment_expression.var_assets_investment_coefficients,
                []::DOUBLE[]
            ) AS var_assets_investment_coefficients,
            COALESCE(
                cte_group_available_asset_units_aggregated.available_asset_units_aggregated_ids,
                []::BIGINT[]
            ) AS available_asset_units_aggregated_ids,
            COALESCE(
                cte_group_available_asset_units_aggregated.available_asset_units_aggregated_coefficients,
                []::DOUBLE[]
            ) AS available_asset_units_aggregated_coefficients,
            COALESCE(
                cte_group_available_asset_units_compact.available_asset_units_compact_ids,
                []::BIGINT[]
            ) AS available_asset_units_compact_ids,
            COALESCE(
                cte_group_available_asset_units_compact.available_asset_units_compact_coefficients,
                []::DOUBLE[]
            ) AS available_asset_units_compact_coefficients,
        FROM $cons_table_name AS cons
        LEFT JOIN cte_group_investment_expression
            ON cons.name = cte_group_investment_expression.name
            AND cons.milestone_year = cte_group_investment_expression.milestone_year
        LEFT JOIN cte_group_available_asset_units_aggregated
            ON cons.name = cte_group_available_asset_units_aggregated.name
            AND cons.milestone_year = cte_group_available_asset_units_aggregated.milestone_year
        LEFT JOIN cte_group_available_asset_units_compact
            ON cons.name = cte_group_available_asset_units_compact.name
            AND cons.milestone_year = cte_group_available_asset_units_compact.milestone_year
        """,
    )
end
