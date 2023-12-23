@testset "Norse Case Study" begin
    dir = joinpath(INPUT_FOLDER, "Norse")
    energy_problem = run_scenario(dir)
    @test energy_problem.objective_value ≈ 1.791715212196092e8 atol = 1e-5
end

@testset "Tiny Case Study" begin
    dir = joinpath(INPUT_FOLDER, "Tiny")
    energy_problem = run_scenario(
        dir,
        OUTPUT_FOLDER;
        optimizer = HiGHS.Optimizer,
        parameters = ["output_flag" => true],
        write_lp_file = true,
    )
    @test energy_problem.objective_value ≈ 269238.43825 atol = 1e-5
end

@testset "Tiny Variable Resolution Case Study" begin
    dir = joinpath(INPUT_FOLDER, "Variable Resolution")
    energy_problem = run_scenario(dir)
    @test energy_problem.objective_value ≈ 28.45872 atol = 1e-5
end

@testset "Infeasible Case Study" begin
    dir = joinpath(INPUT_FOLDER, "Tiny")
    energy_problem = create_energy_problem_from_csv_folder(dir)
    energy_problem.graph["demand"].peak_demand = -1 # make it infeasible
    create_model!(energy_problem)
    @test_logs (:warn, "Model status different from optimal") solve_model!(energy_problem)
    @test energy_problem.termination_status == JuMP.INFEASIBLE
end
