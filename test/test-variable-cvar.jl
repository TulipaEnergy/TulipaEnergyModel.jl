@testitem "Create variables for conditional value-at-risk from test case" setup = [CommonSetup] tags =
    [:unit, :fast, :cvar] begin
    dir = joinpath(INPUT_FOLDER, "Tinier")
    connection = DBInterface.connect(DuckDB.DB)
    TulipaIO.read_csv_folder(connection, dir)
    DuckDB.query(
        connection,
        """
        CREATE OR REPLACE TABLE model_parameters AS
        SELECT *
        FROM (VALUES
            (0.1)
        ) AS t(risk_aversion_weight_lambda);
        """,
    )
    DuckDB.query(
        connection,
        """
        CREATE OR REPLACE TABLE stochastic_scenario AS
        SELECT *
        FROM (VALUES
            ('scenario_1', 0.5, 1),
            ('scenario_2', 0.5, 2)
        ) AS t(description, probability, scenario);
        """,
    )
    TulipaEnergyModel.populate_with_defaults!(connection)
    energy_problem = TulipaEnergyModel.run_scenario(connection; show_log = false)

    # Test value-at-risk threshold `μ` variable
    @test haskey(energy_problem.variables, :value_at_risk_threshold_mu)
    value_at_risk_threshold_mu = energy_problem.variables[:value_at_risk_threshold_mu].container
    @test length(value_at_risk_threshold_mu) == 1
    @test JuMP.lower_bound.(value_at_risk_threshold_mu) == [0.0]
    @test JuMP.has_upper_bound.(value_at_risk_threshold_mu) == [false]
    @test JuMP.is_integer.(value_at_risk_threshold_mu) == [false]

    # Test tail excess slack `ξ` variable
    @test haskey(energy_problem.variables, :tail_excess_slack_xi)
    tail_excess_slack_xi = energy_problem.variables[:tail_excess_slack_xi].container
    @test length(tail_excess_slack_xi) == 2
    @test JuMP.lower_bound.(tail_excess_slack_xi) == [0.0, 0.0]
    @test JuMP.has_upper_bound.(tail_excess_slack_xi) == [false, false]
    @test JuMP.is_integer.(tail_excess_slack_xi) == [false, false]
end

@testitem "Don't create variables for conditional value-at-risk" setup = [CommonSetup] tags =
    [:unit, :fast, :cvar] begin
    dir = joinpath(INPUT_FOLDER, "Tinier")
    connection = DBInterface.connect(DuckDB.DB)
    TulipaIO.read_csv_folder(connection, dir)
    TulipaEnergyModel.populate_with_defaults!(connection)
    # default parameters have risk_aversion_weight_lambda = 0.0, so no variable  should be created
    energy_problem = TulipaEnergyModel.run_scenario(connection; show_log = false)

    # the dictionary of variables should have the key :value_at_risk_threshold_mu
    @test haskey(energy_problem.variables, :value_at_risk_threshold_mu)
    # but the container should be empty
    value_at_risk_threshold_mu = energy_problem.variables[:value_at_risk_threshold_mu].container
    @test length(value_at_risk_threshold_mu) == 0

    # the dictionary of variables should have the key :tail_excess_slack_xi
    @test haskey(energy_problem.variables, :tail_excess_slack_xi)
    # but the container should be empty
    tail_excess_slack_xi = energy_problem.variables[:tail_excess_slack_xi].container
    @test length(tail_excess_slack_xi) == 0
end
