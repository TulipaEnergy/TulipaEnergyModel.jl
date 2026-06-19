@testsnippet ConsMinOutputFlowSetup begin
    using DuckDB: DuckDB
    using TulipaBuilder: TulipaBuilder as TB
    using TulipaClustering: TulipaClustering as TC

    @kwdef struct ConsMinOutputFlowConfig
        name::String = "producer"
        asset_type::Symbol = :producer
        vintage_method::String = "aggregated"
        initial_units::Float64 = 2.0
        capacity::Float64 = 100.0
        min_operating_point::Float64 = 0.4
        unit_commitment::String = "none"
        investable::Bool = false
        num_timesteps::Int = 1
        num_rps::Int = 2
        has_co2_output::Bool = false
        co2_consumer_name::String = "co2_sink"
    end

    """
        create_min_output_flow_test_problem(config::ConsMinOutputFlowConfig)

    Create a minimum output flow test problem using the provided configuration.
    Returns `(connection, energy_problem)`.
    """
    function create_min_output_flow_test_problem(config::ConsMinOutputFlowConfig)
        tulipa = TB.TulipaData()

        # Consumer asset to receive power output
        TB.add_asset!(tulipa, "demand", :consumer; peak_demand = 200.0)

        # For conversion assets, add an upstream producer feeding into the conversion plant
        if config.asset_type == :conversion
            TB.add_asset!(tulipa, "upstream", :producer; capacity = 300.0, initial_units = 1.0)
        end

        # The main asset under test
        TB.add_asset!(
            tulipa,
            config.name,
            config.asset_type;
            capacity = config.capacity,
            initial_units = config.initial_units,
            min_operating_point = config.min_operating_point,
            unit_commitment = config.unit_commitment,
            vintage_method = config.vintage_method,
            investable = config.investable,
        )

        # Outgoing flow to demand (capacity_coefficient defaults to 1.0)
        TB.add_flow!(tulipa, config.name, "demand")

        # Optional CO2 byproduct flow with capacity_coefficient = 0 (should not constrain output)
        if config.has_co2_output
            TB.add_asset!(tulipa, config.co2_consumer_name, :consumer)
            TB.add_flow!(tulipa, config.name, config.co2_consumer_name; capacity_coefficient = 0.0)
        end

        # Incoming flow required by conversion assets
        if config.asset_type == :conversion
            TB.add_flow!(tulipa, "upstream", config.name)
        end

        # Attach an availability profile so TulipaClustering can cluster.
        # One value per original period: num_rps periods of num_timesteps each.
        profile_length = config.num_timesteps * config.num_rps
        TB.attach_profile!(
            tulipa,
            config.name,
            :availability,
            2030,
            ones(profile_length);
            scenario = 1,
        )

        connection = TB.create_connection(tulipa, TEM.schema)

        layout = TC.ProfilesTableLayout(; year = :milestone_year, cols_to_crossby = [:scenario])
        TC.cluster!(connection, config.num_timesteps, config.num_rps; layout)

        TEM.populate_with_defaults!(connection)
        energy_problem = TEM.EnergyProblem(connection)
        TEM.create_model!(energy_problem)

        return (connection, energy_problem)
    end

    function get_min_output_flow_constraint_data(connection, asset_name, vintage_method)
        table = "cons_min_output_flow_without_unit_commitment_$(vintage_method)_vintage_method"
        return DuckDB.query(
            connection,
            """SELECT id, milestone_year, rep_period, time_block_start, time_block_end
               FROM $table
               WHERE asset = '$asset_name'
               ORDER BY milestone_year, rep_period, time_block_start""",
        )
    end

    function get_flow_var_id(connection, from_asset, to_asset, rep_period, time_block_start)
        return TEM.get_single_element_from_query_and_ensure_its_only_one(
            DuckDB.query(
                connection,
                """SELECT id FROM var_flow
                   WHERE from_asset = '$from_asset' AND to_asset = '$to_asset'
                   AND rep_period = $rep_period AND time_block_start = $time_block_start""",
            ),
        )::Int
    end
end

@testitem "Test min output flow constraint - producer, aggregated, non-investable" setup =
    [CommonSetup, ConsMinOutputFlowSetup] tags = [:unit, :constraint, :fast] begin
    config = ConsMinOutputFlowConfig(; name = "wind")

    connection, energy_problem = create_min_output_flow_test_problem(config)
    flow = energy_problem.variables[:flow].container

    constraint_data = get_min_output_flow_constraint_data(connection, config.name, "aggregated")
    @test (constraint_data |> collect |> length) == config.num_rps  # one constraint per rep period

    for row in get_min_output_flow_constraint_data(connection, config.name, "aggregated")
        id = row.id
        flow_id =
            get_flow_var_id(connection, config.name, "demand", row.rep_period, row.time_block_start)

        # Expected: flow >= min_operating_point * capacity * initial_units = 0.4 * 100.0 * 2.0 = 80.0
        expected_cons = JuMP.@build_constraint(
            flow[flow_id] >= config.min_operating_point * config.capacity * config.initial_units
        )
        @test _verify_constraint_using_id(
            energy_problem.model,
            :min_output_flow_without_unit_commitment_aggregated_vintage_method,
            id,
            expected_cons,
        )
    end
