export add_su_sd_ramping_constraints_compact!
export add_su_sd_ramping_constraints_tight!

"""
    add_su_sd_ramping_constraints_compact!(model, constraints)
Adds the start-up and shut-down ramping constraints to the model.
(11a), (11c)
"""
function add_su_sd_ramping_constraints_compact!(
    connection,
    model,
    variables,
    expressions,
    constraints,
    profiles,
)
    # A way to check if any constraints for this index were defined
    constraintsPresent = false
    for row in constraints[:su_ramping_compact_1bin].indices
        constraintsPresent = true
        break
    end

    # If the constraints at this index not defined,
    # this means that no constraints should be added
    if (!constraintsPresent)
        return
    end

    # Warn: runs SQL query. Guarded by `if` statement above
    indices_dict = Dict(
        table_name => _append_su_sd_ramping_data_to_indices(connection, table_name) for
        table_name in (:su_ramping_compact_1bin, :sd_ramping_compact_1bin)
    )

    # Compute ` P^{availability profile} * P^{capacity}`
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
        end for table_name in (:su_ramping_compact_1bin, :sd_ramping_compact_1bin)
    )

    # Start-Up ramping constraint --> (11a)
    let table_name = :su_ramping_compact_1bin, cons = constraints[table_name]
        indices = indices_dict[table_name]
        units_on = cons.expressions[:units_on]
        attach_constraint!(
            model,
            cons,
            table_name,
            [
                if row.time_block_start == 1
                    @constraint(model, 0 == 0) # Placeholder for case k = 1
                elseif cons.expressions[:outgoing][row.id] == cons.expressions[:outgoing][row.id-1]
                    @constraint(model, 0 == 0) # No extra constraint if it is the same flow variable
                else
                    start_up_avg = _calculate_average_su_sd_ramping_parameters(
                        row.max_su_ramp,
                        row.max_ramp_up,
                        profile_times_capacity[table_name][row.id],
                        min_outgoing_flow_duration,
                    )

                    @constraint(
                        model,
                        cons.expressions[:outgoing][row.id] -
                        cons.expressions[:outgoing][row.id-1] ≤
                        (start_up_avg * units_on[row.id]) -
                        (
                            row.max_su_ramp * profile_times_capacity[table_name][row.id] -
                            row.max_ramp_up * profile_times_capacity[table_name][row.id]
                        ) * units_on[row.id-1],
                        base_name = "$table_name[$(row.asset),$(row.year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]"
                    )
                end for (row, min_outgoing_flow_duration) in
                zip(indices, cons.coefficients[:min_outgoing_flow_duration])
            ],
        )
    end

    # Shut-Down ramping constraint --> (11c)
    let table_name = :sd_ramping_compact_1bin, cons = constraints[table_name]
        indices = indices_dict[table_name]
        units_on = cons.expressions[:units_on]
        attach_constraint!(
            model,
            cons,
            table_name,
            [
                if row.time_block_start == 1
                    @constraint(model, 0 == 0) # Placeholder for case k = 1
                elseif cons.expressions[:outgoing][row.id] == cons.expressions[:outgoing][row.id-1]
                    @constraint(model, 0 == 0) # No extra constraint if it is the same flow variable
                else
                    shut_down_avg = _calculate_average_su_sd_ramping_parameters(
                        row.max_sd_ramp,
                        row.max_ramp_down,
                        profile_times_capacity[table_name][row.id-1],
                        cons.coefficients[:min_outgoing_flow_duration][row.id-1],
                    )

                    @constraint(
                        model,
                        cons.expressions[:outgoing][row.id-1] -
                        cons.expressions[:outgoing][row.id] ≤
                        shut_down_avg * units_on[row.id-1] -
                        (
                            row.max_sd_ramp * profile_times_capacity[table_name][row.id-1] -
                            row.max_ramp_down * profile_times_capacity[table_name][row.id-1]
                        ) * units_on[row.id],
                        base_name = "$table_name[$(row.asset),$(row.year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]"
                    )
                end for row in indices
            ],
        )
    end
