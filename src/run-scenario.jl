export run_scenario

"""
    run_scenario(input_folder)
    run_scenario(input_folder, output_folder)

Run the scenario in the given input_folder and return the sets, parameters, and solution.
If the output_folder is specified, save the sets, parameters, and solution to the output_folder.
"""

function run_scenario(input_folder::AbstractString; write_lp_file = false)
    graph, parameters, sets = create_parameters_and_sets_from_file(input_folder)
    model = create_model(graph, parameters, sets; write_lp_file = write_lp_file)
    solution = solve_model(model)
    return sets, graph, parameters, solution
end

function run_scenario(
    input_folder::AbstractString,
    output_folder::AbstractString;
    write_lp_file = false,
)
    sets, graph, parameters, solution = run_scenario(input_folder; write_lp_file)
    save_solution_to_file(
        output_folder,
        [a for a in labels(graph) if graph[a].investable],
        solution.assets_investment,
        Dict(a => graph[a].capacity for a in labels(graph)),
    )
    return sets, graph, parameters, solution
end
