@testsnippet StorageMinMaxLevelSetup begin
    using DuckDB: DuckDB
    using TulipaBuilder: TulipaBuilder as TB
    using TulipaClustering: TulipaClustering as TC

    # Storage configuration struct
    struct StorageMinMaxLevelConfig
        name::String
        is_seasonal::Bool
        initial_units::Float64
        initial_storage_units::Float64
        capacity::Float64
        capacity_storage_energy::Float64
        storage_method_energy::String
        energy_to_power_ratio::Float64
        investable::Bool
        investment_method::String
        investment_integer_storage_energy::Bool
    end

    ## TODO: Once TulipaBuilder supports attaching profiles to the `assets_timeframe_profiles` table for seasonal storage assets, we should update the `create_storage_min_max_level_test_problem` function to use that functionality instead of directly inserting into the database as we do below in `attach_seasonal_storage_min_max_level_profiles!`. We should then add a test specifically for attaching profiles to seasonal storage assets using the TulipaBuilder interface.
    function attach_seasonal_storage_min_max_level_profiles!(
        connection,
        asset_name,
        max_storage_level_profile,
        min_storage_level_profile,
    )
        # Create the assets_timeframe_profiles table if it doesn't exist
        DuckDB.execute(
            connection,
            """
            CREATE TABLE IF NOT EXISTS assets_timeframe_profiles (
                asset VARCHAR,
                milestone_year INTEGER,
                profile_name VARCHAR,
                profile_type VARCHAR,
                scenario INTEGER
            )
            """,
        )

        # Create the profiles_timeframe table if it doesn't exist
        DuckDB.execute(
            connection,
            """
            CREATE TABLE IF NOT EXISTS profiles_timeframe (
                profile_name VARCHAR,
                milestone_year INTEGER,
                period INTEGER,
                value DOUBLE
            )
            """,
        )

        # Insert max_storage_level profile rows
        for ((milestone_year, scenario), values) in max_storage_level_profile
            profile_name = "max_storage_level-$asset_name"
            DuckDB.execute(
                connection,
                """
                INSERT INTO assets_timeframe_profiles (asset, milestone_year, profile_name, profile_type, scenario)
                VALUES ('$asset_name', $milestone_year, '$profile_name', 'max_storage_level', $scenario)
                """,
            )
            for (period, value) in enumerate(values)
                DuckDB.execute(
                    connection,
                    """
                    INSERT INTO profiles_timeframe (profile_name, milestone_year, period, value)
                    VALUES ('$profile_name', $milestone_year, $period, $value)
                    """,
                )
            end
        end

        # Insert min_storage_level profile rows
        for ((milestone_year, scenario), values) in min_storage_level_profile
            profile_name = "min_storage_level-$asset_name"
            DuckDB.execute(
                connection,
                """
                INSERT INTO assets_timeframe_profiles (asset, milestone_year, profile_name, profile_type, scenario)
                VALUES ('$asset_name', $milestone_year, '$profile_name', 'min_storage_level', $scenario)
                """,
            )
            for (period, value) in enumerate(values)
                DuckDB.execute(
                    connection,
                    """
                    INSERT INTO profiles_timeframe (profile_name, milestone_year, period, value)
                    VALUES ('$profile_name', $milestone_year, $period, $value)
                    """,
                )
            end
        end

        return nothing
    end

    """
        create_storage_min_max_level_test_problem(
            storage_asset;
            max_storage_level_profile,
            min_storage_level_profile,
            num_timesteps, num_rps
        )

    Create a storage min-max level test problem with storage asset configuration.
    Returns the database connection with configured storage asset and clustering.
    """
    function create_storage_min_max_level_test_problem(
        storage_asset::StorageMinMaxLevelConfig;
        max_storage_level_profile::Dict{Tuple{Int,Int},Vector{Float64}} = Dict(
            (2030, 1) => [0.8, 0.5, 1.0],
        ),
        min_storage_level_profile::Dict{Tuple{Int,Int},Vector{Float64}} = Dict(
            (2030, 1) => [0.1, 0.4, 0.0],
        ),
        inflows_profile::Dict{Tuple{Int,Int},Vector{Float64}} = Dict((2030, 1) => [0.3, 0.7, 0.2]),
        num_timesteps::Int = 1,
        num_rps::Int = 2,
    )
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
            investment_integer_storage_energy = storage_asset.investment_integer_storage_energy,
        )
        TB.add_flow!(tulipa, "consumer", storage_asset.name)
        TB.add_flow!(tulipa, storage_asset.name, "consumer")

        if !storage_asset.is_seasonal
            # Attach max storage level profiles to the non-seasonal storage asset, commission_year and scenario
            for ((commission_year, scenario), values) in max_storage_level_profile
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
            for ((commission_year, scenario), values) in min_storage_level_profile
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
            # We need to attach at least one profile into 'assets_profiles' for the clustering. So, we attach the inflows profile.
            for ((commission_year, scenario), values) in inflows_profile
                TB.attach_profile!(
                    tulipa,
                    storage_asset.name,
                    :inflows,
                    commission_year,
                    values;
                    scenario = scenario,
                )
            end
        end
        ## TODO: TulipaBuilder v0.20 can't currently attach profiles to the `assets_timeframe_profiles` table for seasonal storage assets, so we handle it below using direct database operations. We should add this functionality in a future update and then test it.

        # Create connection
        connection = TB.create_connection(tulipa)

        # Attach max and min storage level profiles for seasonal storage assets directly to the database since TulipaBuilder v0.20 doesn't currently support this
        if storage_asset.is_seasonal
            attach_seasonal_storage_min_max_level_profiles!(
                connection,
                storage_asset.name,
                max_storage_level_profile,
                min_storage_level_profile,
            )
        end

        # Clustering to find representative periods
        layout = TC.ProfilesTableLayout(; year = :milestone_year, cols_to_crossby = [:scenario])
        TC.cluster!(connection, num_timesteps, num_rps; layout)

        # Populate with defaults and create model
        TEM.populate_with_defaults!(connection)
        energy_problem = TEM.EnergyProblem(connection)
        TEM.create_model!(energy_problem)

        return (connection, energy_problem)
    end