end

@testitem "Test min output flow constraint - producer, aggregated, investable" setup =
    [CommonSetup, ConsMinOutputFlowSetup] tags = [:unit, :constraint, :fast] begin

    # Use initial_units > 0 to verify both the constant and the investment term in the RHS.
    config = ConsMinOutputFlowConfig(;
        name = "wind",
        initial_units = 1.0,
        min_operating_point = 0.5,
        investable = true,
    )

    connection, energy_problem = create_min_output_flow_test_problem(config)
    flow = energy_problem.variables[:flow].container

    # Only the single investable producer has an investment variable
    assets_investment = energy_problem.variables[:assets_investment].container[1]

    constraint_data = get_min_output_flow_constraint_data(connection, config.name, "aggregated")
    @test (constraint_data |> collect |> length) == config.num_rps

    for row in get_min_output_flow_constraint_data(connection, config.name, "aggregated")
        id = row.id
        flow_id =
            get_flow_var_id(connection, config.name, "demand", row.rep_period, row.time_block_start)

        # Expected: flow >= min_op * capacity * (initial_units + assets_investment)
        expected_cons = JuMP.@build_constraint(
            flow[flow_id] >=
            config.min_operating_point *
            config.capacity *
            (config.initial_units + assets_investment)
        )
        @test _verify_constraint_using_id(
            energy_problem.model,
            :min_output_flow_without_unit_commitment_aggregated_vintage_method,
            id,
            expected_cons,
        )
    end
end

@testitem "Test min output flow constraint - conversion asset, aggregated" setup =
    [CommonSetup, ConsMinOutputFlowSetup] tags = [:unit, :constraint, :fast] begin

    # Conversion assets are included in the constraint alongside producers.
    config = ConsMinOutputFlowConfig(;
        name = "smr",
        asset_type = :conversion,
        initial_units = 3.0,
        capacity = 50.0,
        min_operating_point = 0.3,
    )

    connection, energy_problem = create_min_output_flow_test_problem(config)
    flow = energy_problem.variables[:flow].container

    constraint_data = get_min_output_flow_constraint_data(connection, config.name, "aggregated")
    @test (constraint_data |> collect |> length) == config.num_rps

    for row in get_min_output_flow_constraint_data(connection, config.name, "aggregated")
        id = row.id
        flow_id =
            get_flow_var_id(connection, config.name, "demand", row.rep_period, row.time_block_start)

        # Expected: flow >= min_op * capacity * initial_units = 0.3 * 50.0 * 3.0 = 45.0
        expected_cons = JuMP.@build_constraint(
            flow[flow_id] >= config.min_operating_point * config.capacity * config.initial_units
        )
        @test _verify_constraint_using_id(
            energy_problem.model,
            :min_output_flow_without_unit_commitment_aggregated_vintage_method,
            id,
            expected_cons,
        )
    end
end

@testitem "Test min output flow constraint - CO2 output with zero capacity coefficient" setup =
    [CommonSetup, ConsMinOutputFlowSetup] tags = [:unit, :constraint, :fast] begin

    # A producer with both an energy output (capacity_coefficient = 1, the default) and a CO2
    # byproduct output (capacity_coefficient = 0). The min output flow constraint enforces a
    # minimum on the summed outgoing expression weighted by capacity_coefficient, so the CO2
    # flow has zero weight and must not affect the RHS lower bound.
    config = ConsMinOutputFlowConfig(;
        name = "ccgt",
        vintage_method = "aggregated",
        capacity = 200.0,
        min_operating_point = 0.3,
        num_rps = 1,
        has_co2_output = true,
        co2_consumer_name = "atmosphere",
    )

    connection, energy_problem = create_min_output_flow_test_problem(config)
    flow = energy_problem.variables[:flow].container

    constraint_data = get_min_output_flow_constraint_data(connection, config.name, "aggregated")
    @test (constraint_data |> collect |> length) == config.num_rps

    for row in get_min_output_flow_constraint_data(connection, config.name, "aggregated")
        id = row.id
        energy_flow_id =
            get_flow_var_id(connection, config.name, "demand", row.rep_period, row.time_block_start)
        co2_flow_id = get_flow_var_id(
            connection,
            config.name,
            config.co2_consumer_name,
            row.rep_period,
            row.time_block_start,
        )

        cons_ref =
            energy_problem.model[:min_output_flow_without_unit_commitment_aggregated_vintage_method][id]
        cons_obj = JuMP.constraint_object(cons_ref)

        # The energy flow contributes with coefficient 1.0 (capacity_coefficient = 1)
        @test isapprox(get(cons_obj.func.terms, flow[energy_flow_id], 0.0), 1.0)
        # The CO2 flow does not contribute: its coefficient is 0.0 or absent entirely
        @test isapprox(get(cons_obj.func.terms, flow[co2_flow_id], 0.0), 0.0)
        # The RHS lower bound is based on the energy output capacity only
        @test isapprox(
            cons_obj.set.lower,
            config.min_operating_point * config.capacity * config.initial_units,
        )
    end
