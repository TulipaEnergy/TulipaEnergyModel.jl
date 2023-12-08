export run_scenario

"""
    run_scenario(input_folder, output_folder)

Run the scenario in the given input_folder and return the sets, parameters, and solution.
If the output_folder is specified, save the sets, parameters, and solution to the output_folder.
"""
function run_scenario(
    input_folder::AbstractString,
    output_folder::String = "";
    write_lp_file = false,
)
    energy_problem = create_energy_problem_from_csv_folder(input_folder)
    create_model!(energy_problem; write_lp_file = write_lp_file)
    solve_model!(energy_problem)

    output_folder == "" ? nothing : save_solution_to_file(output_folder, energy_problem)

    return energy_problem
end
