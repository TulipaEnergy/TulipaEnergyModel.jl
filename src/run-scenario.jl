export run_scenario

"""
    energy_problem = run_scenario(connection; output_folder, optimizer, parameters, model_parameters_file, write_lp_file, enable_names, log_file, show_log)

Run the scenario in the given `connection` and return the energy problem.

The `optimizer` and `parameters` keyword arguments can be used to change the optimizer
(the default is HiGHS) and its parameters. The variables are passed to the [`solve_model`](@ref) function.

Set `write_lp_file = true` to export the problem that is sent to the solver to a file for viewing.
Set `enable_names = false` to turn off variable and constraint names (faster model creation).
Set `show_log = false` to silence printing the log while running.

Specify a `output_folder` name to export the solution to CSV files.
Specify a `model_parameters_file` name to load the model parameters from a TOML file.
Specify a `log_file` name to export the log to a file.
"""
function run_scenario(
    connection;
    output_folder = "",
    optimizer = HiGHS.Optimizer,
    model_parameters_file = "",
    parameters = default_parameters(optimizer),
    write_lp_file = false,
    enable_names = true,
    log_file = "",
    show_log = true,
)
    energy_problem = @timeit to "create EnergyProblem from connection" EnergyProblem(
        connection;
        model_parameters_file,
    )

    @timeit to "create_model!" create_model!(energy_problem; write_lp_file, enable_names)

    @timeit to "solve_model!" solve_model!(energy_problem, optimizer; parameters)

    @timeit to "save_solution!" save_solution!(energy_problem)

    if output_folder != ""
        @timeit to "export_solution_to_csv_files" export_solution_to_csv_files(
            output_folder,
            energy_problem,
        )
    end

    show_log && show(to)
    println()

    if log_file != ""
        open(log_file, "w") do io
            show(io, to)
            return
        end
    end

    return energy_problem
end
