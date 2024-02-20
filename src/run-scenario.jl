export run_scenario

"""
    energy_problem = run_scenario(input_folder[, output_folder; optimizer, parameters])

Run the scenario in the given `input_folder` and return the energy problem.
The `output_folder` is optional. If it is specified, save the sets, parameters, and solution to the `output_folder`.

The `optimizer` and `parameters` keyword arguments can be used to change the default optimizer
(which is HiGHS) and its parameters. The variables are passed to the [`solve_model`](@ref) function.
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
    to = TimerOutput()

    elapsed_time_read_data = @elapsed begin
        energy_problem =
            @timeit to "create_energy_problem_from_csv_folder" create_energy_problem_from_csv_folder(
                input_folder,
            )
    end

    elapsed_time_create_model = @elapsed begin
        @timeit to "create_model!" create_model!(energy_problem; write_lp_file = write_lp_file)
    end

    elapsed_time_solve_model = @elapsed begin
        @timeit to "solve_model!" solve_model!(energy_problem, optimizer; parameters = parameters)
    end

    energy_problem.time_read_data    = elapsed_time_read_data
    energy_problem.time_create_model = elapsed_time_create_model
    energy_problem.time_solve_model  = elapsed_time_solve_model

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
