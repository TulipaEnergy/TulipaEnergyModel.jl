"""
    add_shut_down_upper_bound_constraints!(model, constraints)

Adds the shut down constraints to the model.
"""
function add_shut_down_upper_bound_constraints!(
    connection,
    model,
    variables,
    expressions,
    constraints,
)
    let table_name = :shut_down_upper_bound_aggregated_vintage_method,
        cons = constraints[table_name]

        expr_avail_aggregated_vintage_method =
            expressions[:available_asset_units_aggregated_vintage_method].expressions[:assets]

        indices =
            _append_available_units_shut_down_aggregated_vintage_method(connection, table_name)

        units_on_vars = variables[:units_on].container
        shut_down_vars = variables[:shut_down].container

        attach_constraint!(
            model,
            cons,
            table_name,
            [
                @constraint(
                    model,
                    shut_down_vars[row.shut_down_id] <=
                    expr_avail_aggregated_vintage_method[row.avail_id] -
                    units_on_vars[row.units_on_id],
                    base_name = "$table_name[$(row.asset),$(row.milestone_year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]"
                ) for row in indices
            ],
        )
    end

    let table_name = :shut_down_upper_bound_compact_vintage_method, cons = constraints[table_name]
        expr_avail_compact_method =
            expressions[:available_asset_units_compact_vintage_method].expressions[:assets]

        indices = _append_available_units_shut_down_compact_method(connection, table_name)

        units_on_vars = variables[:units_on].container
        shut_down_vars = variables[:shut_down].container

        attach_constraint!(
            model,
            cons,
            table_name,
            [
                @constraint(
                    model,
                    shut_down_vars[row.shut_down_id] <=
                    sum(expr_avail_compact_method[avail_id] for avail_id in row.avail_indices) -
                    units_on_vars[row.units_on_id],
                    base_name = "$table_name[$(row.asset),$(row.milestone_year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]"
                ) for row in indices
            ],
        )
    end

    return nothing
end
