export run_rolling_horizon

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
    @warn param.container
    variables[:param_initial_storage_level] = param

    return
end

function update_rolling_horizon_profiles!(profiles, window_start, window_end)
    for (_, profile_object) in profiles.rep_period
        window_length = window_end - window_start + 1
        if length(profile_object.rolling_horizon_variables) == window_length
            JuMP.set_parameter_value.(
                profile_object.rolling_horizon_variables,
                profile_object.values[window_start:window_end],
            )
        else
            JuMP.set_parameter_value.(
                profile_object.rolling_horizon_variables[1:window_length],
                profile_object.values[window_start:window_end],
            )
            JuMP.set_parameter_value.(
                profile_object.rolling_horizon_variables[window_length+1:end],
                0.0,
            )
        end
    end

    return
end

function update_initial_storage_level!(param_initial_storage_level::TulipaVariable, connection)
    new_initial_storage_level = [
        row.solution::Float64 for row in DuckDB.query(
            connection,
            """
            SELECT var.solution
            FROM var_storage_level_rep_period AS var
            WHERE var.time_block_start = 1
            """,
        )
    ]
    @warn param_initial_storage_level.container
    @warn new_initial_storage_level
    return JuMP.set_parameter_value.(
        param_initial_storage_level.container,
        new_initial_storage_level,
    )
end

