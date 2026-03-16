@testitem "Test obj_breakdown is populated after solve" setup = [CommonSetup] tags =
    [:integration, :validation, :fast] begin
    connection = DBInterface.connect(DuckDB.DB)
    _read_csv_folder(connection, joinpath(INPUT_FOLDER, "Tiny"))
    energy_problem = TulipaEnergyModel.EnergyProblem(connection)
    TulipaEnergyModel.create_model!(energy_problem)
    TulipaEnergyModel.solve_model!(energy_problem)
    TulipaEnergyModel.save_solution!(energy_problem)

    @test length(collect(DuckDB.query(connection, "SELECT name FROM obj_breakdown"))) == 10
    for row in DuckDB.query(connection, "SELECT name, value FROM obj_breakdown")
        @test !ismissing(row.value)
    end
    # Sum of components ≈ total objective value
    total = get_single_element_from_query_and_ensure_its_only_one(
        DuckDB.query(connection, "SELECT SUM(value) AS s FROM obj_breakdown"),
    )
    @test total ≈ energy_problem.objective_value atol = 1e-6
end
