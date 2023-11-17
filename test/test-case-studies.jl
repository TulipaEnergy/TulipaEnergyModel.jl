@testset "Norse Case Study" begin
    dir = joinpath(INPUT_FOLDER, "Norse")
    _, _, _, solution = run_scenario(dir)
    @test solution.objective_value ≈ 1.64494182205421e8 atol = 1e-5
end

@testset "Tiny Case Study" begin
    dir = joinpath(INPUT_FOLDER, "Tiny")
    _, _, _, solution = run_scenario(dir, OUTPUT_FOLDER; write_lp_file = true)
    @test solution.objective_value ≈ 269238.43825 atol = 1e-5
end

@testset "Infeasible Case Study" begin
    dir = joinpath(INPUT_FOLDER, "Tiny")
    graph, parameters, sets = create_parameters_and_sets_from_file(dir)
    graph["demand"].peak_demand = -1 # make it infeasible
    model = create_model(graph, parameters, sets)
    @test_logs (:warn, "Model status different from optimal") solve_model(model)
end
