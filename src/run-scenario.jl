export run_scenario

"""
    energy_problem = run_scenario(connection; optimizer, parameters, write_lp_file, log_file, show_log)

Run the scenario in the given `connection` and return the energy problem.

The `optimizer` and `parameters` keyword arguments can be used to change the optimizer
(the default is HiGHS) and its parameters. The variables are passed to the [`solve_model`](@ref) function.

Set `write_lp_file = true` to export the problem that is sent to the solver to a file for viewing.
Set `show_log = false` to silence printing the log while running.
Specify a `log_file` name to export the log to a file.
"""
function run_scenario(
    connection;
    output_folder = "",
    optimizer = HiGHS.Optimizer,
    model_parameters_file = "",
    parameters = default_parameters(optimizer),
    write_lp_file = false,
    log_file = "",
    show_log = true,
    enable_names = false,
)
    energy_problem = @timeit to "create EnergyProblem from connection" EnergyProblem(
        connection;
        model_parameters_file,
    )

    @timeit to "create_model!" create_model!(energy_problem; write_lp_file, enable_names)

    @timeit to "solve and store solution" solve_model!(energy_problem, optimizer; parameters)

    if output_folder != ""
        @timeit to "save_solution_to_file" save_solution_to_file(output_folder, energy_problem)
    end

    show_log && show(to; compact = true)
    println()

    if log_file != ""
        open(log_file, "w") do io
            show(io, to)
        end
    end

    return energy_problem
end
