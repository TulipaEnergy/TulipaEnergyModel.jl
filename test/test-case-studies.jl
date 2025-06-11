@testset "Norse Case Study" begin
    dir = joinpath(INPUT_FOLDER, "Norse")
    parameters_dict = Dict(
        HiGHS.Optimizer => Dict("mip_rel_gap" => 0.01, "output_flag" => false),
        # TODO: Find a different way to test parameters of GLPK
        # Removing because it's finding bad bases (ill-conditioned) randomly
        # GLPK.Optimizer => Dict("mip_gap" => 0.01, "msg_lev" => 0, "presolve" => GLPK.GLP_ON),
    )
    for (optimizer, optimizer_parameters) in parameters_dict
        connection = DBInterface.connect(DuckDB.DB)
        _read_csv_folder(connection, dir)
        energy_problem = TulipaEnergyModel.run_scenario(
            connection;
            optimizer,
            optimizer_parameters,
            show_log = false,
        )
        @test JuMP.is_solved_and_feasible(energy_problem.model)
    end
end

@testset "Tiny Case Study" begin
    dir = joinpath(INPUT_FOLDER, "Tiny")
    optimizer_list = [HiGHS.Optimizer, GLPK.Optimizer]
    for optimizer in optimizer_list
        connection = DBInterface.connect(DuckDB.DB)
        _read_csv_folder(connection, dir)
        energy_problem = TulipaEnergyModel.run_scenario(connection; optimizer, show_log = false)
        @test energy_problem.objective_value ≈ 269238.43825 rtol = 1e-8
        @testset "populate_with_defaults shouldn't change the solution" begin
            TulipaEnergyModel.populate_with_defaults!(connection)
            energy_problem = TulipaEnergyModel.run_scenario(connection; optimizer, show_log = false)
            @test energy_problem.objective_value ≈ 269238.43825 rtol = 1e-8
        end
    end
end

@testset "Tinier Case Study" begin
    dir = joinpath(INPUT_FOLDER, "Tinier")
    connection = DBInterface.connect(DuckDB.DB)
    TulipaIO.read_csv_folder(connection, dir)
    TulipaEnergyModel.populate_with_defaults!(connection)
    energy_problem = TulipaEnergyModel.run_scenario(connection; show_log = false)
    @test energy_problem.objective_value ≈ 269238.43825 rtol = 1e-8
    @testset "populate_with_defaults shouldn't change the solution" begin
        TulipaEnergyModel.populate_with_defaults!(connection)
        energy_problem = TulipaEnergyModel.run_scenario(connection; show_log = false)
        @test energy_problem.objective_value ≈ 269238.43825 rtol = 1e-8
    end
end

@testset "Storage Assets Case Study" begin
    dir = joinpath(INPUT_FOLDER, "Storage")
    connection = DBInterface.connect(DuckDB.DB)
    _read_csv_folder(connection, dir)
    energy_problem = TulipaEnergyModel.run_scenario(connection; show_log = false)
    @test energy_problem.objective_value ≈ 2542.234377 atol = 1e-5
    @testset "populate_with_defaults shouldn't change the solution" begin
        TulipaEnergyModel.populate_with_defaults!(connection)
        energy_problem = TulipaEnergyModel.run_scenario(connection; show_log = false)
        @test energy_problem.objective_value ≈ 2542.234377 atol = 1e-5
    end
end

@testset "UC ramping Case Study" begin
    dir = joinpath(INPUT_FOLDER, "UC-ramping")
    optimizer = HiGHS.Optimizer
    optimizer_parameters =
        Dict("output_flag" => false, "mip_rel_gap" => 0.0, "mip_feasibility_tolerance" => 1e-5)
    connection = DBInterface.connect(DuckDB.DB)
    _read_csv_folder(connection, dir)
    energy_problem = TulipaEnergyModel.run_scenario(
        connection;
        optimizer,
        optimizer_parameters,
        show_log = false,
    )
    @test energy_problem.objective_value ≈ 293074.923309 atol = 1e-5
    @testset "populate_with_defaults shouldn't change the solution" begin
        TulipaEnergyModel.populate_with_defaults!(connection)
        energy_problem = TulipaEnergyModel.run_scenario(
            connection;
            optimizer,
            optimizer_parameters,
            show_log = false,
        )
        @test energy_problem.objective_value ≈ 293074.923309 atol = 1e-5
    end
end

