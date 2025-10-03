export add_minimum_down_time_2var_constraints!

function _get_indices_for_sum_2var(
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
            AND $variable_table_name.year = cons.year
            AND $variable_table_name.rep_period = cons.rep_period
            AND $variable_table_name.time_block_start = cons.time_block_start
        WHERE cons.asset = '$curr_asset' AND cons.year = $curr_year AND cons.rep_period = $curr_rep_period
        ORDER BY cons.id
        ",
    )
end

"""
    add_minimum_down_time_2var_constraints!(model, constraints)

Adds the minimum down time 2var constraints to the model.
"""
function add_minimum_down_time_2var_constraints!(
    connection,
    model,
    variables,
    expressions,
    constraints,
)
    #Minimum down time with simple investment strategy
    let table_name = :minimum_down_time_2var_simple_investment,
        units_on = variables[:units_on].container

        cons = constraints[:minimum_down_time_2var_simple_investment]

        asset_year_rep_period_dict = Dict()
        for row in cons.indices
            key = "$(row.asset),$(row.year),$(row.rep_period)"
            if (!haskey(asset_year_rep_period_dict, key))
                asset_year_rep_period_dict[key] = _get_indices_for_sum_2var(
                    connection,
                    table_name,
                    row.asset,
                    row.year,
                    row.rep_period,
                    "start_up",
                )
            end
        end

        expr_avail_simple_method =
            expressions[:available_asset_units_simple_method].expressions[:assets]

        indices = _append_available_units_data_simple_2var(connection, table_name)

        attach_constraint!(
            model,
            cons,
            :minimum_down_time_2var_simple_investment,
            [
                let RHS_UC_ID = _sum_min_down_blocks_2var(
                        asset_year_rep_period_dict["$(row.asset),$(row.year),$(row.rep_period)"],
                        variables[:start_up].container,
                        row.time_block_start,
                    )
                    if row.asset == "ccgt"
                        println(RHS_UC_ID[2])
                        println(RHS_UC_ID[2] < 2)
                        println(units_on)
                    end
                    if RHS_UC_ID[2] < 2 # || row.time_block_start == 1
                        println("ENTERED NO UC AREA")
                        println(RHS_UC_ID)
                        @constraint(
                            model,
                            RHS_UC_ID[1] <= expr_avail_simple_method[row.avail_id],
                            base_name = "minimum_down_time_2var_simple_investment[$(row.asset),$(row.year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]"
                        )
                    else
                        println("ENTERED YES UC AREA")
                        println(RHS_UC_ID[2])
                        println(units_on[RHS_UC_ID[2]-1])
                        @constraint(
                            model,
                            RHS_UC_ID[1] <=
                            expr_avail_simple_method[row.avail_id] - units_on[RHS_UC_ID[2]-1],
                            base_name = "minimum_down_time_2var_simple_investment[$(row.asset),$(row.year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]"
                        )
                    end
                end for row in indices
            ],
        )
    end

    #Minimum down time with compact investment strategy
    let table_name = :minimum_down_time_2var_compact_investment,
        units_on = variables[:units_on].container

        cons = constraints[:minimum_down_time_2var_compact_investment]

        asset_year_rep_period_dict = Dict()
        for row in cons.indices
            key = "$(row.asset),$(row.year),$(row.rep_period)"
            if (!haskey(asset_year_rep_period_dict, key))
                asset_year_rep_period_dict[key] = _get_indices_for_sum_2var(
                    connection,
                    table_name,
                    row.asset,
                    row.year,
                    row.rep_period,
                    "start_up",
                )
            end
        end

        expr_avail_compact_method =
            expressions[:available_asset_units_compact_method].expressions[:assets]

        indices = _append_available_units_data_compact_2var(connection, table_name)

        attach_constraint!(
            model,
            cons,
            :minimum_down_time_2var_compact_investment,
            [
                let RHS_UC_ID = _sum_min_down_blocks_2var(
                        asset_year_rep_period_dict["$(row.asset),$(row.year),$(row.rep_period)"],
                        variables[:start_up].container,
                        row.time_block_start,
                    )
                    (
                        if RHS_UC_ID[2] < 2
                            @constraint(
                                model,
                                RHS_UC_ID[1] <= sum(
                                    expr_avail_compact_method[avail_id] for
                                    avail_id in row.avail_indices
                                ),
                                base_name = "minimum_down_time_2var_compact_investment[$(row.asset),$(row.year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]"
                            )
                        else
                            @constraint(
                                model,
                                RHS_UC_ID[1] <=
                                sum(
                                    expr_avail_compact_method[avail_id] for
                                    avail_id in row.avail_indices
                                ) - units_on[RHS_UC_ID[2]-1],
                                base_name = "minimum_down_time_2var_compact_investment[$(row.asset),$(row.year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]"
                            )
                        end,
                    )
                end for row in indices
            ],
        )
    end
