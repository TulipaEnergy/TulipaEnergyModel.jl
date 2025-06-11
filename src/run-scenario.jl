export run_scenario

"""
    energy_problem = run_scenario(
        connection;
        output_folder,
        optimizer,
        optimizer_parameters,
        model_parameters_file,
        model_file_name,
        enable_names,
        log_file,
        show_log)

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
function run_scenario(
    connection;
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
    energy_problem = @timeit to "create EnergyProblem from connection" EnergyProblem(
        connection;
        model_parameters_file,
    )

    @timeit to "create_model!" create_model!(
        energy_problem;
        optimizer,
        optimizer_parameters,
        model_file_name,
        enable_names,
        direct_model,
    )

    @timeit to "solve_model!" solve_model!(energy_problem)

    @timeit to "save_solution!" save_solution!(energy_problem)

    if output_folder != "" && energy_problem.solved
        @timeit to "export_solution_to_csv_files" export_solution_to_csv_files(
            output_folder,
            energy_problem,
        )
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

    return energy_problem
end
