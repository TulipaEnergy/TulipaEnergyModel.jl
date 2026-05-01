@testsnippet ConsStorageMinMaxLevelSetup begin
    using DuckDB: DuckDB
    using TulipaBuilder: TulipaBuilder as TB
    using TulipaClustering: TulipaClustering as TC

    # Configuration struct for testing
    @kwdef struct ConsStorageMinMaxLevelConfig
        is_seasonal::Bool
        storage_method_energy::String
        name::String = "dummy_storage"
        initial_units::Float64 = 2.0
        initial_storage_units::Float64 = 3.0
        capacity::Float64 = 5.0
        capacity_storage_energy::Float64 = 47.0
        energy_to_power_ratio::Float64 = 7.0
        investable::Bool = true
        investment_method::String = "simple"
        max_storage_level_profile::Dict{Tuple{Int,Int},Vector{Float64}} =
            Dict((2030, 1) => [0.8, 0.5, 1.0])
        min_storage_level_profile::Dict{Tuple{Int,Int},Vector{Float64}} =
            Dict((2030, 1) => [0.1, 0.4, 0.0])
        inflows_profile::Dict{Tuple{Int,Int},Vector{Float64}} = Dict((2030, 1) => [0.3, 0.7, 0.2])
        num_timesteps::Int = 1
        num_rps::Int = 2
    end

    """
        create_storage_min_max_level_test_problem(storage_asset)

    Create a storage min-max level test problem with storage asset configuration.
    Returns the database connection with configured storage asset and clustering.
    """
    function create_storage_min_max_level_test_problem(storage_asset::ConsStorageMinMaxLevelConfig)
        tulipa = TB.TulipaData()

        # Add basic producer and consumer to connect the storage
        TB.add_asset!(tulipa, "consumer", :consumer)

        # Add and configure the storage asset
        TB.add_asset!(
            tulipa,
            storage_asset.name,
            :storage;
            is_seasonal = storage_asset.is_seasonal,
            initial_units = storage_asset.initial_units,
            initial_storage_units = storage_asset.initial_storage_units,
            capacity = storage_asset.capacity,
            capacity_storage_energy = storage_asset.capacity_storage_energy,
            storage_method_energy = storage_asset.storage_method_energy,
            energy_to_power_ratio = storage_asset.energy_to_power_ratio,
            investable = storage_asset.investable,
            investment_method = storage_asset.investment_method,
        )
        TB.add_flow!(tulipa, "consumer", storage_asset.name)
        TB.add_flow!(tulipa, storage_asset.name, "consumer")

        # We need to attach at least one profile into 'assets_profiles' for the clustering. So, we attach the inflows profile.
        for ((commission_year, scenario), values) in storage_asset.inflows_profile
            TB.attach_profile!(
                tulipa,
                storage_asset.name,
                :inflows,
                commission_year,
                values;
                scenario = scenario,
            )
        end

        if !storage_asset.is_seasonal
            # Attach max storage level profiles to the non-seasonal storage asset, commission_year and scenario
            for ((commission_year, scenario), values) in storage_asset.max_storage_level_profile
                TB.attach_profile!(
                    tulipa,
                    storage_asset.name,
                    :max_storage_level,
                    commission_year,
                    values;
                    scenario = scenario,
                )
            end
            # Attach min storage level profiles to the non-seasonal storage asset, commission_year and scenario
            for ((commission_year, scenario), values) in storage_asset.min_storage_level_profile
                TB.attach_profile!(
                    tulipa,
                    storage_asset.name,
                    :min_storage_level,
                    commission_year,
                    values;
                    scenario = scenario,
                )
            end
        else
            # Attach max storage level profiles to the seasonal storage asset, milestone_year and scenario
            for ((milestone_year, scenario), values) in storage_asset.max_storage_level_profile
                TB.attach_timeframe_profile!(
                    tulipa,
                    storage_asset.name,
                    :max_storage_level,
                    milestone_year,
                    values;
                    scenario = scenario,
                )
            end
            # Attach min storage level profiles to the seasonal storage asset, milestone_year and scenario
            for ((milestone_year, scenario), values) in storage_asset.min_storage_level_profile
                TB.attach_timeframe_profile!(
                    tulipa,
                    storage_asset.name,
                    :min_storage_level,
                    milestone_year,
                    values;
                    scenario = scenario,
                )
            end
        end

        # Create connection
        connection = TB.create_connection(tulipa, TEM.schema)

        # Clustering to find representative periods
        layout = TC.ProfilesTableLayout(; year = :milestone_year, cols_to_crossby = [:scenario])
        TC.cluster!(connection, storage_asset.num_timesteps, storage_asset.num_rps; layout)

        # Populate with defaults and create model
        TEM.populate_with_defaults!(connection)
        energy_problem = TEM.EnergyProblem(connection)
        TEM.create_model!(energy_problem)

        return (connection, energy_problem)
    end

    function get_rep_periods_profile_value(
        connection,
        profile::String,
        milestone_year::Int32,
        rep_period::Int32,
        timestep::Int32,
    )
        return TEM.get_single_element_from_query_and_ensure_its_only_one(
            DuckDB.query(
                connection,
                "SELECT value
                 FROM profiles_rep_periods
                 WHERE profile_name LIKE '%$(profile)%' AND
                       milestone_year = $(milestone_year) AND
                       rep_period = $(rep_period) AND
                       timestep = $(timestep)
                 ORDER BY milestone_year, rep_period, timestep",
            ),
        )
    end

    function get_rep_periods_constraint_data(connection, storage_asset_name)
        # min/max constraints are created using the balance_storage_rep_period info
        return DuckDB.query(
            connection,
            "SELECT id, milestone_year, rep_period, time_block_start
             FROM cons_balance_storage_rep_period
             WHERE asset = '$(storage_asset_name)'
             ORDER BY milestone_year, rep_period, time_block_start",
        )
    end

    function get_inter_periods_constraint_data(connection, storage_asset_name)
        # min/max constraints are created using the balance_storage_inter_period info
        return DuckDB.query(
            connection,
            "SELECT id, milestone_year, scenario, period_block_start
             FROM cons_balance_storage_inter_period
             WHERE asset = '$(storage_asset_name)'
             ORDER BY milestone_year, scenario, period_block_start",
        )
    end
