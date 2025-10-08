export run_rolling_horizon

"""
    add_rolling_horizon_parameters!(connection, model, variables, profiles, window_length)

Create Parameters to handle rolling horizon.

The profile parameters are attached to `profiles.rep_period`.

The other parameters are the ones that have initial value (currently only initial_storage_level).
These must be filtered from the corresponding indices table when time_block_start = 1.
The corresponding parameters is saved in the variables and in the model.
"""
function add_rolling_horizon_parameters!(connection, model, variables, profiles, window_length)
    # Profiles
    for (_, profile_object) in profiles.rep_period
        profile_object.rolling_horizon_variables =
            @variable(model, [1:window_length] in JuMP.Parameter(0.0))
    end

    # initial_storage_level
    # Storing inside the variables, for now TODO: Review if there is a better strategy after all parameters have been defined
    DuckDB.query(
        connection,
        """
        DROP SEQUENCE IF EXISTS id;
        CREATE SEQUENCE id START 1;
        CREATE OR REPLACE TABLE param_initial_storage_level AS
        SELECT
            nextval('id') as id,
            var.asset,
            var.year,
            var.rep_period,
            var.id as var_storage_id,
            asset_milestone.initial_storage_level as original_value
        FROM var_storage_level_rep_period as var
        LEFT JOIN asset_milestone
            ON var.asset = asset_milestone.asset
            AND var.year = asset_milestone.milestone_year
        WHERE time_block_start = 1;
        DROP SEQUENCE id;
        """,
    )
    initial_storage_level = [
        row.original_value::Float64 for
        row in DuckDB.query(connection, "FROM param_initial_storage_level")
    ]
    num_rows = length(initial_storage_level)
    param = TulipaVariable(connection, "param_initial_storage_level")
    model[:param_initial_storage_level] =
        param.container = @variable(model, [1:num_rows] in JuMP.Parameter.(initial_storage_level))
    variables[:param_initial_storage_level] = param

    return
end

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

"""
    validate_rolling_horizon_input(connection, move_forward, opt_window)

Validation of the rolling horizon input:
- opt_window_length ≥ move_forward
- Only one representative period per year
- Only 'uniform' partitions are allowed
- Only partitions that exactly divide opt_window_length are allowed
"""
function validate_rolling_horizon_input(connection, move_forward, opt_window_length)
    @assert opt_window_length >= move_forward
    for row in DuckDB.query(
        connection,
        "SELECT year, max(rep_period) as num_rep_periods
        FROM rep_periods_data
        GROUP BY year",
    )
        @assert row.num_rep_periods == 1
    end
    partition_tables = [
        row.table_name for row in
        DuckDB.query(connection, "FROM duckdb_tables() WHERE table_name LIKE '%_partitions'")
    ]

    for table_name in partition_tables
        for row in DuckDB.query(connection, "FROM $table_name")
            @assert row.specification == "uniform" "Only 'uniform' specification is accepted"
            partition = tryparse(Int, row.partition)
            @assert !isnothing(partition) "Invalid partition"
            @assert opt_window_length % partition == 0
        end
    end

    return
end

"""
    prepare_rolling_horizon_tables!(connection, variable_tables, save_rolling_solution, opt_window_length)

Modify and create tables to prepare to start the rolling horizon execution.
The changes are:

- Stored the original variable tables as `full_var_%` per variable table
- Add `solution` column to each full variable table.
- If `save_rolling_solution`, create the `rolling_solution_var_%` tables per variable table.
- Backup `rep_periods_data` and `year_data` into `full_rep_periods_data` and `full_year_data`.
- Modify `rep_periods_data` and `year_data` to use `opt_window_length` as `num_timesteps`/`length`, respectively.
"""
function prepare_rolling_horizon_tables!(
    connection,
    variable_tables,
    save_rolling_solution,
    opt_window_length,
)
    # Preparing the table to save the rolling solution
    for table in variable_tables
        # Add a column solution to no-rolling variable tables
        DuckDB.execute(connection, "ALTER TABLE $table ADD COLUMN IF NOT EXISTS solution FLOAT8")

        if save_rolling_solution
            # Save solutions with a table linking the window to the id of the (no-rolling) variable
            DuckDB.execute(
                connection,
                """
                CREATE OR REPLACE TABLE rolling_solution_$table (
                    window_id INTEGER,
                    var_id INTEGER,
                    solution FLOAT8,
                );
                """,
            )
        end
    end

    # Create backup tables for rep_periods_data, year_data, and asset_milestone
    # and full tables for the variables
    backup_tables = ["rep_periods_data", "year_data"]
    for table_name in [backup_tables; variable_tables]
        DuckDB.query(
            connection,
            "CREATE OR REPLACE TABLE full_$table_name AS
            SELECT *, NULL AS solution
            FROM $table_name",
        )
    end

    # Modify tables that keep horizon information to limit the horizon to the rolling window
    DuckDB.query(connection, "UPDATE rep_periods_data SET num_timesteps = $opt_window_length")
    DuckDB.query(connection, "UPDATE year_data SET length = $opt_window_length")

    return
