export add_investment_group_constraints!

"""
    add_investment_group_constraints!(connection, model, variables, constraints)

Adds group constraints for assets that share a common limits or bounds.
"""
function add_investment_group_constraints!(connection, model, variables, constraints)
    assets_investment = variables[:assets_investment].container

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

                    @constraint(
                        model,
                        sum(
                            coef * assets_investment[var_id] for
                            (var_id, coef) in zip(row.var_assets_investment_ids, row.coefficients)
                        ) - row.rhs in constraint_sense,
                        base_name = "investment_group[$(row.name),$(row.milestone_year)]"
                    )
                end for row in indices
            ],
        )
    end

    # - TODO: More group constraints e.g., limits on the available investments of a group

    return
end

function _append_group_data_to_indices!(connection, cons_table_name)
    return DuckDB.query(
        connection,
        """
        WITH cte_group_expression AS (
            SELECT
                group_asset.name AS name,
                group_asset.milestone_year AS milestone_year,
                ARRAY_AGG(var.id) AS var_assets_investment_ids,
                ARRAY_AGG(group_asset_membership.coefficient) AS coefficients,
            FROM group_asset
            LEFT JOIN group_asset_membership
                ON group_asset.name = group_asset_membership.group_name
                AND group_asset.milestone_year = group_asset_membership.milestone_year
            LEFT JOIN var_assets_investment AS var
                ON group_asset_membership.asset = var.asset
                AND group_asset.milestone_year = var.milestone_year
            GROUP BY group_asset.name, group_asset.milestone_year
        )
        SELECT
            cons.*,
            cte.name,
            cte.milestone_year,
            cte.var_assets_investment_ids,
            cte.coefficients,
        FROM $cons_table_name AS cons
        LEFT JOIN cte_group_expression AS cte
            ON cons.name = cte.name
            AND cons.milestone_year = cte.milestone_year
        """,
    )
end
