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
    parameters = default_parameters(optimizer),
    write_lp_file = false,
    log_file = "",
    show_log = true,
)
    energy_problem = @timeit to "create_energy_problem_from_csv_folder" EnergyProblem(connection)

    @timeit to "create_model!" create_model!(energy_problem; write_lp_file = write_lp_file)

    @timeit to "solve and store solution" solve_model!(
        energy_problem,
        optimizer;
        parameters = parameters,
    )

    if output_folder != ""
        @timeit to "save_solution_to_file" save_solution_to_file(output_folder, energy_problem)
    end

    show_log && show(to)
    println()

    if log_file != ""
        open(log_file, "w") do io
            show(io, to)
        end
    end

    return energy_problem
end

"""
    energy_problem = run_scenario(input_folder[, output_folder; optimizer, parameters, write_lp_file, log_file, show_log])

Run the scenario in the given `input_folder` and return the energy problem.
The `output_folder` is optional. If it is specified, save the sets, parameters, and solution to the `output_folder`.

The `optimizer` and `parameters` keyword arguments can be used to change the optimizer
(the default is HiGHS) and its parameters. The variables are passed to the [`solve_model`](@ref) function.

Set `write_lp_file = true` to export the problem that is sent to the solver to a file for viewing.
Set `show_log = false` to silence printing the log while running.
Specify a `log_file` name to export the log to a file.

"""

function run_scenario(
    input_folder::AbstractString,
    output_folder::String = "";
    optimizer = HiGHS.Optimizer,
    parameters = default_parameters(optimizer),
    write_lp_file = false,
    log_file = "",
    show_log = true,
)
    connection = create_connection_and_import_from_csv_folder(input_folder)

    return run_scenario(
        connection;
        output_folder,
        optimizer,
        parameters,
        write_lp_file,
        log_file,
        show_log,
    )
end
