export add_investment_group_constraints!

"""
    add_investment_group_constraints!(connection, model, variables, constraints)

Adds group constraints for assets that share a common limits or bounds.
"""
function add_investment_group_constraints!(connection, model, variables, constraints)
    assets_investment = variables[:assets_investment].container

    for table_name in [:group_max_investment_limit, :group_min_investment_limit]
        cons = constraints[table_name]
        indices = _append_group_data_to_indices!(connection, "cons_$table_name")
        attach_expression!(
            cons,
            :investment_group,
            [
                @expression(
                    model,
                    sum(
                        coef * assets_investment[var_id] for
                        (var_id, coef) in zip(row.var_assets_investment_ids, row.coefficients)
                    )
                ) for row in indices
            ],
        )
    end

    let table_name = :group_max_investment_limit, cons = constraints[table_name]
        attach_constraint!(
            model,
            cons,
            :investment_group_max_limit,
            [
                @constraint(
                    model,
                    investment_group ≤ row.max_investment_limit,
                    base_name = "investment_group_max_limit[$(row.name)]"
                ) for
                (row, investment_group) in zip(cons.indices, cons.expressions[:investment_group])
            ],
        )
    end

    let table_name = :group_min_investment_limit, cons = constraints[table_name]
        attach_constraint!(
            model,
            cons,
            :investment_group_min_limit,
            [
                @constraint(
                    model,
                    investment_group ≥ row.min_investment_limit,
                    base_name = "investment_group_min_limit[$(row.name)]"
                ) for
                (row, investment_group) in zip(cons.indices, cons.expressions[:investment_group])
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
                ARRAY_AGG(var.id) AS var_assets_investment_ids,
                ARRAY_AGG(group_asset_membership.coefficient) AS coefficients,
            FROM group_asset
            LEFT JOIN group_asset_membership
                ON group_asset.name = group_asset_membership.group_name
            LEFT JOIN var_assets_investment AS var
                ON group_asset_membership.asset = var.asset
                AND group_asset.milestone_year = var.milestone_year
            GROUP BY group_asset.name
        )
        SELECT
            cons.id,
            cte.name,
            cte.var_assets_investment_ids,
            cte.coefficients,
        FROM $cons_table_name AS cons
        LEFT JOIN cte_group_expression AS cte
            ON cons.name = cte.name
        """,
    )
end