end

@testitem "Test non seasonal storage min/max constraints - no investment" setup =
    [CommonSetup, ConsStorageMinMaxLevelSetup] tags = [:unit, :constraint, :fast] begin

    # Non-seasonal storage only depends on representative periods,
    # not on scenarios, so we test with a single scenario.

    # Create storage asset config struct
    storage_asset = ConsStorageMinMaxLevelConfig(;
        is_seasonal = false,
        storage_method_energy = "none",
        investable = false,
        investment_method = "none",
    )

    # clustering parameters
    num_timesteps = storage_asset.num_timesteps
    num_rps = storage_asset.num_rps

    # Setup test problem with common helper
    connection, energy_problem = create_storage_min_max_level_test_problem(storage_asset)

    # Extract storage level variable
    storage_level = energy_problem.variables[:storage_level_rep_period].container

    # Verify all expected constraints exist
    constraint_data = get_rep_periods_constraint_data(connection, storage_asset.name)
    num_constraints = constraint_data |> collect |> length
    @test num_constraints == num_rps * num_timesteps

    # Test each constraint for proper formulation
    for row in constraint_data
        id, y, rp, ts = row.id, row.milestone_year, row.rep_period, row.time_block_start

        # Get profile values for this representative period
        min_profile_value =
            get_rep_periods_profile_value(connection, "min_storage_level", y, rp, ts)

        # Build expected min_storage_level_rep_period_limit constraint
        expected_cons = JuMP.@build_constraint(
            storage_level[id] >=
            storage_asset.capacity_storage_energy *
            storage_asset.initial_storage_units *
            min_profile_value
        )

        # Verify constraint matches expected form
        @test _verify_constraint_using_id(
            energy_problem.model,
            :min_storage_level_rep_period_limit,
            id,
            expected_cons,
        )

        # Get profile values for this representative period
        max_profile_value =
            get_rep_periods_profile_value(connection, "max_storage_level", y, rp, ts)

        # Build expected max_storage_level_rep_period_limit constraint
        expected_cons = JuMP.@build_constraint(
            storage_level[id] <=
            storage_asset.capacity_storage_energy *
            storage_asset.initial_storage_units *
            max_profile_value
        )

        # Verify constraint matches expected form
        @test _verify_constraint_using_id(
            energy_problem.model,
            :max_storage_level_rep_period_limit,
            id,
            expected_cons,
        )
    end
