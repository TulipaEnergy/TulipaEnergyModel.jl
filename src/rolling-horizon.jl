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
    move_forward,
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
    @assert maximum_window_length >= move_forward
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
    @assert move_forward < horizon_length
    @assert maximum_window_length <= horizon_length

    # Create rolling horizon problem
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
    @timeit to "save_solution!" save_solution!(full_energy_problem, compute_duals = false)
    variable_tables = [
        row.table_name::String for row in DuckDB.query(
            connection,
            "FROM duckdb_tables() WHERE table_name LIKE 'var_%' AND estimated_size > 0",
        )
    ]
    for table in variable_tables
        DuckDB.execute(
            connection,
            "ALTER TABLE $table ADD COLUMN IF NOT EXISTS rolling_solution FLOAT8",
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
    for row in DuckDB.query(connection, "FROM duckdb_tables() WHERE temporary")
        DuckDB.query(connection, "DROP TABLE $(row.table_name)")
    end

    # TODO: Instead of modifying existing tables (and risking losing information), allow different table names internally
    DuckDB.query(connection, "UPDATE rep_periods_data SET num_timesteps = $maximum_window_length")
    DuckDB.query(connection, "UPDATE year_data SET length = $maximum_window_length")

    energy_problem = @timeit to "create EnergyProblem from connection" EnergyProblem(
        connection;
        model_parameters_file,
    )

    # The variables that are actually parameters are created here
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

    # No changes
    solved = true
    for window_start in 1:move_forward:horizon_length-move_forward
        window_end = min(window_start + maximum_window_length - 1, horizon_length)
        window_length = window_end - window_start + 1

        if window_length < maximum_window_length
            DuckDB.query(connection, "UPDATE rep_periods_data SET num_timesteps = $window_length")
            DuckDB.query(connection, "UPDATE year_data SET length = $window_length")
        end

        @timeit to "solve_model!" solve_model!(energy_problem)

        @info energy_problem

        if !energy_problem.solved
            solved = false
            break
        end

        @timeit to "save_solution!" save_solution!(energy_problem, compute_duals = false)

        # Save rolling solution
        for table_name in variable_tables
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
            where_condition =
                join(["full_$table_name.$key = $table_name.$key" for key in key_columns], " AND ")
            DuckDB.query(
                connection,
                """
                UPDATE full_$table_name
                SET rolling_solution = $table_name.solution
                FROM $table_name WHERE $where_condition
                    AND full_$table_name.time_block_start = $(window_start - 1) + $table_name.time_block_start
                """,
            )
        end

        # Update model
        @timeit to "update rolling horizon profiles" update_rolling_horizon_profiles!(
            energy_problem.profiles,
            window_start,
            window_end,
        )
        # TODO: Update initial_storage_level
        update_initial_storage_level!(
            energy_problem.variables[:param_initial_storage_level],
            connection,
        )

        energy_problem.solved = false
    end

    energy_problem.solved = solved

    # TODO: Instead of modifying existing tables (and risking losing information), allow different table names internally
    # Undo the changes
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

    # energy_problem.solved = true

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
