@testitem "Create scenario tail excess for case study" setup = [CommonSetup] tags =
    [:unit, :fast, :constraint] begin
    dir = joinpath(INPUT_FOLDER, "TwoStage-StochOpt RPs per Scenario")
    connection = DBInterface.connect(DuckDB.DB)
    TulipaIO.read_csv_folder(connection, dir)

    DuckDB.query(
        connection,
        """
        CREATE OR REPLACE TABLE model_parameters AS
        SELECT *
        FROM (VALUES
        	(0.1, 0.98)
        ) AS t(risk_aversion_weight_lambda, risk_aversion_confidence_level_alpha);
        """,
    )

    TulipaEnergyModel.populate_with_defaults!(connection)
    energy_problem = TulipaEnergyModel.EnergyProblem(connection)
    TulipaEnergyModel.create_model!(energy_problem)

    total_cost_per_scenario =
        energy_problem.expressions[:scenario_tail_excess].expressions[:total_cost_per_scenario]

    model = energy_problem.model
    tail_excess_indices = energy_problem.variables[:tail_excess_slack_xi].indices
    tail_excess_vars = energy_problem.variables[:tail_excess_slack_xi].container
    value_at_risk_threshold_mu = energy_problem.variables[:value_at_risk_threshold_mu].container[1]

    base_cost = JuMP.AffExpr(0.0)
    for objective_name in (
        :assets_investment_cost,
        :assets_fixed_cost_compact_method,
        :assets_fixed_cost_simple_method,
        :storage_assets_energy_investment_cost,
        :storage_assets_energy_fixed_cost,
        :flows_investment_cost,
        :flows_fixed_cost,
    )
        if haskey(model, objective_name)
            JuMP.add_to_expression!(base_cost, model[objective_name])
        end
    end

    flows_operational_cost_per_scenario = Dict(
        row.scenario =>
            energy_problem.expressions[:flows_operational_cost_per_scenario].expressions[:cost][row.id]
        for row in energy_problem.expressions[:flows_operational_cost_per_scenario].indices
    )
    vintage_flows_operational_cost_per_scenario = Dict(
        row.scenario =>
            energy_problem.expressions[:vintage_flows_operational_cost_per_scenario].expressions[:cost][row.id]
        for
        row in energy_problem.expressions[:vintage_flows_operational_cost_per_scenario].indices
    )
    units_on_operational_cost_per_scenario = Dict(
        row.scenario =>
            energy_problem.expressions[:units_on_operational_cost_per_scenario].expressions[:cost][row.id]
        for row in energy_problem.expressions[:units_on_operational_cost_per_scenario].indices
    )

    for row in tail_excess_indices
        expected_total_cost = JuMP.AffExpr(0.0)
        JuMP.add_to_expression!(expected_total_cost, base_cost)
        JuMP.add_to_expression!(
            expected_total_cost,
            flows_operational_cost_per_scenario[row.scenario],
        )
        JuMP.add_to_expression!(
            expected_total_cost,
            vintage_flows_operational_cost_per_scenario[row.scenario],
        )
        JuMP.add_to_expression!(
            expected_total_cost,
            units_on_operational_cost_per_scenario[row.scenario],
        )

        @test expected_total_cost == total_cost_per_scenario[row.id]

        expected_cons = JuMP.@build_constraint(
            tail_excess_vars[row.id] >=
            total_cost_per_scenario[row.id] - value_at_risk_threshold_mu
        )
        @test _verify_constraint_using_id(model, :scenario_tail_excess, row.id, expected_cons)
    end
end

@testitem "Don't create scenario tail excess constraints with default parameters (no risk aversion)" setup =
    [CommonSetup] tags = [:unit, :objective, :cvar] begin
    dir = joinpath(INPUT_FOLDER, "Tinier")
    connection = DBInterface.connect(DuckDB.DB)
    TulipaIO.read_csv_folder(connection, dir)
    TulipaEnergyModel.populate_with_defaults!(connection)
    # default parameters have risk_aversion_weight_lambda = 0.0, so no scenario tail excess constraints should be created
    energy_problem = TulipaEnergyModel.EnergyProblem(connection)
    TulipaEnergyModel.create_model!(energy_problem)

    # Check that no constraints were created for scenario tail excess
    @test isempty(
        energy_problem.expressions[:scenario_tail_excess].expressions[:total_cost_per_scenario],
    )

    # Check that the expr_scenario_tail_excess table is empty
    df = DuckDB.query(
        connection,
        """
        SELECT *
        FROM expr_scenario_tail_excess;
        """,
    ) |> DataFrame
    @test DataFrames.nrow(df) == 0
end