"""
    energy_problem = run_rolling_horizon(
        connection;
        output_folder,
        optimizer,
        optimizer_parameters,
        model_parameters_file,
        model_file_name,
        enable_names,
        log_file,
        show_log
    )

TODO: Update docs
Run the scenario in the given `connection` and return the energy problem.

The `optimizer` and `optimizer_parameters` keyword arguments can be used to change the optimizer
(the default is HiGHS) and its parameters. The arguments are passed to the [`create_model`](@ref) function.

Set `model_file_name = "some-name.lp"` to export the problem that is sent to the solver to a file for viewing (.lp or .mps).
Set `enable_names = false` to turn off variable and constraint names (faster model creation).
Set `direct_model = true` to create a JuMP direct model (faster & less memory).
Set `show_log = false` to silence printing the log while running.

Specify a `output_folder` name to export the solution to CSV files.
Specify a `model_parameters_file` name to load the model parameters from a TOML file.
Specify a `log_file` name to export the log to a file.
"""
function run_rolling_horizon(
    connection,
    maximum_move_forward,
    maximum_window_length;
    output_folder = "",
    optimizer = HiGHS.Optimizer,
    optimizer_parameters = default_parameters(optimizer),
    model_parameters_file = "",
    model_file_name = "",
    enable_names = true,
    direct_model = false,
    log_file = "",
    show_log = true,
)
    # Validation that the input data must satisfy to run rolling horizon
    # TODO: Should this be in data_validation?
    @assert maximum_window_length >= maximum_move_forward
    for row in DuckDB.query(
        connection,
        "SELECT year, max(rep_period) as num_rep_periods
        FROM rep_periods_data
        GROUP BY year",
    )
        @assert row.num_rep_periods == 1
    end
    horizon_length = get_single_element_from_query_and_ensure_its_only_one(
        DuckDB.query(connection, "SELECT max(timestep) FROM profiles_rep_periods"),
    )
    @assert maximum_move_forward < horizon_length
    @assert maximum_window_length <= horizon_length

    # Rolling horizon info table
    DuckDB.query(
        connection,
        """
        CREATE OR REPLACE TABLE rolling_horizon_window (
            id INTEGER,
            window_start INTEGER,
            maximum_move_forward INTEGER,
            opt_window_length INTEGER,
            objective_solution FLOAT8,
        );
        """,
    )

    # Create no-rolling problem
    # TODO: How much to we need to build? Indices are enough?
    full_energy_problem = @timeit to "create Rolling Horizon EnergyProblem" EnergyProblem(
        connection;
        model_parameters_file,
    )
    @timeit to "create_model!" create_model!(
        full_energy_problem;
        optimizer,
        optimizer_parameters,
        model_file_name,
        enable_names,
        direct_model,
    )
    @timeit to "solve_model!" solve_model!(full_energy_problem)
    # @timeit to "save_solution!" save_solution!(full_energy_problem, compute_duals = false)

    # These are all the non-empty variable tables
    # TODO: We possibly don't need all of them
    variable_tables = [
        row.table_name::String for row in DuckDB.query(
            connection,
            "FROM duckdb_tables() WHERE table_name LIKE 'var_%' AND estimated_size > 0",
        )
    ]

    # Preparing the table to save the rolling solution
    # TODO: Currently we save it twice, we should check what we want
    for table in variable_tables
        # Add a column rolling_solution to no-rolling variable tables
        # TODO: It might be better to not separate solution vs rolling_solution
        DuckDB.execute(
            connection,
            "ALTER TABLE $table ADD COLUMN IF NOT EXISTS rolling_solution FLOAT8",
        )
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

    # Create backup tables for rep_periods_data, year_data, and asset_milestone
    # and full tables for the variables
    backup_tables = ["rep_periods_data", "year_data", "asset_milestone"]
    for table_name in [backup_tables; variable_tables]
        DuckDB.query(
            connection,
            "CREATE OR REPLACE TABLE full_$table_name AS SELECT * FROM $table_name",
        )
    end

    # Drop all temporary tables to avoid conflict (shouldn't happen anyway)
    for row in DuckDB.query(connection, "FROM duckdb_tables() WHERE temporary")
        DuckDB.query(connection, "DROP TABLE $(row.table_name)")
    end

    # Modify tables that keep horizon information to limit the horizon to the rolling window
    # TODO: Instead of modifying existing tables (and risking losing information), allow different table names internally (this is a larger issue)
    DuckDB.query(connection, "UPDATE rep_periods_data SET num_timesteps = $maximum_window_length")
    DuckDB.query(connection, "UPDATE year_data SET length = $maximum_window_length")

    # Rolling horizon problem
    energy_problem = @timeit to "create EnergyProblem from connection" EnergyProblem(
        connection;
        model_parameters_file,
    )

    # The rolling horizon Parameters are created here. The model has the size of
    # the `maximum_window_length` even if all not all variables are used. This
    # maximum is limited by the horizon_length because of the validation.
    @timeit to "create_model!" create_model!(
        energy_problem;
        optimizer,
        optimizer_parameters,
        model_file_name,
        enable_names,
        direct_model,
        rolling_horizon = true,
        rolling_horizon_window_length = maximum_window_length,
    )

    # Loop over the windows, solve, save, update, repeat
    solved = true
    for (rolling_horizon_id, window_start) in enumerate(1:maximum_move_forward:horizon_length)
        # Windows might be shorter than expected due to horizon end
        move_forward =
            min(window_start + maximum_move_forward - 1, horizon_length) - window_start + 1
        window_end = min(window_start + maximum_window_length - 1, horizon_length)
        opt_window_length = window_end - window_start + 1
        @info "DEBUG" window_end, move_forward, opt_window_length

        # If this window is too large, we decrease the rep_periods_data
        if opt_window_length < maximum_window_length
            DuckDB.query(
                connection,
                "UPDATE rep_periods_data SET num_timesteps = $opt_window_length",
            )
            DuckDB.query(connection, "UPDATE year_data SET length = $opt_window_length")
        end

        # Update Parameters in the model (even for the first time)
        @timeit to "update rolling horizon profiles" update_rolling_horizon_profiles!(
            energy_problem.profiles,
            window_start,
            window_start + opt_window_length - 1,
        )
        # TODO: Update other scalar parameters
        if rolling_horizon_id > 1 # Don't try to update the first initial values
            update_initial_storage_level!(
                energy_problem.variables[:param_initial_storage_level],
                connection,
            )
        end

        @timeit to "solve_model!" solve_model!(energy_problem)
        @info "objective" energy_problem.objective_value # DEBUG

        # Save window to table rolling_horizon_window
        objective_solution = if isnothing(energy_problem.objective_value)
            "NULL"
        else
            string(energy_problem.objective_value)
        end
        DuckDB.query(
            connection,
            """
            INSERT INTO rolling_horizon_window
            VALUES ($rolling_horizon_id, $window_start, $move_forward, $opt_window_length, $objective_solution);
            """,
        )

        # @info energy_problem # DEBUG

        if !energy_problem.solved
            solved = false
            break
        end

        @timeit to "save_solution!" save_solution!(energy_problem, compute_duals = false)

        # Save rolling solution of each variable
        for table_name in variable_tables
            # Guessing which columns should be used as key for matching with the larger no-rolling variables
            # TODO: Use the schema for this matching
            key_columns = [
                row.column_name for row in DuckDB.query(
                    connection,
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

            # Attach solution in the optimisation window to the full table
            # TODO: Maybe we don't want to do this, check earlier TODO comments
            DuckDB.query(
                connection,
                """
                UPDATE full_$table_name
                SET rolling_solution = $table_name.solution
                FROM $table_name WHERE $where_condition
                    AND full_$table_name.time_block_start = $(window_start - 1) + $table_name.time_block_start
                    AND $table_name.time_block_end <= $opt_window_length -- only save the optimisation window
                """,
            )

            # Store the solution in the corresponding rolling_solution_$table_name
            # This also uses the `where_condition`, but to join the no-rolling and rolling variable tables
            DuckDB.query(
                connection,
                """
                WITH cte_var_solution AS (
                    SELECT
                        $rolling_horizon_id as window_id,
                        full_$table_name.id as var_id, -- the ids are from the main model
                        $table_name.solution
                    FROM $table_name
                    LEFT JOIN full_$table_name
                        ON $where_condition -- this condition should match
                        AND full_$table_name.time_block_start = $(window_start - 1) + $table_name.time_block_start
                    WHERE
                        $table_name.time_block_end <= $opt_window_length -- limiting the time_block_end by the actual opt_window_length to ignore extra variables in the last window
                )
                INSERT INTO rolling_solution_$table_name
                SELECT *
                FROM cte_var_solution
                """,
            )
        end

        energy_problem.solved = false
    end

    energy_problem.solved = solved

    # Undo the changes to rep_periods_data and year_data
    # TODO: Instead of modifying existing tables (and risking losing information), allow different table names internally
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

    # Export solution
    # TODO: Figure out what needs to change to export the solution
    # if output_folder != ""
    #     if energy_problem.solved
    #         @timeit to "export_solution_to_csv_files" export_solution_to_csv_files(
    #             output_folder,
    #             energy_problem,
    #         )
    #     else
    #         @warn "The energy problem has not been solved yet. Skipping export solution."
    #     end
    # end

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

    return energy_problem
end
