
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
    # Match the parameter with the variable
    # Select the variable solution
    # Filter by time_block_end = $move_forward
    # Order by parameter id
    # This should result in a new value for the initial value in the same order
    # as when it was created
    new_initial_storage_level = [
        row.solution::Float64 for row in DuckDB.query(
            connection,
            """
            SELECT
                param.id,
                var.solution
            FROM param_initial_storage_level AS param
            LEFT JOIN var_storage_level_rep_period AS var
                ON param.asset = var.asset
                AND param.milestone_year = var.milestone_year
                AND param.rep_period = var.rep_period
            WHERE var.time_block_end = $move_forward
            ORDER BY param.id
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
