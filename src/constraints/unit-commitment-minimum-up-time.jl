export add_minimum_up_time_constraints!

"""
    add_minimum_up_time_constraints!(model, constraints)

Adds the minimum up time constraints to the model.
"""
function add_minimum_up_time_constraints!(connection, model, variables, expressions, constraints)
    let table_name = :minimum_up_time,
        cons = constraints[:minimum_up_time],
        units_on = variables[:units_on].container,
        indices = _append_variable_ids(connection, table_name, ["units_on"])

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
                    "start_up",
                )
            end
        end

        attach_constraint!(
            model,
            cons,
            table_name,
            [
                @constraint(
                    model,
                    _sum_min_up_blocks(
                        asset_year_rep_period_dict["$(row.asset),$(row.milestone_year),$(row.rep_period)"],
                        variables[:start_up].container,
                        row.time_block_start,
                    ) <= units_on[row.units_on_id],
                    base_name = "$table_name[$(row.asset),$(row.milestone_year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]"
                ) for row in indices
            ],
        )
    end
end

function _sum_min_up_blocks(sum_rows, start_ups, start_of_curr_constraint)
    sum = 0
    for single_row in sum_rows
        start_of_this = single_row.time_block_start
        minimum_up_time = single_row.minimum_up_time
        if (
            start_of_curr_constraint - minimum_up_time + 1 <=
            start_of_this <=
            start_of_curr_constraint
        )
            sum = sum + start_ups[single_row.start_up_id]
        end
    end
    return sum
end

function _get_indices_for_sum(
    connection,
    table_name,
    curr_asset,
    curr_year,
    curr_rep_period,
    variable_name,
)
    variable_table_name = "var_" * variable_name

    return DuckDB.query(
        connection,
        "SELECT
            cons.*,
            asset.minimum_up_time,
            asset.minimum_down_time,
            $variable_table_name.id as $(variable_name)_id,
        FROM cons_$table_name AS cons
        LEFT JOIN asset
            ON cons.asset = asset.asset
        LEFT JOIN $variable_table_name
            ON $variable_table_name.asset = cons.asset
            AND $variable_table_name.milestone_year = cons.milestone_year
            AND $variable_table_name.rep_period = cons.rep_period
            AND $variable_table_name.time_block_start = cons.time_block_start
        WHERE cons.asset = '$curr_asset' AND cons.milestone_year = $curr_year AND cons.rep_period = $curr_rep_period
        ORDER BY cons.id
        ",
    )
end
