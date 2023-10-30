@testset "Norse Case Study" begin
    dir = joinpath(INPUT_FOLDER, "Norse")
    parameters, sets = create_parameters_and_sets_from_file(dir)
    graph = create_graph(joinpath(dir, "assets-data.csv"), joinpath(dir, "flows-data.csv"))
    model = create_model(graph, parameters, sets)
    solution = solve_model(model)
    @test solution.objective_value ≈ 164432876.31472 atol = 1e-5
    save_solution_to_file(
        OUTPUT_FOLDER,
        sets.assets_investment,
        solution.assets_investment,
        parameters.assets_unit_capacity,
    )
end

@testset "Tiny Case Study" begin
    dir = joinpath(INPUT_FOLDER, "Tiny")
    parameters, sets = create_parameters_and_sets_from_file(dir)
    graph = create_graph(joinpath(dir, "assets-data.csv"), joinpath(dir, "flows-data.csv"))
    model = create_model(graph, parameters, sets; write_lp_file = true)
    solution = solve_model(model)
    @test solution.objective_value ≈ 269238.43825 atol = 1e-5
    save_solution_to_file(
        OUTPUT_FOLDER,
        sets.assets_investment,
        solution.assets_investment,
        parameters.assets_unit_capacity,
    )
end

@testset "Infeasible Case Study" begin
    dir = joinpath(INPUT_FOLDER, "Tiny")
    parameters, sets = create_parameters_and_sets_from_file(dir)
    parameters.peak_demand["demand"] = -1 # make it infeasible
    graph = create_graph(joinpath(dir, "assets-data.csv"), joinpath(dir, "flows-data.csv"))
    model = create_model(graph, parameters, sets)
    @test_logs (:warn, "Model status different from optimal") solve_model(model)
end