end

"""
    save_solution_into_tables!(energy_problem, variable_tables, window_id, move_forward, window_start, horizon_length, save_rolling_solution)

Save the current rolling horizon solution from the model into the connection.
This involves:
- Calling [`save_solution!`](@ref) to copy the internal solution from the JuMP model to the connection.
- Copying the solution from the internal variables to the full variables for the `move_forward` sub-window.
- If `save_rolling_solution`, save the complete rolling solution in the table `rolling_solution_var_%` per variable table.
"""
function save_solution_into_tables!(
    energy_problem,
    variable_tables,
    window_id,
    move_forward,
    window_start,
    horizon_length,
    save_rolling_solution,
)
    @timeit to "Save internal rolling horizon solution to connection" save_solution!(
        energy_problem,
        compute_duals = false,
    )
    # Save rolling solution of each variable
    for table_name in variable_tables
        # Guessing which columns should be used as key for matching with the larger no-rolling variables
        # TODO: Use the schema for this matching?
        key_columns = [
            row.column_name for row in DuckDB.query(
                energy_problem.db_connection,
                """
                FROM duckdb_columns
                WHERE table_name = '$table_name'
                    AND column_name IN ('asset', 'from_asset', 'to_asset',
                        'milestone_year', 'commission_year', 'year', 'rep_period')
                """,
            )
        ]

        # Construct the WHERE condition matching the keys
        where_condition =
            join(["full_$table_name.$key = $table_name.$key" for key in key_columns], " AND ")

        # Save solution to full table
        DuckDB.query(
            energy_problem.db_connection,
            """
            UPDATE full_$table_name
            SET solution = $table_name.solution
            FROM $table_name WHERE $where_condition
                AND full_$table_name.time_block_start = ($(window_start - 1) + $table_name.time_block_start - 1) % $horizon_length + 1
                AND $table_name.time_block_end <= $move_forward -- only save the move_forward window
            """,
        )

        if save_rolling_solution
            # Store the solution in the corresponding rolling_solution_$table_name
            # This also uses the `where_condition`, but to join the no-rolling and rolling variable tables
            DuckDB.query(
                energy_problem.db_connection,
                """
                WITH cte_var_solution AS (
                    SELECT
                        $window_id as window_id,
                        full_$table_name.id as var_id, -- the ids are from the main model
                        $table_name.solution
                    FROM $table_name
                    LEFT JOIN full_$table_name
                        ON $where_condition -- this condition should match
                        AND full_$table_name.time_block_start = ($(window_start - 1) + $table_name.time_block_start - 1) % $horizon_length + 1
                )
                INSERT INTO rolling_solution_$table_name
                SELECT *
                FROM cte_var_solution
                """,
            )
        end
    end

    return
end

"""
    prepare_tables_to_leave_rolling_horizon!(connection, variable_tables)

Undo some of the changes done by [`prepare_rolling_horizon_tables`] to go back to the original input data.
This involves:
- Revert `rep_periods_data` and `year_data` to their original values.
- Drop the internal variable tables and replace them with the full variable tables.
"""
function prepare_tables_to_leave_rolling_horizon!(connection, variable_tables)
    DuckDB.query(
        connection,
        "UPDATE rep_periods_data
        SET num_timesteps = full_rep_periods_data.num_timesteps
        FROM full_rep_periods_data
        WHERE rep_periods_data.year = full_rep_periods_data.year
            AND rep_periods_data.rep_period = full_rep_periods_data.rep_period",
    )
    DuckDB.query(
        connection,
        "UPDATE year_data
        SET length = full_year_data.length
        FROM full_year_data
        WHERE year_data.year = full_year_data.year
        ",
    )

    # Drop the rolling horizon variable tables and rename the full_var_% tables
    for table_name in variable_tables
        DuckDB.query(connection, "DROP TABLE IF EXISTS $table_name")
        DuckDB.query(connection, "ALTER TABLE full_$table_name RENAME TO $table_name")
    end

    return
end

