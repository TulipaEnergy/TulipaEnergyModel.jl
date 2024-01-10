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
)
    energy_problem = create_energy_problem_from_csv_folder(input_folder)
    create_model!(energy_problem; write_lp_file = write_lp_file)
    solve_model!(energy_problem, optimizer; parameters = parameters)

    output_folder == "" ? nothing : save_solution_to_file(output_folder, energy_problem)

    return energy_problem
end