end

@testitem "Test non seasonal storage min/max constraints - investment with optimize_storage_capacity" setup =
    [CommonSetup, ConsStorageMinMaxLevelSetup] tags = [:unit, :constraint, :fast] begin

    # Non-seasonal storage only depends on representative periods,
    # not on scenarios, so we test with a single scenario.

    # Create storage asset config struct
    storage_asset = ConsStorageMinMaxLevelConfig(;
        is_seasonal = false,
        storage_method_energy = "optimize_storage_capacity",
    )

    # clustering parameters
    num_timesteps = storage_asset.num_timesteps
    num_rps = storage_asset.num_rps

    # Setup test problem with common helper
    connection, energy_problem = create_storage_min_max_level_test_problem(storage_asset)

    # Extract storage level variable
    storage_level = energy_problem.variables[:storage_level_rep_period].container

    # Extract energy storage investment
    assets_investment_energy = energy_problem.variables[:assets_investment_energy].container[1]

    # Verify all expected constraints exist
    constraint_data = get_rep_periods_constraint_data(connection, storage_asset.name)
    num_constraints = constraint_data |> collect |> length
    @test num_constraints == num_rps * num_timesteps

    # Test each constraint for proper formulation
    for row in constraint_data
        id, y, rp, ts = row.id, row.milestone_year, row.rep_period, row.time_block_start

        # Get profile values for this representative period
        min_profile_value =
            get_rep_periods_profile_value(connection, "min_storage_level", y, rp, ts)

        # Build expected min_storage_level_rep_period_limit constraint
        expected_cons = JuMP.@build_constraint(
            storage_level[id] >=
            min_profile_value *
            storage_asset.capacity_storage_energy *
            (storage_asset.initial_storage_units + assets_investment_energy)
        )

        # Verify constraint matches expected form
        @test _verify_constraint_using_id(
            energy_problem.model,
            :min_storage_level_rep_period_limit,
            id,
            expected_cons,
        )

        # Get profile values for this representative period
        max_profile_value =
            get_rep_periods_profile_value(connection, "max_storage_level", y, rp, ts)

        # Build expected max_storage_level_rep_period_limit constraint
        expected_cons = JuMP.@build_constraint(
            storage_level[id] <=
            max_profile_value *
            storage_asset.capacity_storage_energy *
            (storage_asset.initial_storage_units + assets_investment_energy)
        )

        # Verify constraint matches expected form
        @test _verify_constraint_using_id(
            energy_problem.model,
            :max_storage_level_rep_period_limit,
            id,
            expected_cons,
        )
    end
end

@testitem "Test non seasonal storage min/max constraints - investment with use_fixed_energy_to_power_ratio" setup =
    [CommonSetup, ConsStorageMinMaxLevelSetup] tags = [:unit, :constraint, :fast] begin

    # Non-seasonal storage only depends on representative periods,
    # not on scenarios, so we test with a single scenario.

    # Create storage asset config struct
    storage_asset = ConsStorageMinMaxLevelConfig(;
        is_seasonal = false,
        storage_method_energy = "use_fixed_energy_to_power_ratio",
    )

    # clustering parameters
    num_timesteps = storage_asset.num_timesteps
    num_rps = storage_asset.num_rps

    # Setup test problem with common helper
    connection, energy_problem = create_storage_min_max_level_test_problem(storage_asset)

    # Extract storage level variable
    storage_level = energy_problem.variables[:storage_level_rep_period].container

    # Extract storage investment
    assets_investment = energy_problem.variables[:assets_investment].container[1]

    # Verify all expected constraints exist
    constraint_data = get_rep_periods_constraint_data(connection, storage_asset.name)
    num_constraints = constraint_data |> collect |> length
    @test num_constraints == num_rps * num_timesteps

    # Test each constraint for proper formulation
    for row in constraint_data
        id, y, rp, ts = row.id, row.milestone_year, row.rep_period, row.time_block_start

        # Get profile values for this representative period
        min_profile_value =
            get_rep_periods_profile_value(connection, "min_storage_level", y, rp, ts)

        # Build expected min_storage_level_rep_period_limit constraint
        expected_cons = JuMP.@build_constraint(
            storage_level[id] >=
            min_profile_value * (
                storage_asset.capacity_storage_energy * storage_asset.initial_storage_units +
                storage_asset.capacity * storage_asset.energy_to_power_ratio * assets_investment
            )
        )

        # Verify constraint matches expected form
        @test _verify_constraint_using_id(
            energy_problem.model,
            :min_storage_level_rep_period_limit,
            id,
            expected_cons,
        )

        # Get profile values for this representative period
        max_profile_value =
            get_rep_periods_profile_value(connection, "max_storage_level", y, rp, ts)

        # Build expected max_storage_level_rep_period_limit constraint
        expected_cons = JuMP.@build_constraint(
            storage_level[id] <=
            max_profile_value * (
                storage_asset.capacity_storage_energy * storage_asset.initial_storage_units +
                storage_asset.capacity * storage_asset.energy_to_power_ratio * assets_investment
            )
        )

        # Verify constraint matches expected form
        @test _verify_constraint_using_id(
            energy_problem.model,
            :max_storage_level_rep_period_limit,
            id,
            expected_cons,
        )
    end
