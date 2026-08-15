export add_minimum_down_time_constraints!

"""
    add_minimum_down_time_constraints!(model, constraints)

Adds the minimum down time constraints to the model.
"""
function add_minimum_down_time_constraints!(connection, model, variables, expressions, constraints)
    #Minimum down time with simple investment strategy
    let table_name = :minimum_down_time_aggregated_vintage_method,
        units_on = variables[:units_on].container

        cons = constraints[table_name]

        asset_year_rep_period_dict = Dict()
        for row in cons.indices
            key = "$(row.asset),$(row.milestone_year),$(row.rep_period)"
            if (!haskey(asset_year_rep_period_dict, key))
                asset_year_rep_period_dict[key] = _get_indices_for_sum(
                    connection,
                    table_name,
                    row.asset,
                    row.milestone_year,
                    row.rep_period,
                    "shut_down",
                )
            end
        end

        expr_avail_simple_method =
            expressions[:available_asset_units_aggregated_vintage_method].expressions[:assets]

        indices =
            _append_available_units_shut_down_aggregated_vintage_method(connection, table_name)

        attach_constraint!(
            model,
            cons,
            table_name,
            [
                @constraint(
                    model,
                    _sum_min_down_blocks(
                        asset_year_rep_period_dict["$(row.asset),$(row.milestone_year),$(row.rep_period)"],
                        variables[:shut_down].container,
                        row.time_block_start,
                    ) <= expr_avail_simple_method[row.avail_id] - units_on[row.units_on_id],
                    base_name = "$table_name[$(row.asset),$(row.milestone_year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]"
                ) for row in indices
            ],
        )
    end

    #Minimum down time with compact investment strategy
    let table_name = :minimum_down_time_compact_vintage_method,
        units_on = variables[:units_on].container

        cons = constraints[table_name]

        asset_year_rep_period_dict = Dict()
        for row in cons.indices
            key = "$(row.asset),$(row.milestone_year),$(row.rep_period)"
            if (!haskey(asset_year_rep_period_dict, key))
                asset_year_rep_period_dict[key] = _get_indices_for_sum(
                    connection,
                    table_name,
                    row.asset,
                    row.milestone_year,
                    row.rep_period,
                    "shut_down",
                )
            end
        end

        expr_avail_compact_method =
            expressions[:available_asset_units_compact_vintage_method].expressions[:assets]

        indices = _append_available_units_shut_down_compact_method(connection, table_name)

        attach_constraint!(
            model,
            cons,
            table_name,
            [
                @constraint(
                    model,
                    _sum_min_down_blocks(
                        asset_year_rep_period_dict["$(row.asset),$(row.milestone_year),$(row.rep_period)"],
                        variables[:shut_down].container,
                        row.time_block_start,
                    ) <=
                    sum(expr_avail_compact_method[avail_id] for avail_id in row.avail_indices) -
                    units_on[row.units_on_id],
                    base_name = "$table_name[$(row.asset),$(row.milestone_year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]"
                ) for row in indices
            ],
        )
    end
end

function _sum_min_down_blocks(sum_rows, shut_downs, start_of_curr_constraint)
    sum = 0
    for single_row in sum_rows
        start_of_this = single_row.time_block_start
        minimum_down_time = single_row.minimum_down_time
        if (
            start_of_curr_constraint - minimum_down_time + 1 <=
            start_of_this <=
            start_of_curr_constraint
        )
            sum = sum + shut_downs[single_row.shut_down_id]
        end
    end
    return sum
end
