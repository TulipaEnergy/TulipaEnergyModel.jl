export add_su_sd_ramping_with_vars_constraints!

"""
    add_su_sd_ramping_with_vars_constraints!(model, constraints)

Adds the start-up and shut-down ramping constraints (with start-up and shut-down variables) to the model.
"""
function add_su_sd_ramping_with_vars_constraints!(
    connection,
    model,
    variables,
    expressions,
    constraints,
    profiles,
)
    indices_dict = Dict(
        table_name => _append_su_sd_ramp_vars_data_to_indices(connection, table_name) for
        table_name in (
            :su_ramp_vars_flow_diff,
            :sd_ramp_vars_flow_diff,
            :su_ramp_vars_flow_upper_bound,
            :sd_ramp_vars_flow_upper_bound,
            :su_sd_ramp_vars_flow_with_high_uptime,
        )
    )

    # expression for p^{availability profile} * p^{capacity}
    # as also found in ramping-and-unit-commitment.jl
    profile_times_capacity = Dict(
        table_name => begin
            indices = indices_dict[table_name]
            [
                _profile_aggregate(
                    profiles.rep_period,
                    (row.profile_name, row.year, row.rep_period),
                    row.time_block_start:row.time_block_end,
                    Statistics.mean,
                    1.0,
                ) * row.capacity for row in indices
            ]
        end for table_name in (
            :su_ramp_vars_flow_diff,
            :sd_ramp_vars_flow_diff,
            :su_ramp_vars_flow_upper_bound,
            :sd_ramp_vars_flow_upper_bound,
            :su_sd_ramp_vars_flow_with_high_uptime,
        )
    )

    # constraint 13a - start-up ramping flow difference
    let table_name = :su_ramp_vars_flow_diff, cons = constraints[table_name]
        units_on = cons.expressions[:units_on]
        start_up = cons.expressions[:start_up]
        flow_total = cons.expressions[:outgoing]
        duration = cons.coefficients[:min_outgoing_flow_duration]

        attach_constraint!(
            model,
            cons,
            table_name,
            [
                if row.time_block_start == 1
                    @constraint(model, 0 == 0)
                else
                    p_min = row.min_operating_point * profile_times_capacity[table_name][row.id]

                    average_up, average_up_prime = _calculate_average_ramping_parameters(
                        row.max_su_ramp,
                        row.max_ramp_up,
                        profile_times_capacity[table_name][row.id],
                        duration[row.id],
                    )

                    @constraint(
                        model,
                        flow_total[row.id] - flow_total[row.id-1] <=
                        start_up[row.id] * (average_up - p_min - average_up_prime) +
                        units_on[row.id] * (p_min + average_up_prime) - units_on[row.id-1] * p_min,
                        base_name = "$table_name[$(row.asset),$(row.year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]"
                    )
                end for row in indices_dict[table_name]
            ],
        )
    end

    # constraint 13c - shut-down ramping flow difference
    let table_name = :sd_ramp_vars_flow_diff, cons = constraints[table_name]
        units_on = cons.expressions[:units_on]
        shut_down = cons.expressions[:shut_down]
        flow_total = cons.expressions[:outgoing]
        duration = cons.coefficients[:min_outgoing_flow_duration]

        attach_constraint!(
            model,
            cons,
            table_name,
            [
                if row.time_block_start == 1
                    @constraint(model, 0 == 0)
                else
                    p_min = row.min_operating_point * profile_times_capacity[table_name][row.id-1]

                    average_down, average_down_prime = _calculate_average_ramping_parameters(
                        row.max_sd_ramp,
                        row.max_ramp_down,
                        profile_times_capacity[table_name][row.id],
                        duration[row.id],
                    )

                    @constraint(
                        model,
                        flow_total[row.id-1] - flow_total[row.id] <=
                        shut_down[row.id] * (average_down - p_min - average_down_prime) +
                        units_on[row.id-1] * (p_min + average_down_prime) -
                        units_on[row.id] * p_min,
                        base_name = "$table_name[$(row.asset),$(row.year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]"
                    )
                end for row in indices_dict[table_name]
            ],
        )
    end

    # constraint 13b - start-up ramping flow upper bound
    let table_name = :su_ramp_vars_flow_upper_bound, cons = constraints[table_name]
        units_on = cons.expressions[:units_on]
        start_up = cons.expressions[:start_up]
        shut_down = cons.expressions[:shut_down]
        flow_total = cons.expressions[:outgoing]
        duration = cons.coefficients[:min_outgoing_flow_duration]

        attach_constraint!(
            model,
            cons,
            table_name,
            [
                if row.time_block_start == 1 || (
                    row.units_on_start != row.time_block_start ||
                    row.units_on_end != row.time_block_end
                )
                    @constraint(model, 0 == 0)
                else
                    average_up, average_up_prime = _calculate_average_ramping_parameters(
                        row.max_su_ramp,
                        row.max_ramp_up,
                        profile_times_capacity[table_name][row.id],
                        duration[row.id],
                    )

                    @constraint(
                        model,
                        flow_total[row.id-1] <=
                        p_max * units_on[row.id-1] - start_up[row.id-1] * (p_max - average_up) -
                        shut_down[row.id] * max(average_up - average_down, 0),
                        base_name = "$table_name[$(row.asset),$(row.year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]"
                    )
                end for row in indices_dict[table_name]
            ],
        )
    end

    # constraint 13d - shut-down ramping flow upper bound
    let table_name = :sd_ramp_vars_flow_upper_bound, cons = constraints[table_name]
        units_on = cons.expressions[:units_on]
        start_up = cons.expressions[:start_up]
        shut_down = cons.expressions[:shut_down]
        flow_total = cons.expressions[:outgoing]
        duration = cons.coefficients[:min_outgoing_flow_duration]

        attach_constraint!(
            model,
            cons,
            table_name,
            [
                if row.time_block_start == 1 || (
                    row.units_on_start != row.time_block_start ||
                    row.units_on_end != row.time_block_end
                )
                    @constraint(model, 0 == 0)
                else
                    average_down, average_down_prime = _calculate_average_ramping_parameters(
                        row.max_sd_ramp,
                        row.max_ramp_down,
                        profile_times_capacity[table_name][row.id],
                        duration[row.id],
                    )

                    @constraint(
                        model,
                        flow_total[row.id-1] <=
                        p_max * units_on[row.id-1] - shut_down[row.id] * (p_max - average_down) -
                        start_up[row.id-1] * max(average_down - average_up, 0),
                        base_name = "$table_name[$(row.asset),$(row.year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]"
                    )
                end for row in indices_dict[table_name]
            ],
        )
    end

    # constraint 13e - flow upper bound for min up time >= 2
    let table_name = :su_sd_ramp_vars_flow_with_high_uptime, cons = constraints[table_name]
        units_on = cons.expressions[:units_on]
        start_up = cons.expressions[:start_up]
        shut_down = cons.expressions[:shut_down]
        flow_total = cons.expressions[:outgoing]
        duration = cons.coefficients[:min_outgoing_flow_duration]

        attach_constraint!(
            model,
            cons,
            table_name,
            [
                if row.time_block_start == 1 || (
                    row.units_on_start == row.time_block_start &&
                    row.units_on_end == row.time_block_end
                )
                    @constraint(model, 0 == 0)
                else
                    p_max = profile_times_capacity[table_name][row.id-1]

                    average_up = _calculate_average_su_sd_ramping_parameters(
                        row.max_su_ramp,
                        row.max_ramp_up,
                        profile_times_capacity[table_name][row.id-1],
                        duration[row.id-1],
                    )

                    average_down = _calculate_average_su_sd_ramping_parameters(
                        row.max_sd_ramp,
                        row.max_ramp_down,
                        profile_times_capacity[table_name][row.id-1],
                        duration[row.id-1],
                    )

                    @constraint(
                        model,
                        flow_total[row.id-1] <=
                        p_max * units_on[row.id-1] - start_up[row.id-1] * (p_max - average_up) -
                        shut_down[row.id] * (p_max - average_down),
                        base_name = "$table_name[$(row.asset),$(row.year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]"
                    )
                end for row in indices_dict[table_name]
            ],
        )
    end
end

function _append_su_sd_ramp_vars_data_to_indices(connection, table_name)
    return DuckDB.query(
        connection,
        "SELECT
            cons.*,
            ast_t.capacity,
            ast_t.min_operating_point,
            ast_t.max_ramp_up,
            ast_t.max_ramp_down,
            ast_t.max_su_ramp,
            ast_t.max_sd_ramp,
            ast_t.minimum_up_time,
            assets_profiles.profile_name,
        FROM cons_$table_name AS cons
        LEFT JOIN asset as ast_t
            ON cons.asset = ast_t.asset
        LEFT JOIN assets_profiles
            ON cons.asset = assets_profiles.asset
            AND cons.year = assets_profiles.commission_year
            AND assets_profiles.profile_type = 'availability'
        ORDER BY cons.id
        ",
    )
end
