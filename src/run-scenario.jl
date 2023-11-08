export run_scenario

"""
    run_scenario(input_folder)
    run_scenario(input_folder, output_folder)

Run the scenario in the given input_folder and return the sets, parameters, and solution.
If the output_folder is specified, save the sets, parameters, and solution to the output_folder.
"""

function run_scenario(input_folder::AbstractString; write_lp_file = false)
    parameters, sets = create_parameters_and_sets_from_file(input_folder)
    graph = create_graph(
        joinpath(input_folder, "assets-data.csv"),
        joinpath(input_folder, "flows-data.csv"),
    )
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
        sets.assets_investment,
        solution.assets_investment,
        parameters.assets_unit_capacity,
    )
    return sets, graph, parameters, solution
end
