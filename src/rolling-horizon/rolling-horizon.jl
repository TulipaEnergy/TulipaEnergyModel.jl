export run_rolling_horizon

include("create.jl")
include("update.jl")
include("utils.jl")

"""
    energy_problem = run_rolling_horizon(
        connection,
        move_forward,
        opt_window_length;
        save_rolling_solution = false,
        compute_duals = true,
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

If `compute_duals` is `true`, then the duals are computed for each internal
problem and the dual solutions are copied for the full problem.

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
    compute_duals = true,
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

    constraint_tables = [
        row.table_name::String for row in DuckDB.query(
            connection,
            "FROM duckdb_tables() WHERE table_name LIKE 'cons_%' AND estimated_size > 0",
        )
    ]

    @timeit to "Prepare table for rolling horizon" prepare_rolling_horizon_tables!(
        connection,
        variable_tables,
        constraint_tables,
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
            constraint_tables,
            window_id,
            move_forward,
            window_start,
            horizon_length,
            save_rolling_solution,
            compute_duals,
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
        constraint_tables,
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