end

@testitem "Test seasonal storage min/max constraints - no investment" setup =
    [CommonSetup, ConsStorageMinMaxLevelSetup] tags = [:unit, :constraint, :fast] begin

    # seasonal storage variables depend on the scenario

    # Create storage asset config struct
    storage_asset = ConsStorageMinMaxLevelConfig(;
        is_seasonal = true,
        storage_method_energy = "none",
        investable = false,
        investment_method = "none",
        max_storage_level_profile = Dict((2030, 1) => [0.8, 0.4, 1.0]),
        min_storage_level_profile = Dict((2030, 1) => [0.2, 0.3, 0.0]),
    )

    # Setup test problem with common helper
    connection, energy_problem = create_storage_min_max_level_test_problem(storage_asset)

    # Extract storage level variable
    storage_level = energy_problem.variables[:storage_level_inter_period].container

    # Verify all expected constraints exist
    constraint_data = get_inter_periods_constraint_data(connection, storage_asset.name)
    num_constraints = constraint_data |> collect |> length
    @test num_constraints == length(storage_asset.inflows_profile[(2030, 1)])

    # Test each constraint for proper formulation
    for row in constraint_data
        y, sc, p, id =
            Int(row.milestone_year), Int(row.scenario), Int(row.period_block_start), row.id

        # Build expected min_storage_level_inter_period_limit constraint
        expected_cons = JuMP.@build_constraint(
            storage_level[id] >=
            storage_asset.min_storage_level_profile[(y, sc)][p] *
            (storage_asset.capacity_storage_energy * storage_asset.initial_storage_units)
        )

        # Verify constraint matches expected form
        @test _verify_constraint_using_id(
            energy_problem.model,
            :min_storage_level_inter_period_limit,
            id,
            expected_cons,
        )

        # Build expected max_storage_level_inter_period_limit constraint
        expected_cons = JuMP.@build_constraint(
            storage_level[id] <=
            storage_asset.max_storage_level_profile[(y, sc)][p] *
            (storage_asset.capacity_storage_energy * storage_asset.initial_storage_units)
        )

        # Verify constraint matches expected form
        @test _verify_constraint_using_id(
            energy_problem.model,
            :max_storage_level_inter_period_limit,
            id,
            expected_cons,
        )
    end
end

