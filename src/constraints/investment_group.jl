export add_investment_group_constraints!

"""
    add_investment_group_constraints!(connection, model, variables, constraints)

Adds group constraints for assets that share a common limits or bounds.
"""
function add_investment_group_constraints!(connection, model, variables, constraints)
    assets_investment = variables[:assets_investment].container

    for table_name in [:group_max_investment_limit, :group_min_investment_limit]
        cons = constraints[table_name]
        attach_expression!(
            cons,
            :investment_group,
            [
                @expression(
                    model,
                    sum(
                        asset_row.capacity * assets_investment[asset_row.id] for
                        asset_row in _get_assets_in_group(connection, row.name)
                    )
                ) for row in cons.indices
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

function _get_assets_in_group(connection, group)
    return DuckDB.query(
        connection,
        "SELECT
            var.id,
            asset.investment_group,
            asset.capacity,
        FROM var_assets_investment AS var
        JOIN asset
            ON var.asset = asset.asset
        JOIN group_asset
            ON asset.investment_group = group_asset.name
        WHERE asset.investment_group IS NOT NULL
              AND  asset.investment_group = '$group'
        ",
    )
end
