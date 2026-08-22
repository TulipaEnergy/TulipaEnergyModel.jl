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
    total = TulipaEnergyModel.get_single_element_from_query_and_ensure_its_only_one(
        DuckDB.query(connection, "SELECT SUM(value) AS s FROM obj_breakdown"),
    )
    @test total ≈ energy_problem.objective_value atol = 1e-6
end

@testitem "Test storage-energy investment discount is independent of power investment cost" setup =
    [CommonSetup] tags = [:integration, :validation, :fast] begin
    connection = DBInterface.connect(DuckDB.DB)
    _read_csv_folder(connection, joinpath(INPUT_FOLDER, "Multi-year Investments"))
    energy_problem = TulipaEnergyModel.EnergyProblem(connection)

    # Zero out the battery power investment cost while keeping the positive energy
    # investment cost, isolating the storage-energy discounting factor.
    DuckDB.query(
        connection,
        "UPDATE asset_commission SET investment_cost = 0 WHERE asset = 'battery'",
    )
    TulipaEnergyModel.create_model!(energy_problem)

    rows = Dict(
        row.milestone_year => row for row in DuckDB.query(
            connection,
            "SELECT
                milestone_year,
                weight_for_asset_investment_discount,
                weight_for_asset_investment_energy_discount
            FROM t_objective_assets
            WHERE asset = 'battery'",
        )
    )

    # Power investment cost is 0, so its discounting weight is guarded to 0.
    @test rows[2030].weight_for_asset_investment_discount == 0.0
    @test rows[2050].weight_for_asset_investment_discount == 0.0

    # Energy investment cost is positive, so the weight is calculated based on the formula.
    @test rows[2030].weight_for_asset_investment_energy_discount ≈ 0.744093915 atol = 1e-6
    @test rows[2050].weight_for_asset_investment_energy_discount ≈ 0.050813475 atol = 1e-6
end
