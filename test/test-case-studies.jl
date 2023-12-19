@testset "Norse Case Study" begin
    dir = joinpath(INPUT_FOLDER, "Norse")
    optimizer_list = [HiGHS.Optimizer, Cbc.Optimizer, GLPK.Optimizer]
    parameters_dict = Dict(
        HiGHS.Optimizer => Dict("mip_rel_gap" => 0.0, "output_flag" => false),
        Cbc.Optimizer => Dict("ratioGap" => 0.0, "logLevel" => 0),
        GLPK.Optimizer => Dict("mip_gap" => 0.0, "msg_lev" => 0),
    )
    for optimizer in optimizer_list
        energy_problem =
            run_scenario(dir; optimizer = optimizer, parameters = parameters_dict[optimizer])
        @testset "Codecov Demands Graphs" begin
            plot_single_flow(energy_problem, "Asgard_Solar", "Asgard_Battery", 1)
            plot_graph(energy_problem)
            plot_assets_capacity(energy_problem)
        end
        @test energy_problem.objective_value ≈ 1.7913342401e8 rtol = 1e-8
    end
end

@testset "Tiny Case Study" begin
    dir = joinpath(INPUT_FOLDER, "Tiny")
    optimizer_list = [HiGHS.Optimizer, Cbc.Optimizer, GLPK.Optimizer]
    for optimizer in optimizer_list
        energy_problem = run_scenario(dir; optimizer = optimizer)
        @test energy_problem.objective_value ≈ 269238.43825 atol = 1e-5
    end
end

@testset "Test run_scenario arguments" begin
    dir = joinpath(INPUT_FOLDER, "Tiny")
    energy_problem = run_scenario(dir, OUTPUT_FOLDER; write_lp_file = true, log_file = "model.log")
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
