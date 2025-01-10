@testset "Test that solve_model! throws if model is not created but works otherwise" begin
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