@testitem "Test seasonal storage min/max constraints - investment with optimize_storage_capacity" setup =
    [CommonSetup, ConsStorageMinMaxLevelSetup] tags = [:unit, :constraint, :fast] begin

    # seasonal storage variables depend on the scenario

    # Create storage asset config struct
    storage_asset = ConsStorageMinMaxLevelConfig(;
        is_seasonal = true,
        storage_method_energy = "optimize_storage_capacity",
        max_storage_level_profile = Dict((2030, 1) => [0.8, 0.4, 1.0]),
        min_storage_level_profile = Dict((2030, 1) => [0.2, 0.3, 0.0]),
    )

    # Setup test problem with common helper
    connection, energy_problem = create_storage_min_max_level_test_problem(storage_asset)

    # Extract storage level variable
    storage_level = energy_problem.variables[:storage_level_inter_period].container

    # Extract storage investment
    assets_investment_energy = energy_problem.variables[:assets_investment_energy].container[1]

    # Verify all expected constraints exist
    constraint_data = get_inter_periods_constraint_data(connection, storage_asset.name)
    num_constraints = constraint_data |> collect |> length
    @test num_constraints == length(storage_asset.inflows_profile[(2030, 1)])

    # Test each constraint for proper formulation
    for row in constraint_data
        y, sc, p, id =
            Int(row.milestone_year), Int(row.scenario), Int(row.period_block_start), row.id

        # Build expected min_storage_level_inter_period_limit constraint
        expected_cons = JuMP.@build_constraint(
            storage_level[id] >=
            storage_asset.min_storage_level_profile[(y, sc)][p] *
            storage_asset.capacity_storage_energy *
            (storage_asset.initial_storage_units + assets_investment_energy)
        )

        # Verify constraint matches expected form
        @test _verify_constraint_using_id(
            energy_problem.model,
            :min_storage_level_inter_period_limit,
            id,
            expected_cons,
        )

        # Build expected max_storage_level_inter_period_limit constraint
        expected_cons = JuMP.@build_constraint(
            storage_level[id] <=
            storage_asset.max_storage_level_profile[(y, sc)][p] *
            storage_asset.capacity_storage_energy *
            (storage_asset.initial_storage_units + assets_investment_energy)
        )

        # Verify constraint matches expected form
        @test _verify_constraint_using_id(
            energy_problem.model,
            :max_storage_level_inter_period_limit,
            id,
            expected_cons,
        )
    end
end

@testitem "Test seasonal storage min/max constraints - investment with use_fixed_energy_to_power_ratio" setup =
    [CommonSetup, ConsStorageMinMaxLevelSetup] tags = [:unit, :constraint, :fast] begin

    # seasonal storage variables depend on the scenario

    # Create storage asset config struct
    storage_asset = ConsStorageMinMaxLevelConfig(;
        is_seasonal = true,
        storage_method_energy = "use_fixed_energy_to_power_ratio",
        max_storage_level_profile = Dict((2030, 1) => [0.8, 0.4, 1.0]),
        min_storage_level_profile = Dict((2030, 1) => [0.2, 0.3, 0.0]),
    )

    # Setup test problem with common helper
    connection, energy_problem = create_storage_min_max_level_test_problem(storage_asset)

    # Extract storage level variable
    storage_level = energy_problem.variables[:storage_level_inter_period].container

    # Extract storage investment
    assets_investment = energy_problem.variables[:assets_investment].container[1]

    # Verify all expected constraints exist
    constraint_data = get_inter_periods_constraint_data(connection, storage_asset.name)
    num_constraints = constraint_data |> collect |> length
    @test num_constraints == length(storage_asset.inflows_profile[(2030, 1)])

    # Test each constraint for proper formulation
    for row in constraint_data
        y, sc, p, id =
            Int(row.milestone_year), Int(row.scenario), Int(row.period_block_start), row.id

        # Build expected min_storage_level_inter_period_limit constraint
        expected_cons = JuMP.@build_constraint(
            storage_level[id] >=
            storage_asset.min_storage_level_profile[(y, sc)][p] * (
                storage_asset.capacity_storage_energy * storage_asset.initial_storage_units +
                storage_asset.capacity * storage_asset.energy_to_power_ratio * assets_investment
            )
        )

        # Verify constraint matches expected form
        @test _verify_constraint_using_id(
            energy_problem.model,
            :min_storage_level_inter_period_limit,
            id,
            expected_cons,
        )

        # Build expected max_storage_level_inter_period_limit constraint
        expected_cons = JuMP.@build_constraint(
            storage_level[id] <=
            storage_asset.max_storage_level_profile[(y, sc)][p] * (
                storage_asset.capacity_storage_energy * storage_asset.initial_storage_units +
                storage_asset.capacity * storage_asset.energy_to_power_ratio * assets_investment
            )
        )

        # Verify constraint matches expected form
        @test _verify_constraint_using_id(
            energy_problem.model,
            :max_storage_level_inter_period_limit,
            id,
            expected_cons,
        )
    end
end