@testset "Tiny Variable Resolution Case Study" begin
    dir = joinpath(INPUT_FOLDER, "Variable Resolution")
    connection = DBInterface.connect(DuckDB.DB)
    _read_csv_folder(connection, dir)
    energy_problem = TulipaEnergyModel.run_scenario(connection; show_log = false)
    @test energy_problem.objective_value ≈ 28.45872 atol = 1e-5
    @testset "populate_with_defaults shouldn't change the solution" begin
        TulipaEnergyModel.populate_with_defaults!(connection)
        energy_problem = TulipaEnergyModel.run_scenario(connection; show_log = false)
        @test energy_problem.objective_value ≈ 28.45872 atol = 1e-5
    end
end

@testset "Multi-year Case Study" begin
    dir = joinpath(INPUT_FOLDER, "Multi-year Investments")
    connection = DBInterface.connect(DuckDB.DB)
    _read_csv_folder(connection, dir)
    energy_problem = TulipaEnergyModel.run_scenario(
        connection;
        model_parameters_file = joinpath(@__DIR__, "inputs", "model-parameters-example.toml"),
        show_log = false,
    )
    @test energy_problem.objective_value ≈ 3458577.01472 atol = 1e-5
    @testset "populate_with_defaults shouldn't change the solution" begin
        TulipaEnergyModel.populate_with_defaults!(connection)
        energy_problem = TulipaEnergyModel.run_scenario(
            connection;
            model_parameters_file = joinpath(@__DIR__, "inputs", "model-parameters-example.toml"),
            show_log = false,
        )
        @test energy_problem.objective_value ≈ 3458577.01472 atol = 1e-5
    end
end

@testset "Power Flow Case Study" begin
    dir = joinpath(INPUT_FOLDER, "Power-flow")
    connection = DBInterface.connect(DuckDB.DB)
    _read_csv_folder(connection, dir)
    energy_problem = TulipaEnergyModel.run_scenario(connection; show_log = false)
    @test energy_problem.objective_value ≈ 417486.99986 atol = 1e-5
    @testset "populate_with_defaults shouldn't change the solution" begin
        TulipaEnergyModel.populate_with_defaults!(connection)
        energy_problem = TulipaEnergyModel.run_scenario(connection; show_log = false)
        @test energy_problem.objective_value ≈ 417486.99986 atol = 1e-5
    end
end

@testset "Multiple Inputs Multiple Outputs Case Study" begin
    dir = joinpath(INPUT_FOLDER, "MIMO")
    connection = DBInterface.connect(DuckDB.DB)
    _read_csv_folder(connection, dir)
    energy_problem = TulipaEnergyModel.run_scenario(connection; show_log = false)
    @test energy_problem.objective_value ≈ 102936.724257 atol = 1e-5
    @testset "populate_with_defaults shouldn't change the solution" begin
        TulipaEnergyModel.populate_with_defaults!(connection)
        energy_problem = TulipaEnergyModel.run_scenario(connection; show_log = false)
        @test energy_problem.objective_value ≈ 102936.724257 atol = 1e-5
    end
end

@testset "Infeasible Case Study" begin
    dir = joinpath(INPUT_FOLDER, "Tiny")
    connection = DBInterface.connect(DuckDB.DB)
    _read_csv_folder(connection, dir)
    DuckDB.execute( # Make it infeasible
        connection,
        "UPDATE asset_milestone
            SET peak_demand = -1
            WHERE
                asset = 'demand'
                AND milestone_year = 2030
        ",
    )
    energy_problem = TulipaEnergyModel.EnergyProblem(connection)
    TulipaEnergyModel.create_model!(energy_problem)
    @test_logs (:warn, "Model status different from optimal") TulipaEnergyModel.solve_model!(
        energy_problem;
    )
    @test energy_problem.termination_status == JuMP.INFEASIBLE
    io = IOBuffer()
    print(io, energy_problem)
    @test split(String(take!(io))) ==
          split(read("io-outputs/energy-problem-model-infeasible.txt", String))

    # Test that export solution warning is present in logs
    output_folder = mktempdir()
    test_logger = Test.TestLogger()
    with_logger(test_logger) do
        return TulipaEnergyModel.run_scenario(connection; output_folder)
    end
    warning_messages = [log.message for log in test_logger.logs if log.level == Logging.Warn]
    @test any(
        msg -> msg == "The energy problem has not been solved yet. Skipping export solution.",
        warning_messages,
    )
end
