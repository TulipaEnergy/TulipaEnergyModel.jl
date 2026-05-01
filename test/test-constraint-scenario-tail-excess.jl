@testsnippet ConsScenarioTailExcessSetup begin
    using DuckDB: DuckDB
    using TulipaBuilder: TulipaBuilder as TB
    using TulipaClustering: TulipaClustering as TC

    # Configuration struct for testing
    @kwdef struct ConsScenarioTailExcessConfig
        producer_name::String = "dummy_producer"
        initial_units::Float64 = 2.0
        capacity::Float64 = 5.0
        investable::Bool = true
        decommissionable::Bool = true
        investment_method::String = "simple"
        fixed_cost::Float64 = 1.7
        investment_cost::Float64 = 13.0
        operational_cost::Float64 = 0.19
        availability_profiles::Dict{Tuple{Int,Int},Vector{Float64}} =
            Dict((2030, 1) => [0.8, 0.5, 1.0], (2030, 2) => [0.3, 0.1, 0.4])
        num_timesteps::Int = 1
        num_rps::Int = 2
        lambda::Float64 = 0.1
        alpha::Float64 = 0.98
    end

    """
        create_scenario_tail_excess_test_problem(config)

    Create a scenario tail excess test problem with producer asset configuration.
    Returns the database connection with configured producer asset and clustering.
    """
    function create_scenario_tail_excess_test_problem(config::ConsScenarioTailExcessConfig)
        tulipa = TB.TulipaData()

        # Add basic producer and consumer to connect the storage
        TB.add_asset!(tulipa, "consumer", :consumer)

        # Add and configure the producer asset
        TB.add_asset!(
            tulipa,
            config.producer_name,
            :producer;
            initial_units = config.initial_units,
            capacity = config.capacity,
            investable = config.investable,
            decommissionable = config.decommissionable,
            investment_method = config.investment_method,
            fixed_cost = config.fixed_cost,
            investment_cost = config.investment_cost,
        )
        TB.add_flow!(
            tulipa,
            config.producer_name,
            "consumer";
            operational_cost = config.operational_cost,
        )

        # We attach the availability profiles per scenario
        for ((commission_year, scenario), values) in config.availability_profiles
            TB.attach_profile!(
                tulipa,
                config.producer_name,
                :availability,
                commission_year,
                values;
                scenario = scenario,
            )
        end

        # Create connection
        connection = TB.create_connection(tulipa, TEM.schema)

        # Clustering to find representative periods
        layout = TC.ProfilesTableLayout(; year = :milestone_year, cols_to_crossby = [:scenario])
        TC.cluster!(connection, config.num_timesteps, config.num_rps; layout)

        # Create model parameters table with risk aversion parameters to trigger scenario tail excess constraints
        table_name = "model_parameters"
        table_rows = [(config.lambda, config.alpha)]
        columns = [:risk_aversion_weight_lambda, :risk_aversion_confidence_level_alpha]
        _create_table_for_tests(connection, table_name, table_rows, columns)

        # Populate with defaults and create model
        TEM.populate_with_defaults!(connection)
        energy_problem = TEM.EnergyProblem(connection)
        TEM.create_model!(energy_problem)

        # get the number of scenarios
        num_scenarios =
            DuckDB.query(
                connection,
                """
                SELECT DISTINCT scenario AS scenarios
                FROM rep_periods_mapping;
                """,
            ) |> collect |> length

        return (connection, energy_problem, num_scenarios)
    end

    function create_weight_lookup(connection)
        query_result = DuckDB.query(
            connection,
            """
            SELECT
                rep_period,
                scenario,
                COALESCE(SUM(weight), 0.0) AS weight
            FROM rep_periods_mapping
            GROUP BY milestone_year, rep_period, scenario
            ;
            """,
        )
        weight_lookup = Dict((row.rep_period, row.scenario) => row.weight for row in query_result)
        return weight_lookup
    end
end