end

@testitem "Test min output flow constraint - compact profiles vintage method" setup =
    [CommonSetup, ConsMinOutputFlowSetup] tags = [:unit, :constraint, :fast] begin
    config = ConsMinOutputFlowConfig(;
        name = "nuclear",
        vintage_method = "compact_profiles",
        initial_units = 3.0,
        capacity = 150.0,
        min_operating_point = 0.5,
    )

    connection, energy_problem = create_min_output_flow_test_problem(config)
    flow = energy_problem.variables[:flow].container

    constraint_data = get_min_output_flow_constraint_data(connection, config.name, "compact")
    @test (constraint_data |> collect |> length) == config.num_rps

    for row in get_min_output_flow_constraint_data(connection, config.name, "compact")
        id = row.id
        flow_id =
            get_flow_var_id(connection, config.name, "demand", row.rep_period, row.time_block_start)

        # Expected: flow >= min_op * capacity * initial_units = 0.5 * 150.0 * 3.0 = 225.0
        expected_cons = JuMP.@build_constraint(
            flow[flow_id] >= config.min_operating_point * config.capacity * config.initial_units
        )
        @test _verify_constraint_using_id(
            energy_problem.model,
            :min_output_flow_without_unit_commitment_compact_vintage_method,
            id,
            expected_cons,
        )
    end
end

@testitem "Test min output flow constraint - unit commitment asset is excluded" setup =
    [CommonSetup, ConsMinOutputFlowSetup] tags = [:unit, :constraint, :fast] begin

    # Assets with unit_commitment != 'none' use the min_output_flow_with_unit_commitment
    # mechanism instead; they must not appear in the without-UC constraint tables.
    config = ConsMinOutputFlowConfig(; name = "ccgt_uc", unit_commitment = "basic", num_rps = 1)

    connection, energy_problem = create_min_output_flow_test_problem(config)

    @test (
        get_min_output_flow_constraint_data(connection, config.name, "aggregated") |>
        collect |>
        length
    ) == 0
    @test (
        get_min_output_flow_constraint_data(connection, config.name, "compact") |>
        collect |>
        length
    ) == 0
end

@testitem "Test min output flow constraint - zero min operating point is excluded" setup =
    [CommonSetup, ConsMinOutputFlowSetup] tags = [:unit, :constraint, :fast] begin

    # Assets with min_operating_point = 0 have no minimum output requirement,
    # so no constraint rows are created for them.
    config = ConsMinOutputFlowConfig(; name = "wind", min_operating_point = 0.0, num_rps = 1)

    connection, energy_problem = create_min_output_flow_test_problem(config)

    @test (
        get_min_output_flow_constraint_data(connection, config.name, "aggregated") |>
        collect |>
        length
    ) == 0
    @test (
        get_min_output_flow_constraint_data(connection, config.name, "compact") |>
        collect |>
        length
    ) == 0
end

@testitem "Test minimum_flow_limit constraint activates correctly in a full solve" setup =
    [CommonSetup] tags = [:integration, :validation, :fast] begin
    # Load the Tiny dataset and modify it so that an asset has a minimum output flow
    # constraint without unit commitment.
    connection = DBInterface.connect(DuckDB.DB)
    _read_csv_folder(connection, joinpath(INPUT_FOLDER, "Tiny"))

    # ens has initial_units = 1 and is a producer with unit_commitment = 'none'.
    # Setting min_operating_point = 0.1 enforces a minimum output:
    #   min_output = 0.1 * capacity(1115) * initial_units(1) = 111.5 MW
    DuckDB.query(
        connection,
        "UPDATE asset SET min_operating_point = 0.1 WHERE asset = 'ens' AND type = 'producer'",
    )

    energy_problem = TulipaEnergyModel.EnergyProblem(connection)
    TulipaEnergyModel.create_model!(energy_problem)
    TulipaEnergyModel.solve_model!(energy_problem)

    @test energy_problem.solved
    # The must-run constraint forces ens to produce at least min_op * capacity * initial_units = 111.5 MW,
    # increasing cost vs. the baseline (ens must dispatch even when cheaper options exist).
    @test energy_problem.objective_value > 269238.43825
end
