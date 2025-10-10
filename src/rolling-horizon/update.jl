
"""
    update_rolling_horizon_profiles!(profiles, window_start, window_end)

Update the profile parameters to use the window window_start:window_end.
"""
function update_rolling_horizon_profiles!(profiles, window_start, window_end)
    for (_, profile_object) in profiles.rep_period
        profile_length = length(profile_object.values)
        JuMP.set_parameter_value.(
            profile_object.rolling_horizon_variables,
            profile_object.values[mod1.(window_start:window_end, profile_length)],
        )
    end

    return
end

"""
    update_initial_storage_level!(param_initial_storage_level, connection, move_forward)

Update the initial_storage_level parameter to use the new value at time_block_end=move_forward
"""
function update_initial_storage_level!(
    param_initial_storage_level::TulipaVariable,
    connection,
    move_forward,
)
    new_initial_storage_level = [
        row.solution::Float64 for row in DuckDB.query(
            connection,
            """
            SELECT var.solution
            FROM var_storage_level_rep_period AS var
            WHERE var.time_block_end = $move_forward
            """,
        )
    ]
    return JuMP.set_parameter_value.(
        param_initial_storage_level.container,
        new_initial_storage_level,
    )
end

"""
    update_scalar_parameters!(variables, connection, move_forward)

Update scalar parameters, i.e., the ones that have an initial value that changes
between windows.
"""
function update_scalar_parameters!(variables, connection, move_forward)
    return update_initial_storage_level!(
        variables[:param_initial_storage_level],
        connection,
        move_forward,
    )
end
