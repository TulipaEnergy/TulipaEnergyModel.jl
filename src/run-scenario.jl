export run_scenario

"""
    run_scenario(input_folder)
    run_scenario(input_folder, output_folder)

Run the scenario in the given input_folder and return the sets, parameters, and solution.
If the output_folder is specified, save the sets, parameters, and solution to the output_folder.
"""

function run_scenario(input_folder::AbstractString; write_lp_file = false)
    energy_problem = create_energy_problem_from_csv_folder(input_folder)
    model = create_model(energy_problem; write_lp_file = write_lp_file)
    solution = solve_model(model)
    return energy_problem, solution
end

function run_scenario(
    input_folder::AbstractString,
    output_folder::AbstractString;
    write_lp_file = false,
)
    energy_problem, solution = run_scenario(input_folder; write_lp_file)
    save_solution_to_file(
        output_folder,
        [a for a in labels(energy_problem.graph) if energy_problem.graph[a].investable],
        solution.assets_investment,
        Dict(a => energy_problem.graph[a].capacity for a in labels(energy_problem.graph)),
    )
    return energy_problem, solution
end
