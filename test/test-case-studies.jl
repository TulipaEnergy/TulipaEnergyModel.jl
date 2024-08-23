@testset "Norse Case Study" begin
    dir = joinpath(INPUT_FOLDER, "Norse")
    parameters_dict = Dict(
        HiGHS.Optimizer => Dict("mip_rel_gap" => 0.01, "output_flag" => false),
        GLPK.Optimizer => Dict("mip_gap" => 0.01, "msg_lev" => 0, "presolve" => GLPK.GLP_ON),
    )
    if !Sys.isapple()
        parameters_dict[Cbc.Optimizer] = Dict("ratioGap" => 0.01, "logLevel" => 0)
    end
    for (optimizer, parameters) in parameters_dict
        connection = DBInterface.connect(DuckDB.DB)
        _read_csv_folder(connection, dir)
        energy_problem = run_scenario(connection; optimizer, parameters)
        @test JuMP.is_solved_and_feasible(energy_problem.model)
    end
end

@testset "Tiny Case Study" begin
    dir = joinpath(INPUT_FOLDER, "Tiny")
    optimizer_list = [HiGHS.Optimizer, GLPK.Optimizer]
    if !Sys.isapple()
        push!(optimizer_list, Cbc.Optimizer)
    end
    for optimizer in optimizer_list
        connection = DBInterface.connect(DuckDB.DB)
        _read_csv_folder(connection, dir)
        energy_problem = run_scenario(connection; optimizer)
        @test energy_problem.objective_value ≈ 269238.43825 rtol = 1e-8
    end
end

@testset "Test run_scenario arguments" begin
    dir = joinpath(INPUT_FOLDER, "Norse")
    connection = DBInterface.connect(DuckDB.DB)
    _read_csv_folder(connection, dir)
    energy_problem = run_scenario(
        connection;
        output_folder = OUTPUT_FOLDER,
        write_lp_file = true,
        log_file = "model.log",
    )
end

@testset "Storage Assets Case Study" begin
    dir = joinpath(INPUT_FOLDER, "Storage")
    connection = DBInterface.connect(DuckDB.DB)
    _read_csv_folder(connection, dir)
    energy_problem = run_scenario(connection)
    @test energy_problem.objective_value ≈ 2409.384029 atol = 1e-5
end

@testset "Tiny Variable Resolution Case Study" begin
    dir = joinpath(INPUT_FOLDER, "Variable Resolution")
    connection = DBInterface.connect(DuckDB.DB)
    _read_csv_folder(connection, dir)
    energy_problem = run_scenario(connection)
    @test energy_problem.objective_value ≈ 28.45872 atol = 1e-5
end

@testset "Infeasible Case Study" begin
    dir = joinpath(INPUT_FOLDER, "Tiny")
    connection = DBInterface.connect(DuckDB.DB)
    _read_csv_folder(connection, dir)
    energy_problem = EnergyProblem(connection)
    energy_problem.graph["demand"].peak_demand = -1 # make it infeasible
    create_model!(energy_problem)
    @test_logs (:warn, "Model status different from optimal") solve_model!(energy_problem)
    @test energy_problem.termination_status == JuMP.INFEASIBLE
    print(energy_problem)
end
