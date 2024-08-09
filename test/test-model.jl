@testset "Test that solve_model! throws if model is not created but works otherwise" begin
    connection = DBInterface.connect(DuckDB.DB)
    read_csv_folder(
        connection,
        joinpath(INPUT_FOLDER, "Tiny");
        schemas = TulipaEnergyModel.schema_per_file,
    )
    energy_problem = EnergyProblem(connection)
    @test_throws Exception solve_model!(energy_problem)
    @test !energy_problem.solved
    create_model!(energy_problem)
    @test !energy_problem.solved
    solution = solve_model!(energy_problem)
    @test energy_problem.solved
end