"""
    energy_problem = run_rolling_horizon(
        connection,
        move_forward,
        opt_window_length;
        save_rolling_solution = false,
        kwargs...
    )

Run the scenario in the given `connection` as a rolling horizon and return the energy problem.

Our implementation of rolling horizon uses a moving window with size
`opt_window_length` that is moved ahead each iteration by `move_forward`.
The solution of the variables in the `move_forward` window are saved between iterations.

We implement a model with fixed size given by the `opt_window_length`.
The `EnergyProblem` with this internal model is stored internally inside the
returned `EnergyProblem` on field `rolling_horizon_energy_problem`.

The termination status of the returned `EnergyProblem` is the same as the
termination status of the last solved window.
In other words, it is OPTIMAL if all windows were solved optimally. Otherwise,
the last solved window will be non-optimal, and the issue will be returned.

The table `rolling_horizon_window` stores the window information.

If `save_rolling_solution` is `true`, the tables `rolling_solution_var_%` will
be created for each non-empty variable. These can be used for debugging purposes.

The parameters associated with the profiles are stored in
`rolling_horizon_energy_problem.profiles`, in the respective
`rolling_horizon_variables`.

The other rolling parameters are stored in tables `param_%` and
`rolling_horizon_energy_problem.variables` under the same name.

This function also accepts other keyword arguments also accepted by [`run_scenario`](@ref).
"""
function run_rolling_horizon(
    connection,
    move_forward,
    opt_window_length;
    output_folder = "",
    optimizer = HiGHS.Optimizer,
    optimizer_parameters = default_parameters(optimizer),
    model_parameters_file = "",
    model_file_name = "",
    enable_names = true,
    direct_model = false,
    log_file = "",
    show_log = true,
    save_rolling_solution = false,
)
    # Validation that the input data must satisfy to run rolling horizon
    @timeit to "Validate rolling horizon input" validate_rolling_horizon_input(
        connection,
        move_forward,
        opt_window_length,
    )

    horizon_length = get_single_element_from_query_and_ensure_its_only_one(
        DuckDB.query(connection, "SELECT max(timestep) FROM profiles_rep_periods"),
    )

    # Rolling horizon info table
    DuckDB.query(
        connection,
        """
        CREATE OR REPLACE TABLE rolling_horizon_window (
            id INTEGER,
            window_start INTEGER,
            move_forward INTEGER,
            opt_window_length INTEGER,
            objective_value FLOAT8,
        );
        """,
    )

    # Create no-rolling problem
    full_energy_problem = @timeit to "Create Rolling Horizon EnergyProblem" EnergyProblem(
        connection;
        model_parameters_file,
    )

    # These are all the non-empty variable tables
    variable_tables = [
        row.table_name::String for row in DuckDB.query(
            connection,
            "FROM duckdb_tables() WHERE table_name LIKE 'var_%' AND estimated_size > 0",
        )
    ]

    @timeit to "Prepare table for rolling horizon" prepare_rolling_horizon_tables!(
        connection,
        variable_tables,
        save_rolling_solution,
        opt_window_length,
    )

    energy_problem = @timeit to "Create internal EnergyProblem for rolling horizon" EnergyProblem(
        connection;
        model_parameters_file,
    )

    # The rolling horizon Parameters are created here. The model has the size of
    # the `opt_window_length`.
    @timeit to "Create internal rolling horizon model" create_model!(
        energy_problem;
        optimizer,
        optimizer_parameters,
        model_file_name,
        enable_names,
        direct_model,
        rolling_horizon = true,
        rolling_horizon_window_length = opt_window_length,
    )

    # Loop over the windows, solve, save, update, repeat
    solved = true
    for (window_id, window_start) in enumerate(1:move_forward:horizon_length)
        # Update Parameters in the model (even for the first time)
        @timeit to "update rolling horizon profiles" update_rolling_horizon_profiles!(
            energy_problem.profiles,
            window_start,
            window_start + opt_window_length - 1,
        )
        if window_id > 1 # Don't try to update the first initial values
            @timeit to "update scalar parameters" update_scalar_parameters!(
                energy_problem.variables,
                connection,
                move_forward,
            )
        end

        @timeit to "Solve internal rolling horizon model" solve_model!(energy_problem)

        # Save window to table rolling_horizon_window
        objective_value = if isnan(energy_problem.objective_value)
            "NULL"
        else
            string(energy_problem.objective_value)
        end
        DuckDB.query(
            connection,
            """
            INSERT INTO rolling_horizon_window
            VALUES ($window_id, $window_start, $move_forward, $opt_window_length, $objective_value);
            """,
        )

        if !energy_problem.solved
            solved = false
            break
        end

        @timeit to "Save window solution" save_solution_into_tables!(
            energy_problem,
            variable_tables,
            window_id,
            move_forward,
            window_start,
            horizon_length,
            save_rolling_solution,
        )

        energy_problem.solved = false
    end

    energy_problem.solved = solved

    # Propagate information to main model
    full_energy_problem.solved = solved
    full_energy_problem.termination_status = energy_problem.termination_status
    full_energy_problem.rolling_horizon_energy_problem = energy_problem

    # Undo the changes to rep_periods_data and year_data
    @timeit to "undo changes to rolling horizon tables" prepare_tables_to_leave_rolling_horizon!(
        connection,
        variable_tables,
    )

    # Export solution
    if output_folder != ""
        if energy_problem.solved
            @timeit to "export_solution_to_csv_files" export_solution_to_csv_files(
                output_folder,
                energy_problem,
            )
        else
            @warn "The energy problem has not been solved yet. Skipping export solution."
        end
    end

    if show_log
        show(to)
        println()
    end

    if log_file != ""
        open(log_file, "w") do io
            show(io, to)
            return
        end
    end

    return full_energy_problem
end
