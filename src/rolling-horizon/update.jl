
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
    update_initial_storage_level!(
        param_initial_storage_level,
        available_energy_capacity,
        connection,
        move_forward,
    )

Update the initial_storage_level parameter in p.u. using the new storage level at
`time_block_end=move_forward` and the solved available energy capacity.
"""
function update_initial_storage_level!(
    param_initial_storage_level::TulipaVariable,
    available_energy_capacity,
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
        begin
            energy_capacity =
                JuMP.value(available_energy_capacity[row.available_energy_capacity_id::Int])
            if iszero(energy_capacity)
                0.0
            else
                clamp(row.solution::Float64 / energy_capacity, 0.0, 1.0)
            end
        end for row in DuckDB.query(
            connection,
            """
            SELECT
                param.id,
                param.available_energy_capacity_id,
                var.solution
            FROM param_initial_storage_level AS param
            LEFT JOIN var_storage_level_intra_rep_period AS var
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
function update_scalar_parameters!(variables, expressions, connection, move_forward)
    available_energy_capacity =
        expressions[:available_energy_capacity_aggregated_vintage_method].expressions[:energy_capacity]
    return update_initial_storage_level!(
        variables[:param_initial_storage_level],
        available_energy_capacity,
        connection,
        move_forward,
    )
end