end

@testitem "Test non seasonal storage min/max constraints - no investment" setup =
    [CommonSetup, StorageMinMaxLevelSetup] tags = [:unit, :validation, :fast] begin

    # Non-seasonal storage only depends on representative periods,
    # not on scenarios, so we test with a single scenario.

    # storage asset parameters
    name = "battery"
    is_seasonal = false
    initial_units = 0.0
    initial_storage_units = 1.0
    capacity = 10.0
    capacity_storage_energy = 40.0
    storage_method_energy = "none"
    energy_to_power_ratio = 2.0
    investable = false
    investment_method = "none"
    investment_integer_storage_energy = false

    # Create storage asset config struct
    storage_asset = StorageMinMaxLevelConfig(
        name,
        is_seasonal,
        initial_units,
        initial_storage_units,
        capacity,
        capacity_storage_energy,
        storage_method_energy,
        energy_to_power_ratio,
        investable,
        investment_method,
        investment_integer_storage_energy,
    )

    # profile parameters
    max_storage_level_profile = Dict((2030, 1) => [0.8, 0.5, 1.0])
    min_storage_level_profile = Dict((2030, 1) => [0.1, 0.4, 0.0])

    # clustering parameters
    num_timesteps = 1
    num_rps = 2

    # Setup test problem with common helper
    connection, energy_problem = create_storage_min_max_level_test_problem(
        storage_asset;
        max_storage_level_profile,
        min_storage_level_profile,
        num_timesteps,
        num_rps,
    )

    # Extract storage level variable
    storage_level = energy_problem.variables[:storage_level_rep_period].container

    # Get profiles in the representative periods for this storage asset
    profiles = TulipaIO.get_table(connection, "profiles_rep_periods")
    min_profiles = filter(row -> occursin("min_storage_level", row.profile_name), profiles)
    max_profiles = filter(row -> occursin("max_storage_level", row.profile_name), profiles)

    # Verify all expected constraints exist
    # min/max constraints are created using the balance_storage_rep_period info
    cons_name = :balance_storage_rep_period
    constraint_data = DuckDB.query(
        connection,
        "SELECT id, rep_period, time_block_start
         FROM cons_$cons_name
         WHERE asset = '$name'
         ORDER BY rep_period, time_block_start",
    )
    num_constraints = constraint_data |> collect |> length
    @test num_constraints == num_rps * num_timesteps

    # Test each constraint for proper formulation
    for row in constraint_data
        rp, tb, id = Int(row.rep_period), Int(row.time_block_start), row.id

        # Build expected min_storage_level_rep_period_limit constraint
        expected_cons = JuMP.@build_constraint(
            storage_level[id] >=
            capacity_storage_energy * initial_storage_units * min_profiles.value[id]
        )

        # Verify constraint matches expected form
        @test _verify_constraint_using_id(
            energy_problem.model,
            :min_storage_level_rep_period_limit,
            id,
            expected_cons,
        )

        # Build expected max_storage_level_rep_period_limit constraint
        expected_cons = JuMP.@build_constraint(
            storage_level[id] <=
            capacity_storage_energy * initial_storage_units * max_profiles.value[id]
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
    [CommonSetup, StorageMinMaxLevelSetup] tags = [:unit, :validation, :fast] begin

    # Non-seasonal storage only depends on representative periods,
    # not on scenarios, so we test with a single scenario.

    # storage asset parameters
    name = "battery"
    is_seasonal = false
    initial_units = 2.0
    initial_storage_units = 1.0
    capacity = 10.0
    capacity_storage_energy = 40.0
    storage_method_energy = "optimize_storage_capacity"
    energy_to_power_ratio = 2.0
    investable = true
    investment_method = "simple"
    investment_integer_storage_energy = false

    # Create storage asset config struct
    storage_asset = StorageMinMaxLevelConfig(
        name,
        is_seasonal,
        initial_units,
        initial_storage_units,
        capacity,
        capacity_storage_energy,
        storage_method_energy,
        energy_to_power_ratio,
        investable,
        investment_method,
        investment_integer_storage_energy,
    )

    # profile parameters
    max_storage_level_profile = Dict((2030, 1) => [0.8, 0.5, 1.0])
    min_storage_level_profile = Dict((2030, 1) => [0.1, 0.4, 0.0])

    # clustering parameters
    num_timesteps = 1
    num_rps = 2

    # Setup test problem with common helper
    connection, energy_problem = create_storage_min_max_level_test_problem(
        storage_asset;
        max_storage_level_profile,
        min_storage_level_profile,
        num_timesteps,
        num_rps,
    )

    # Extract storage level variable
    storage_level = energy_problem.variables[:storage_level_rep_period].container

    # Extract energy storage investment
    assets_investment_energy = energy_problem.variables[:assets_investment_energy].container[1]

    # Get profiles in the representative periods for this storage asset
    profiles = TulipaIO.get_table(connection, "profiles_rep_periods")
    min_profiles = filter(row -> occursin("min_storage_level", row.profile_name), profiles)
    max_profiles = filter(row -> occursin("max_storage_level", row.profile_name), profiles)

    # Verify all expected constraints exist
    # min/max constraints are created using the balance_storage_rep_period info
    cons_name = :balance_storage_rep_period
    constraint_data = DuckDB.query(
        connection,
        "SELECT id, rep_period, time_block_start
         FROM cons_$cons_name
         WHERE asset = '$name'
         ORDER BY rep_period, time_block_start",
    )
    num_constraints = constraint_data |> collect |> length
    @test num_constraints == num_rps * num_timesteps

    # Test each constraint for proper formulation
    for row in constraint_data
        rp, tb, id = Int(row.rep_period), Int(row.time_block_start), row.id

        # Build expected min_storage_level_rep_period_limit constraint
        expected_cons = JuMP.@build_constraint(
            storage_level[id] >=
            capacity_storage_energy *
            min_profiles.value[id] *
            (initial_storage_units + assets_investment_energy)
        )

        # Verify constraint matches expected form
        @test _verify_constraint_using_id(
            energy_problem.model,
            :min_storage_level_rep_period_limit,
            id,
            expected_cons,
        )

        # Build expected max_storage_level_rep_period_limit constraint
        expected_cons = JuMP.@build_constraint(
            storage_level[id] <=
            capacity_storage_energy *
            max_profiles.value[id] *
            (initial_storage_units + assets_investment_energy)
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
    [CommonSetup, StorageMinMaxLevelSetup] tags = [:unit, :validation, :fast] begin

    # Non-seasonal storage only depends on representative periods,
    # not on scenarios, so we test with a single scenario.

    # storage asset parameters
    name = "battery"
    is_seasonal = false
    initial_units = 2.0
    initial_storage_units = 1.0
    capacity = 10.0
    capacity_storage_energy = 40.0
    storage_method_energy = "use_fixed_energy_to_power_ratio"
    energy_to_power_ratio = 2.0
    investable = true
    investment_method = "simple"
    investment_integer_storage_energy = false

    # Create storage asset config struct
    storage_asset = StorageMinMaxLevelConfig(
        name,
        is_seasonal,
        initial_units,
        initial_storage_units,
        capacity,
        capacity_storage_energy,
        storage_method_energy,
        energy_to_power_ratio,
        investable,
        investment_method,
        investment_integer_storage_energy,
    )

    # profile parameters
    max_storage_level_profile = Dict((2030, 1) => [0.8, 0.5, 1.0])
    min_storage_level_profile = Dict((2030, 1) => [0.1, 0.4, 0.0])

    # clustering parameters
    num_timesteps = 1
    num_rps = 2

    # Setup test problem with common helper
    connection, energy_problem = create_storage_min_max_level_test_problem(
        storage_asset;
        max_storage_level_profile,
        min_storage_level_profile,
        num_timesteps,
        num_rps,
    )

    # Extract storage level variable
    storage_level = energy_problem.variables[:storage_level_rep_period].container

    # Extract storage investment
    assets_investment = energy_problem.variables[:assets_investment].container[1]

    # Get profiles in the representative periods for this storage asset
    profiles = TulipaIO.get_table(connection, "profiles_rep_periods")
    min_profiles = filter(row -> occursin("min_storage_level", row.profile_name), profiles)
    max_profiles = filter(row -> occursin("max_storage_level", row.profile_name), profiles)

    # Verify all expected constraints exist
    # min/max constraints are created using the balance_storage_rep_period info
    cons_name = :balance_storage_rep_period
    constraint_data = DuckDB.query(
        connection,
        "SELECT id, rep_period, time_block_start
         FROM cons_$cons_name
         WHERE asset = '$name'
         ORDER BY rep_period, time_block_start",
    )
    num_constraints = constraint_data |> collect |> length
    @test num_constraints == num_rps * num_timesteps

    # Test each constraint for proper formulation
    for row in constraint_data
        rp, tb, id = Int(row.rep_period), Int(row.time_block_start), row.id

        # Build expected min_storage_level_rep_period_limit constraint
        expected_cons = JuMP.@build_constraint(
            storage_level[id] >=
            min_profiles.value[id] * (
                capacity_storage_energy * initial_storage_units +
                capacity * energy_to_power_ratio * assets_investment
            )
        )

        # Verify constraint matches expected form
        @test _verify_constraint_using_id(
            energy_problem.model,
            :min_storage_level_rep_period_limit,
            id,
            expected_cons,
        )

        # Build expected max_storage_level_rep_period_limit constraint
        expected_cons = JuMP.@build_constraint(
            storage_level[id] <=
            max_profiles.value[id] * (
                capacity_storage_energy * initial_storage_units +
                capacity * energy_to_power_ratio * assets_investment
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
    [CommonSetup, StorageMinMaxLevelSetup] tags = [:unit, :validation, :fast] begin

    # seasonal storage variables depend on the scenario

    # storage asset parameters
    name = "PHS"
    is_seasonal = true
    initial_units = 2.0
    initial_storage_units = 1.0
    capacity = 90.0
    capacity_storage_energy = 17280.0
    storage_method_energy = "none"
    energy_to_power_ratio = 168.0
    investable = false
    investment_method = "none"
    investment_integer_storage_energy = false

    # Create storage asset config struct
    storage_asset = StorageMinMaxLevelConfig(
        name,
        is_seasonal,
        initial_units,
        initial_storage_units,
        capacity,
        capacity_storage_energy,
        storage_method_energy,
        energy_to_power_ratio,
        investable,
        investment_method,
        investment_integer_storage_energy,
    )

    # profile parameters
    max_storage_level_profile = Dict((2030, 1) => [1.0, 1.0, 1.0])
    min_storage_level_profile = Dict((2030, 1) => [0.0, 0.0, 0.0])
    inflows_profile = Dict((2030, 1) => [0.3, 0.7, 0.2])

    # clustering parameters
    num_timesteps = 1
    num_rps = 2

    # Setup test problem with common helper
    connection, energy_problem = create_storage_min_max_level_test_problem(
        storage_asset;
        max_storage_level_profile,
        min_storage_level_profile,
        inflows_profile,
        num_timesteps,
        num_rps,
    )

    # Extract storage level variable
    storage_level = energy_problem.variables[:storage_level_inter_period].container

    # Verify all expected constraints exist
    # min/max constraints are created using the balance_storage_inter_period info
    cons_name = :balance_storage_inter_period
    constraint_data = DuckDB.query(
        connection,
        "SELECT id, milestone_year, scenario, period_block_start
         FROM cons_$cons_name
         WHERE asset = '$name'
         ORDER BY milestone_year, scenario, period_block_start",
    )
    num_constraints = constraint_data |> collect |> length
    @test num_constraints == length(inflows_profile[(2030, 1)])

    # Test each constraint for proper formulation
    for row in constraint_data
        y, sc, p, id =
            Int(row.milestone_year), Int(row.scenario), Int(row.period_block_start), row.id

        # Build expected min_storage_level_inter_period_limit constraint
        expected_cons = JuMP.@build_constraint(
            storage_level[id] >=
            min_storage_level_profile[(y, sc)][p] *
            (capacity_storage_energy * initial_storage_units)
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
            max_storage_level_profile[(y, sc)][p] *
            (capacity_storage_energy * initial_storage_units)
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
    [CommonSetup, StorageMinMaxLevelSetup] tags = [:unit, :validation, :fast] begin

    # seasonal storage variables depend on the scenario

    # storage asset parameters
    name = "PHS"
    is_seasonal = true
    initial_units = 2.0
    initial_storage_units = 1.0
    capacity = 90.0
    capacity_storage_energy = 17280.0
    storage_method_energy = "optimize_storage_capacity"
    energy_to_power_ratio = 168.0
    investable = true
    investment_method = "simple"
    investment_integer_storage_energy = false

    # Create storage asset config struct
    storage_asset = StorageMinMaxLevelConfig(
        name,
        is_seasonal,
        initial_units,
        initial_storage_units,
        capacity,
        capacity_storage_energy,
        storage_method_energy,
        energy_to_power_ratio,
        investable,
        investment_method,
        investment_integer_storage_energy,
    )

    # profile parameters
    max_storage_level_profile = Dict((2030, 1) => [1.0, 1.0, 1.0])
    min_storage_level_profile = Dict((2030, 1) => [0.0, 0.0, 0.0])
    inflows_profile = Dict((2030, 1) => [0.3, 0.7, 0.2])

    # clustering parameters
    num_timesteps = 1
    num_rps = 2

    # Setup test problem with common helper
    connection, energy_problem = create_storage_min_max_level_test_problem(
        storage_asset;
        max_storage_level_profile,
        min_storage_level_profile,
        inflows_profile,
        num_timesteps,
        num_rps,
    )

    # Extract storage level variable
    storage_level = energy_problem.variables[:storage_level_inter_period].container

    # Extract storage investment
    assets_investment_energy = energy_problem.variables[:assets_investment_energy].container[1]

    # Verify all expected constraints exist
    # min/max constraints are created using the balance_storage_inter_period info
    cons_name = :balance_storage_inter_period
    constraint_data = DuckDB.query(
        connection,
        "SELECT id, milestone_year, scenario, period_block_start
         FROM cons_$cons_name
         WHERE asset = '$name'
         ORDER BY milestone_year, scenario, period_block_start",
    )
    num_constraints = constraint_data |> collect |> length
    @test num_constraints == length(inflows_profile[(2030, 1)])

    # Test each constraint for proper formulation
    for row in constraint_data
        y, sc, p, id =
            Int(row.milestone_year), Int(row.scenario), Int(row.period_block_start), row.id

        # Build expected min_storage_level_inter_period_limit constraint
        expected_cons = JuMP.@build_constraint(
            storage_level[id] >=
            min_storage_level_profile[(y, sc)][p] *
            capacity_storage_energy *
            (initial_storage_units + assets_investment_energy)
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
            max_storage_level_profile[(y, sc)][p] *
            capacity_storage_energy *
            (initial_storage_units + assets_investment_energy)
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
    [CommonSetup, StorageMinMaxLevelSetup] tags = [:unit, :validation, :fast] begin

    # seasonal storage variables depend on the scenario

    # storage asset parameters
    name = "PHS"
    is_seasonal = true
    initial_units = 2.0
    initial_storage_units = 1.0
    capacity = 90.0
    capacity_storage_energy = 17280.0
    storage_method_energy = "use_fixed_energy_to_power_ratio"
    energy_to_power_ratio = 168.0
    investable = true
    investment_method = "simple"
    investment_integer_storage_energy = false

    # Create storage asset config struct
    storage_asset = StorageMinMaxLevelConfig(
        name,
        is_seasonal,
        initial_units,
        initial_storage_units,
        capacity,
        capacity_storage_energy,
        storage_method_energy,
        energy_to_power_ratio,
        investable,
        investment_method,
        investment_integer_storage_energy,
    )

    # profile parameters
    max_storage_level_profile = Dict((2030, 1) => [1.0, 1.0, 1.0])
    min_storage_level_profile = Dict((2030, 1) => [0.0, 0.0, 0.0])
    inflows_profile = Dict((2030, 1) => [0.3, 0.7, 0.2])

    # clustering parameters
    num_timesteps = 1
    num_rps = 2

    # Setup test problem with common helper
    connection, energy_problem = create_storage_min_max_level_test_problem(
        storage_asset;
        max_storage_level_profile,
        min_storage_level_profile,
        inflows_profile,
        num_timesteps,
        num_rps,
    )

    # Extract storage level variable
    storage_level = energy_problem.variables[:storage_level_inter_period].container

    # Extract storage investment
    assets_investment = energy_problem.variables[:assets_investment].container[1]

    # Verify all expected constraints exist
    # min/max constraints are created using the balance_storage_inter_period info
    cons_name = :balance_storage_inter_period
    constraint_data = DuckDB.query(
        connection,
        "SELECT id, milestone_year, scenario, period_block_start
         FROM cons_$cons_name
         WHERE asset = '$name'
         ORDER BY milestone_year, scenario, period_block_start",
    )
    num_constraints = constraint_data |> collect |> length
    @test num_constraints == length(inflows_profile[(2030, 1)])

    # Test each constraint for proper formulation
    for row in constraint_data
        y, sc, p, id =
            Int(row.milestone_year), Int(row.scenario), Int(row.period_block_start), row.id

        # Build expected min_storage_level_inter_period_limit constraint
        expected_cons = JuMP.@build_constraint(
            storage_level[id] >=
            min_storage_level_profile[(y, sc)][p] * (
                capacity_storage_energy * initial_storage_units +
                capacity * energy_to_power_ratio * assets_investment
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
            max_storage_level_profile[(y, sc)][p] * (
                capacity_storage_energy * initial_storage_units +
                capacity * energy_to_power_ratio * assets_investment
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
