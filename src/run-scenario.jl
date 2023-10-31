export run_scenario

"""
    run_scenario(input_folder, output_folder)

Run the scenario in the given input_folder and save the results to the output_folder
"""

function run_scenario(input_folder::AbstractString, output_folder::AbstractString)
    parameters, sets = create_parameters_and_sets_from_file(input_folder)
    graph = create_graph(
        joinpath(input_folder, "assets-data.csv"),
        joinpath(input_folder, "flows-data.csv"),
    )
    model = create_model(graph, parameters, sets)
    solution = solve_model(model)
    save_solution_to_file(
        output_folder,
        sets.assets_investment,
        solution.assets_investment,
        parameters.assets_unit_capacity,
    )
end

"""
    run_scenario(scenario_name)

Run the scenario with the given scenario_name, assuming the folder structure is dir/inputs/scenario_name and dir/outputs/scenario_name
"""
function run_scenario(scenario_name::String)
    input_folder = joinpath(@__DIR__, "inputs", scenario_name)
    output_folder = joinpath(@__DIR__, "outputs", scenario_name)
    parameters, sets = create_parameters_and_sets_from_file(input_folder)
    graph = create_graph(
        joinpath(input_folder, "assets-data.csv"),
        joinpath(input_folder, "flows-data.csv"),
    )
    model = create_model(graph, parameters, sets)
    solution = solve_model(model)
    save_solution_to_file(
        output_folder,
        sets.assets_investment,
        solution.assets_investment,
        parameters.assets_unit_capacity,
    )
end