end

"""
    add_su_sd_ramping_constraints_tight!(model, constraints)
Adds the tighter start-up and shut-down ramping constraints to the model.
(12a), (12b)
"""
function add_su_sd_ramping_constraints_tight!(
    connection,
    model,
    variables,
    expressions,
    constraints,
    profiles,
)
    # A way to check if any constraints for this index were defined
    constraintsPresent = false
    for row in constraints[:su_ramping_tight_1bin].indices
        constraintsPresent = true
        break
    end

    # If the constraints at this index not defined,
    # this means that no constraints should be added
    if (!constraintsPresent)
        return
    end

    # Warn: runs SQL query. Guarded by `if` statement above
    indices_dict = Dict(
        table_name => _append_su_sd_ramping_data_to_indices(connection, table_name) for
        table_name in (:su_ramping_tight_1bin, :sd_ramping_tight_1bin)
    )

    # Compute ` P^{availability profile} * P^{capacity}`
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
        end for table_name in (:su_ramping_tight_1bin, :sd_ramping_tight_1bin)
    )

    # Start-Up ramping constraint --> (12a)
    let table_name = :su_ramping_tight_1bin, cons = constraints[table_name]
        indices = indices_dict[table_name]
        units_on = cons.expressions[:units_on]
        attach_constraint!(
            model,
            cons,
            table_name,
            [
                if row.time_block_start == 1
                    @constraint(model, 0 == 0) # Placeholder for case k = 1
                else
                    start_up_avg = _calculate_average_su_sd_ramping_parameters(
                        row.max_su_ramp,
                        row.max_ramp_up,
                        profile_times_capacity[table_name][row.id],
                        min_outgoing_flow_duration,
                    )

                    @constraint(
                        model,
                        cons.expressions[:outgoing][row.id] ≤
                        (start_up_avg * units_on[row.id]) +
                        (profile_times_capacity[table_name][row.id] - start_up_avg) *
                        units_on[row.id-1],
                        base_name = "$table_name[$(row.asset),$(row.year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]"
                    )
                end for (row, min_outgoing_flow_duration) in
                zip(indices, cons.coefficients[:min_outgoing_flow_duration])
            ],
        )
    end

    # Shut-Down ramping constraint --> (12b)
    let table_name = :sd_ramping_tight_1bin, cons = constraints[table_name]
        indices = indices_dict[table_name]
        units_on = cons.expressions[:units_on]
        attach_constraint!(
            model,
            cons,
            table_name,
            [
                if row.time_block_start == 1
                    @constraint(model, 0 == 0) # Placeholder for case k = 1
                else
                    shut_down_avg = _calculate_average_su_sd_ramping_parameters(
                        row.max_sd_ramp,
                        row.max_ramp_down,
                        profile_times_capacity[table_name][row.id-1],
                        cons.coefficients[:min_outgoing_flow_duration][row.id-1],
                    )

                    @constraint(
                        model,
                        cons.expressions[:outgoing][row.id-1] ≤
                        (shut_down_avg * units_on[row.id-1]) +
                        (profile_times_capacity[table_name][row.id-1] - shut_down_avg) *
                        units_on[row.id],
                        base_name = "$table_name[$(row.asset),$(row.year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]"
                    )
                end for row in indices
            ],
        )
    end
end

function _append_su_sd_ramping_data_to_indices(connection, table_name)
    return DuckDB.query(
        connection,
        "SELECT
            cons.*,
            assett.capacity,
            assett.min_operating_point,
            assett.max_ramp_up,
            assett.max_ramp_down,
            assett.max_su_ramp,
            assett.max_sd_ramp,
            assets_profiles.profile_name,
        FROM cons_$table_name AS cons
        LEFT JOIN asset as assett
            ON cons.asset = assett.asset
        LEFT OUTER JOIN assets_profiles
            ON cons.asset = assets_profiles.asset
            AND cons.year = assets_profiles.commission_year
            AND assets_profiles.profile_type = 'availability'
        ORDER BY cons.id
        ",
    )
end
