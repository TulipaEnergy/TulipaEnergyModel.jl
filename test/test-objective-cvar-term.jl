@testitem "Create objective function term for conditional value-at-risk from test case" setup =
    [CommonSetup] tags = [:unit, :objective, :cvar] begin
    dir = joinpath(INPUT_FOLDER, "Tinier")
    connection = DBInterface.connect(DuckDB.DB)
    TulipaIO.read_csv_folder(connection, dir)

    lambda = 0.1
    alpha = 0.98
    probability_scenario_1 = 0.6
    probability_scenario_2 = 0.4

    DuckDB.query(
        connection,
        """
        CREATE OR REPLACE TABLE model_parameters AS
        SELECT *
        FROM (VALUES
            ($lambda, $alpha)
        ) AS t(risk_aversion_weight_lambda, risk_aversion_confidence_level_alpha);
        """,
    )
    DuckDB.query(
        connection,
        """
        CREATE OR REPLACE TABLE stochastic_scenario AS
        SELECT *
        FROM (VALUES
            ('scenario_1', $probability_scenario_1, 1),
            ('scenario_2', $probability_scenario_2, 2)
        ) AS t(description, probability, scenario);
        """,
    )
    TulipaEnergyModel.populate_with_defaults!(connection)
    energy_problem = TulipaEnergyModel.EnergyProblem(connection)
    TulipaEnergyModel.create_model!(energy_problem)

    # The expression for the CVaR term should be added to the objective function.
    @test haskey(energy_problem.model, :conditional_value_at_risk_term)

    # Check that it is in the obj_breakdown table
    df = DuckDB.query(
        connection,
        """
        SELECT *
        FROM obj_breakdown
        WHERE name = 'conditional_value_at_risk_term';
        """,
    ) |> DataFrame
    @test DataFrames.nrow(df) == 1

    # Check that the expression in the model is correct
    variables = energy_problem.variables
    cvar_expr = energy_problem.model[:conditional_value_at_risk_term]
    value_at_risk_threshold_mu = variables[:value_at_risk_threshold_mu].container[1]
    tail_excess_slack_xi = variables[:tail_excess_slack_xi].container

    @test JuMP.constant(cvar_expr) == 0.0
    @test isapprox(JuMP.coefficient(cvar_expr, value_at_risk_threshold_mu), 1.0)
    @test isapprox(
        JuMP.coefficient(cvar_expr, tail_excess_slack_xi[1]),
        probability_scenario_1 / (1 - alpha),
    )
    @test isapprox(
        JuMP.coefficient(cvar_expr, tail_excess_slack_xi[2]),
        probability_scenario_2 / (1 - alpha),
    )
end

@testitem "Don't create objective function term for conditional value-at-risk" setup = [CommonSetup] tags =
    [:unit, :objective, :cvar] begin
    dir = joinpath(INPUT_FOLDER, "Tinier")
    connection = DBInterface.connect(DuckDB.DB)
    TulipaIO.read_csv_folder(connection, dir)
    TulipaEnergyModel.populate_with_defaults!(connection)
    # default parameters have risk_aversion_weight_lambda = 0.0, so no variable  should be created
    energy_problem = TulipaEnergyModel.EnergyProblem(connection)
    TulipaEnergyModel.create_model!(energy_problem)

    # The expression for the CVaR term should not be added to the objective function.
    # So, the the expression in the model should not exist
    @test !haskey(energy_problem.model, :conditional_value_at_risk_term)

    # Check that it is not in the obj_breakdown table
    df = DuckDB.query(
        connection,
        """
        SELECT *
        FROM obj_breakdown
        WHERE name = 'conditional_value_at_risk_term';
        """,
    ) |> DataFrame
    @test DataFrames.nrow(df) == 0
end
