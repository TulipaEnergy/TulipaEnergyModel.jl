@testitem "Operational costs per scenario are stored in TulipaExpression" setup = [CommonSetup] tags =
    [:unit, :fast, :objective, :cvar] begin
    dir = joinpath(INPUT_FOLDER, "TwoStage-StochOpt RPs per Scenario")
    connection = DBInterface.connect(DuckDB.DB)
    TulipaIO.read_csv_folder(connection, dir)
    TulipaEnergyModel.populate_with_defaults!(connection)
    energy_problem = TulipaEnergyModel.EnergyProblem(connection)
    TulipaEnergyModel.create_model!(energy_problem)

    scenario_data = DuckDB.query(
        connection,
        """
        SELECT
            scenario,
            probability
        FROM stochastic_scenario
        ORDER BY scenario
        """,
    ) |> DataFrame
    num_scenarios = DataFrames.nrow(scenario_data)

    for (expr_name, model_name) in (
        (:flows_operational_cost_per_scenario, :flows_operational_cost),
        (:vintage_flows_operational_cost_per_scenario, :vintage_flows_operational_cost),
        (:units_on_operational_cost_per_scenario, :units_on_operational_cost),
    )
        @test haskey(energy_problem.expressions, expr_name)
        @test haskey(energy_problem.model, model_name)

        expr = energy_problem.expressions[expr_name]
        expr_data = DuckDB.query(
            connection,
            """
            SELECT
                scenario,
                probability
            FROM $(expr.table_name)
            ORDER BY id
            """,
        ) |> DataFrame

        @test expr.num_rows == num_scenarios
        @test length(expr.expressions[:cost]) == num_scenarios
        @test expr_data.scenario == scenario_data.scenario
        @test expr_data.probability == scenario_data.probability
        @test all(cost isa JuMP.AffExpr for cost in expr.expressions[:cost])

        expected = sum(row.probability * expr.expressions[:cost][row.id] for row in expr.indices)
        @test expected == energy_problem.model[model_name]
    end
end