end

function _sum_min_down_blocks_2var(sum_rows, shut_downs, start_of_curr_constraint)
    sum = 0

    first_SU_id = -1

    iters = 0

    should_look_for_first = true

    for single_row in sum_rows
        start_of_this = single_row.time_block_start
        minimum_down_time = single_row.minimum_down_time
        if (
            start_of_curr_constraint - minimum_down_time + 1 <=
            start_of_this <=
            start_of_curr_constraint
        )
            if iters == 0
                should_look_for_first = false
            end

            sum = sum + shut_downs[single_row.id]

            if should_look_for_first
                first_SU_id = single_row.id
                should_look_for_first = false
            end

            # if first_SU_id == -1 && iters > 0
            #     first_SU_id = single_row.id
            # end
        end

        iters = iters + 1
    end
    return sum, first_SU_id
end

function _append_available_units_data_simple_2var(connection, table_name)
    return DuckDB.query(
        connection,
        "SELECT
            cons.*,
            expr_avail.id AS avail_id,
            var_units_on.id as units_on_id,
            asset.minimum_down_time as minimum_down_time
        FROM cons_$table_name AS cons
        LEFT JOIN expr_available_asset_units_simple_method AS expr_avail
            ON cons.asset = expr_avail.asset
            AND cons.year = expr_avail.milestone_year
        LEFT JOIN asset
            ON cons.asset = asset.asset
        LEFT JOIN var_units_on
            ON var_units_on.asset = cons.asset
            AND var_units_on.year = cons.year
            AND var_units_on.rep_period = cons.rep_period
            AND var_units_on.time_block_start = cons.time_block_start
        WHERE asset.investment_method in ('simple', 'none')
        ORDER BY cons.id
        ",
    )
end

function _append_available_units_data_compact_2var(connection, table_name)
    return DuckDB.query(
        connection,
        "SELECT
            cons.id,
            ANY_VALUE(cons.asset) AS asset,
            ANY_VALUE(cons.year) AS year,
            ANY_VALUE(cons.rep_period) AS rep_period,
            ANY_VALUE(cons.time_block_start) AS time_block_start,
            ANY_VALUE(cons.time_block_end) AS time_block_end,
            ARRAY_AGG(expr_avail.id) AS avail_indices,
            ANY_VALUE(var_units_on.id) as units_on_id,
            ANY_VALUE(asset.minimum_down_time) as minimum_down_time
        FROM cons_$table_name AS cons
        LEFT JOIN expr_available_asset_units_compact_method AS expr_avail
            ON cons.asset = expr_avail.asset
            AND cons.year = expr_avail.milestone_year
        LEFT JOIN asset
            ON cons.asset = asset.asset
        LEFT JOIN var_units_on
            ON var_units_on.asset = cons.asset
            AND var_units_on.year = cons.year
            AND var_units_on.rep_period = cons.rep_period
            AND var_units_on.time_block_start = cons.time_block_start
        WHERE asset.investment_method = 'compact'
        GROUP BY cons.id
        ORDER BY cons.id
        ",
    )
end
