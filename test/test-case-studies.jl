@testset "Norse Case Study" begin
    dir = joinpath(INPUT_FOLDER, "Norse")
    _, solution = run_scenario(dir)
    @test solution.objective_value ≈ 1.64494182205421e8 atol = 1e-5
end

@testset "Tiny Case Study" begin
    dir = joinpath(INPUT_FOLDER, "Tiny")
    _, solution = run_scenario(dir, OUTPUT_FOLDER; write_lp_file = true)
    @test solution.objective_value ≈ 269238.43825 atol = 1e-5
end

@testset "Infeasible Case Study" begin
    dir = joinpath(INPUT_FOLDER, "Tiny")
    energy_problem = create_energy_model_from_csv_folder(dir)
    energy_problem.graph["demand"].peak_demand = -1 # make it infeasible
    model = create_model(energy_problem)
    @test_logs (:warn, "Model status different from optimal") solve_model(model)
end