@testitem "Test scenario tail excess constraints using workflow TB->TC->TEM" setup =
    [CommonSetup, ConsScenarioTailExcessSetup] tags = [:unit, :fast, :constraint] begin
    asset = ConsScenarioTailExcessConfig()
    connection, energy_problem, num_scenarios = create_scenario_tail_excess_test_problem(asset)
    num_rep_periods = asset.num_rps

    # unpack model components for easier access
    model = energy_problem.model
    variables = energy_problem.variables
    constraints = energy_problem.constraints
    expressions = energy_problem.expressions

    # Extract the variables
    assets_investment = variables[:assets_investment].container[1]
    assets_decommission = variables[:assets_decommission].container[1]
    flow = variables[:flow].container
    tail_excess_vars = variables[:tail_excess_slack_xi].container
    value_at_risk_threshold_mu = only(variables[:value_at_risk_threshold_mu].container)

    # Create expected base cost (scenario independent part of the cost expression)
    constant_cost = asset.capacity * asset.initial_units * asset.fixed_cost
    investment_cost = asset.capacity * (asset.investment_cost + asset.fixed_cost)
    decommission_cost = -1.0 * asset.capacity * asset.fixed_cost
    base_cost = JuMP.AffExpr(constant_cost)
    for (coef, var) in
        ((investment_cost, assets_investment), (decommission_cost, assets_decommission))
        JuMP.add_to_expression!(base_cost, coef, var)
    end

    # Create expected flows operational cost per scenario
    weight_lookup = create_weight_lookup(connection)
    operational_cost_per_scenario = Dict{Int64,JuMP.AffExpr}()
    for scenario in 1:num_scenarios
        operational_cost_per_scenario[scenario] = JuMP.AffExpr(0.0)
        for rp in 1:num_rep_periods
            weight = get(weight_lookup, (rp, scenario), 0.0)
            JuMP.add_to_expression!(
                operational_cost_per_scenario[scenario],
                asset.operational_cost * weight,
                flow[rp],
            )
        end
    end

    # Extract the constraints
    scenario_tail_excess_indices = constraints[:scenario_tail_excess].indices

    for row in scenario_tail_excess_indices
        id, scenario = row.id, row.scenario
        cost_per_scenario = JuMP.AffExpr(0.0)
        JuMP.add_to_expression!(cost_per_scenario, base_cost)
        JuMP.add_to_expression!(cost_per_scenario, operational_cost_per_scenario[scenario])

        expected_cons = JuMP.@build_constraint(
            tail_excess_vars[id] >= cost_per_scenario - value_at_risk_threshold_mu
        )
        @test _verify_constraint_using_id(model, :scenario_tail_excess, id, expected_cons)
    end
end

@testitem "Create scenario tail excess constraints from case study" setup = [CommonSetup] tags =
    [:unit, :fast, :constraint] begin
    dir = joinpath(INPUT_FOLDER, "TwoStage-StochOpt RPs per Scenario")
    connection = DBInterface.connect(DuckDB.DB)
    TulipaIO.read_csv_folder(connection, dir)

    # Create model parameters table with risk aversion parameters to trigger scenario tail excess constraints
    table_name = "model_parameters"
    table_rows = [(0.1, 0.98)]
    columns = [:risk_aversion_weight_lambda, :risk_aversion_confidence_level_alpha]
    _create_table_for_tests(connection, table_name, table_rows, columns)

    TulipaEnergyModel.populate_with_defaults!(connection)
    energy_problem = TulipaEnergyModel.EnergyProblem(connection)
    TulipaEnergyModel.create_model!(energy_problem)

    total_cost_per_scenario =
        energy_problem.expressions[:scenario_tail_excess].expressions[:total_cost_per_scenario]

    model = energy_problem.model
    scenario_tail_excess_indices = energy_problem.constraints[:scenario_tail_excess].indices
    tail_excess_vars = energy_problem.variables[:tail_excess_slack_xi].container
    value_at_risk_threshold_mu =
        only(energy_problem.variables[:value_at_risk_threshold_mu].container)

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

    for row in scenario_tail_excess_indices
        id, scenario = row.id, row.scenario
        cost_per_scenario = JuMP.AffExpr(0.0)
        JuMP.add_to_expression!(cost_per_scenario, base_cost)
        JuMP.add_to_expression!(cost_per_scenario, flows_operational_cost_per_scenario[scenario])
        JuMP.add_to_expression!(
            cost_per_scenario,
            vintage_flows_operational_cost_per_scenario[scenario],
        )
        JuMP.add_to_expression!(cost_per_scenario, units_on_operational_cost_per_scenario[scenario])

        @test cost_per_scenario ≈ total_cost_per_scenario[id]

        expected_cons = JuMP.@build_constraint(
            tail_excess_vars[id] >= cost_per_scenario - value_at_risk_threshold_mu
        )
        @test _verify_constraint_using_id(model, :scenario_tail_excess, id, expected_cons)
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
