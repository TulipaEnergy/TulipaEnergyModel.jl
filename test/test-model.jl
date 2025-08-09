@testitem "Test that solve_model! throws if model is not created but works otherwise" setup =
    [CommonSetup] tags = [:integration, :validation, :fast] begin
    connection = DBInterface.connect(DuckDB.DB)
    _read_csv_folder(connection, joinpath(INPUT_FOLDER, "Tiny"))
    energy_problem = TulipaEnergyModel.EnergyProblem(connection)
    @test_throws Exception TulipaEnergyModel.solve_model!(energy_problem)
    @test !energy_problem.solved
    TulipaEnergyModel.create_model!(energy_problem)
    @test !energy_problem.solved
    solution = TulipaEnergyModel.solve_model!(energy_problem)
    @test energy_problem.solved
end

@testitem "Test that model.lp and model.mps are created" setup = [CommonSetup] tags =
    [:integration, :validation, :fast] begin
    for ext in ("lp", "mps")
        connection = DBInterface.connect(DuckDB.DB)
        _read_csv_folder(connection, joinpath(INPUT_FOLDER, "Tiny"))
        energy_problem = TulipaEnergyModel.EnergyProblem(connection)

        model_file_name = joinpath(mktempdir(), "saved_model.$ext")
        @test !isfile(model_file_name)
        TulipaEnergyModel.create_model!(energy_problem; model_file_name)
        @test isfile(model_file_name)
    end
end
