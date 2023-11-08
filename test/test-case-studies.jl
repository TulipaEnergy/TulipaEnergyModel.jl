@testset "Norse Case Study" begin
    dir = joinpath(INPUT_FOLDER, "Norse")
    _, _, _, solution = run_scenario(dir)
    @test solution.objective_value ≈ 164432876.31472 atol = 1e-5
end

@testset "Tiny Case Study" begin
    dir = joinpath(INPUT_FOLDER, "Tiny")
    _, _, _, solution = run_scenario(dir, OUTPUT_FOLDER)
    @test solution.objective_value ≈ 269238.43825 atol = 1e-5
end

@testset "Infeasible Case Study" begin
    dir = joinpath(INPUT_FOLDER, "Tiny")
    parameters, sets = create_parameters_and_sets_from_file(dir)
    parameters.peak_demand["demand"] = -1 # make it infeasible
    graph = create_graph(joinpath(dir, "assets-data.csv"), joinpath(dir, "flows-data.csv"))
    model = create_model(graph, parameters, sets)
    @test_logs (:warn, "Model status different from optimal") solve_model(model)
end
