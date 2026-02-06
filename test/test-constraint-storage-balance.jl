@testsnippet StorageSetup begin
    using DuckDB: DuckDB
    using TulipaBuilder: TulipaBuilder as TB
    using TulipaClustering: TulipaClustering as TC

    # Type-stable storage configuration struct
    struct StorageConfig
        inflows::Float64
        is_seasonal::Bool
        initial_units::Float64
        initial_storage_units::Float64
        charging_efficiency::Float64
        discharging_efficiency::Float64
        initial_storage_level::Float64
        capacity::Float64
        capacity_storage_energy::Float64
    end

    # Storage asset configuration data
    const STORAGE_CONFIGS = Dict{String,StorageConfig}(
        "seasonal_storage" => StorageConfig(
            10.0,  # inflows
            true,  # is_seasonal
            1.0,   # initial_units
            1.0,   # initial_storage_units
            0.85,  # charging_efficiency
            0.8,   # discharging_efficiency
            0.5,   # initial_storage_level
            1.0,   # capacity
            168.0, # capacity_storage_energy
        ),
        "non_seasonal_storage" => StorageConfig(
            3.5,   # inflows
            false, # is_seasonal
            1.0,   # initial_units
            1.0,   # initial_storage_units
            0.9,   # charging_efficiency
            0.95,  # discharging_efficiency
            0.25,  # initial_storage_level
            1.0,   # capacity
            4.0,   # capacity_storage_energy
        ),
    )

    """
        create_storage_balance_problem(; inflows_profile, period_duration, num_rps)

    Create a storage balance test problem with two storage assets.
    Returns the database connection with configured storage assets and clustering.
    """
    function create_storage_balance_problem(;
        inflows_profile::Dict{Tuple{String,Int,Int},Vector{Float64}} = Dict(
            ("seasonal_storage", 2030, 1) => [1.0, 5.5, 10.0],
        ),
        period_duration::Int = 1,
        num_rps::Int = 2,
    )::DuckDB.DB
        tulipa = TB.TulipaData()

        # Add basic producer and consumer for flow balance
        TB.add_asset!(tulipa, "generator", :producer)
        TB.add_asset!(tulipa, "consumer", :consumer)
        TB.add_flow!(tulipa, "generator", "consumer")

        # Add and configure storage assets
        for (storage_name, config) in STORAGE_CONFIGS
            TB.add_asset!(
                tulipa,
                storage_name,
                :storage;
                storage_inflows = config.inflows,
                is_seasonal = config.is_seasonal,
                initial_units = config.initial_units,
                initial_storage_units = config.initial_storage_units,
                storage_charging_efficiency = config.charging_efficiency,
                storage_discharging_efficiency = config.discharging_efficiency,
                initial_storage_level = config.initial_storage_level,
                capacity = config.capacity,
                capacity_storage_energy = config.capacity_storage_energy,
            )
            TB.add_flow!(tulipa, "consumer", storage_name)
            TB.add_flow!(tulipa, storage_name, "consumer")

            # Attach inflows profiles per  storage asset, year and scenario
            for ((asset, year, scenario), values) in inflows_profile
                if asset == storage_name
                    TB.attach_profile!(
                        tulipa,
                        storage_name,
                        :inflows,
                        year,
                        values;
                        scenario = scenario,
                    )
                end
            end
        end

        # Create connection and apply clustering
        connection = TB.create_connection(tulipa)
        layout = TC.ProfilesTableLayout(; cols_to_crossby = [:scenario])
        TC.cluster!(
            connection,
            period_duration,
            num_rps;
            method = :convex_hull,
            weight_type = :convex,
            tol = 1e-6,
            weight_fitting_kwargs = Dict(:learning_rate => 0.001, :niters => 1000),
            layout = layout,
        )

        return connection
    end

    """
        get_flow_ids(connection, storage_asset, num_rps, period_duration) -> (incoming, outgoing)

    Query incoming and outgoing flow IDs for a storage asset across all time blocks.
    Returns two dictionaries indexed by (rep_period, time_block_start).
    """
    function get_flow_ids(
        connection::DuckDB.DB,
        storage_asset::String,
        num_rps::Int,
        period_duration::Int,
    )::Tuple{Dict{Tuple{Int,Int},Vector{Int}},Dict{Tuple{Int,Int},Vector{Int}}}
        # Pre-allocate dictionaries for all time blocks
        incoming = Dict{Tuple{Int,Int},Vector{Int}}(
            (rp, tb) => Int[] for rp in 1:num_rps for tb in 1:period_duration
        )
        outgoing = Dict{Tuple{Int,Int},Vector{Int}}(
            (rp, tb) => Int[] for rp in 1:num_rps for tb in 1:period_duration
        )

        # Query flow IDs for each time block
        for rp in 1:num_rps, tb in 1:period_duration
            incoming[(rp, tb)] = [
                row.id for row in DuckDB.query(
                    connection,
                    "SELECT id FROM var_flow WHERE to_asset = '$storage_asset' AND rep_period = $rp AND time_block_start = $tb",
                )
            ]
            outgoing[(rp, tb)] = [
                row.id for row in DuckDB.query(
                    connection,
                    "SELECT id FROM var_flow WHERE from_asset = '$storage_asset' AND rep_period = $rp AND time_block_start = $tb",
                )
            ]
        end

        return (incoming, outgoing)
    end

    """
        get_storage_ids(connection, storage_asset, scenarios, periods) -> (storage_level_ids)

    Query storage level over clustered year IDs for a storage asset for each scenario and period block.
    Returns a dictionary indexed by (scenario, period).
    """
    function get_storage_ids(
        connection::DuckDB.DB,
        storage_asset::String,
        scenarios::UnitRange{Int},
        periods::UnitRange{Int},
    )::Dict{Tuple{Int,Int},Int}
        # Pre-allocate dictionaries
        storage_level_ids = Dict{Tuple{Int,Int},Int}(
            (scenario, period) => 0 for scenario in scenarios for period in periods
        )

        # Query storage level IDs for each scenario and period block
        for s in scenarios, p in periods
            storage_level_ids[(s, p)] = [
                row.id for row in DuckDB.query(
                    connection,
                    "SELECT id
                     FROM var_storage_level_over_clustered_year
                     WHERE asset = '$storage_asset' AND
                           scenario = $s AND
                           period_block_start = $p",
                )
            ][1] # one variable per scenario and period block
        end

        return storage_level_ids
    end

    """
        get_inflow_value(profiles_rep_periods, rp, tb) -> Float64

    Extract inflow value for a given representative period and time block.
    Returns 0.0 if no matching profile is found.
    """
    function get_inflow_value(profiles_rep_periods::DataFrame, rp::Int, tb::Int)::Float64
        filtered = profiles_rep_periods[
            (profiles_rep_periods.rep_period.==rp).&(profiles_rep_periods.timestep.==tb),
            :value,
        ]
        return isempty(filtered) ? 0.0 : filtered[1]
    end

    """
        compute_flow_terms(flow, flow_ids, efficiency) -> JuMP.AffExpr

    Compute weighted flow term for charging or discharging.
    """
    function compute_flow_terms(
        flow::Vector{JuMP.VariableRef},
        flow_ids::Vector{Int},
        efficiency::Float64,
    )::JuMP.AffExpr
        return sum(flow[id] for id in flow_ids; init = JuMP.AffExpr(0.0)) * efficiency
    end

    """
        compute_expected_terms_seasonal_storage(...)

    Compute aggregated flow and inflow terms for seasonal storage over a period.
    Aggregates across all representative periods using their weights.
    """
    function compute_expected_terms_seasonal_storage(
        flow::Vector{JuMP.VariableRef},
        incoming_flow_ids::Dict{Tuple{Int,Int},Vector{Int}},
        outgoing_flow_ids::Dict{Tuple{Int,Int},Vector{Int}},
        period_weight_map::Dict{Tuple{Int,Int,Int},Float64},
        profiles_rep_periods::DataFrame,
        scenario::Int,
        period::Int,
        num_rps::Int,
        period_duration::Int,
        config::StorageConfig,
    )::Tuple{JuMP.AffExpr,JuMP.AffExpr,Float64}
        incoming = JuMP.AffExpr(0.0)
        outgoing = JuMP.AffExpr(0.0)
        inflows = 0.0

        for rp in 1:num_rps
            weight = get(period_weight_map, (scenario, period, rp), 0.0)
            for tb in 1:period_duration
                # Compute weighted charging flows
                incoming +=
                    compute_flow_terms(
                        flow,
                        incoming_flow_ids[(rp, tb)],
                        config.charging_efficiency,
                    ) * weight

                # Compute weighted discharging flows (divide by efficiency for energy balance)
                outgoing +=
                    compute_flow_terms(
                        flow,
                        outgoing_flow_ids[(rp, tb)],
                        1.0 / config.discharging_efficiency,
                    ) * weight

                # Aggregate weighted inflows
                profile_value = get_inflow_value(profiles_rep_periods, rp, tb)
                inflows += weight * profile_value * config.inflows
            end
        end

        return (incoming, outgoing, inflows)
    end

    """
        compute_expected_terms_non_seasonal_storage(...)

    Compute flow and inflow terms for non-seasonal storage at a specific time block.
    No aggregation across representative periods - each time block is independent.
    """
    function compute_expected_terms_non_seasonal_storage(
        flow::Vector{JuMP.VariableRef},
        incoming_flow_ids::Dict{Tuple{Int,Int},Vector{Int}},
        outgoing_flow_ids::Dict{Tuple{Int,Int},Vector{Int}},
        profiles_rep_periods::DataFrame,
        rp::Int,
        tb::Int,
        config::StorageConfig,
    )::Tuple{JuMP.AffExpr,JuMP.AffExpr,Float64}
        # Compute charging flows
        incoming = compute_flow_terms(flow, incoming_flow_ids[(rp, tb)], config.charging_efficiency)

        # Compute discharging flows (divide by efficiency for energy balance)
        outgoing = compute_flow_terms(
            flow,
            outgoing_flow_ids[(rp, tb)],
            1.0 / config.discharging_efficiency,
        )

        # Get inflows for this time block
        profile_value = get_inflow_value(profiles_rep_periods, rp, tb)
        inflows = profile_value * config.inflows

        return (incoming, outgoing, inflows)
    end
end

@testitem "Test non seasonal storage balance constraints" setup = [CommonSetup, StorageSetup] tags =
    [:unit, :validation, :fast] begin
    using DuckDB: DuckDB
    using JuMP: JuMP

    # Non-seasonal storage (intra-day/week) only depends on representative periods,
    # not on scenarios, so we test with a single scenario.

    # Setup test parameters
    storage_asset = "non_seasonal_storage"
    config = STORAGE_CONFIGS[storage_asset]
    year = 2030
    inflows_profile = Dict((storage_asset, year, 1) => [1.0, 5.5, 10.0, 2.5]) # keys = (asset, year, scenario)
    period_duration = 2
    num_rps = 2

    # Create and configure the test problem
    connection = create_storage_balance_problem(;
        inflows_profile = inflows_profile,
        period_duration = period_duration,
        num_rps = num_rps,
    )
    TEM.populate_with_defaults!(connection)
    energy_problem = TEM.EnergyProblem(connection)
    TEM.create_model!(energy_problem)

    # Extract model variables
    flow = energy_problem.variables[:flow].container
    storage_level = energy_problem.variables[:storage_level_rep_period].container

    # Get inflow profiles for this storage asset
    profiles = TulipaIO.get_table(connection, "profiles_rep_periods")
    profiles = filter(row -> occursin(storage_asset, row.profile_name), profiles)

    # Get flow IDs for charging and discharging
    incoming_flow_ids, outgoing_flow_ids =
        get_flow_ids(connection, storage_asset, num_rps, period_duration)

    # Verify all expected constraints exist
    cons_name = :balance_storage_rep_period
    constraint_data = [row for row in DuckDB.query(
        connection,
        "SELECT id, rep_period, time_block_start
         FROM cons_$cons_name
         WHERE asset = '$storage_asset'
         ORDER BY rep_period, time_block_start",
    )]
    @test length(constraint_data) == num_rps * period_duration

    # Test each constraint
    for row in constraint_data
        rp = Int(row.rep_period)
        tb = Int(row.time_block_start)
        id = row.id

        # Compute expected terms for this time block
        incoming, outgoing, inflows = compute_expected_terms_non_seasonal_storage(
            flow,
            incoming_flow_ids,
            outgoing_flow_ids,
            profiles,
            rp,
            tb,
            config,
        )

        # Build expected constraint based on position in time series
        expected_cons = if tb == 1
            # First time block: balance includes initial storage level
            JuMP.@build_constraint(
                storage_level[id] - incoming + outgoing == inflows + config.initial_storage_level
            )
        else
            # Subsequent time blocks: balance against previous time block
            JuMP.@build_constraint(
                storage_level[id] - storage_level[id-1] - incoming + outgoing == inflows
            )
        end

        # Verify constraint matches expected form
        observed_cons = _get_cons_object(energy_problem.model, cons_name)[id]
        @test _is_constraint_equal(expected_cons, observed_cons)
    end
end

@testitem "Test seasonal storage balance constraints - single scenario" setup =
    [CommonSetup, StorageSetup] tags = [:unit, :validation, :fast] begin
    using DuckDB: DuckDB
    using JuMP: JuMP

    # Seasonal storage aggregates across representative periods using weights.
    # This test uses a single scenario to verify the constraint formulation.

    # Setup test parameters
    storage_asset = "seasonal_storage"
    config = STORAGE_CONFIGS[storage_asset]
    year = 2030
    inflows_profile = Dict((storage_asset, year, 1) => [1.0, 5.5, 10.0]) # keys = (asset, year, scenario)
    periods = 1:length(inflows_profile[(storage_asset, year, 1)])
    period_duration = 1
    num_rps = 2

    # Create and configure the test problem
    connection = create_storage_balance_problem(;
        inflows_profile = inflows_profile,
        period_duration = period_duration,
        num_rps = num_rps,
    )
    TEM.populate_with_defaults!(connection)
    energy_problem = TEM.EnergyProblem(connection)
    TEM.create_model!(energy_problem)

    # Extract model variables
    flow = energy_problem.variables[:flow].container
    storage_level = energy_problem.variables[:storage_level_over_clustered_year].container

    # Build period-to-representative-period weight mapping
    rep_periods_mapping = TulipaIO.get_table(connection, "rep_periods_mapping")
    period_weight_map = Dict{Tuple{Int,Int,Int},Float64}(
        (1, row.period, row.rep_period) => get(row, :weight, 0.0) for
        row in eachrow(rep_periods_mapping)
    ) # single scenario = 1 in the key

    # Get inflow profiles for this storage asset
    profiles = TulipaIO.get_table(connection, "profiles_rep_periods")
    profiles = filter(row -> occursin(storage_asset, row.profile_name), profiles)

    # Get flow IDs for charging and discharging
    incoming_flow_ids, outgoing_flow_ids =
        get_flow_ids(connection, storage_asset, num_rps, period_duration)

    # Verify all expected constraints exist
    cons_name = :balance_storage_over_clustered_year
    constraint_ids = [
        row.id for row in DuckDB.query(
            connection,
            "SELECT id FROM cons_$cons_name WHERE asset = '$storage_asset'",
        )
    ]
    @test length(constraint_ids) == length(periods)

    # Test each period's constraint
    for period in periods
        # Compute expected terms aggregated over all representative periods
        incoming, outgoing, inflows_sum = compute_expected_terms_seasonal_storage(
            flow,
            incoming_flow_ids,
            outgoing_flow_ids,
            period_weight_map,
            profiles,
            1, # single scenario
            period,
            num_rps,
            period_duration,
            config,
        )

        # Build expected constraint based on position in time series
        expected_cons = if period == 1
            # First period: balance includes initial storage level
            JuMP.@build_constraint(
                storage_level[period] - incoming + outgoing ==
                inflows_sum + config.initial_storage_level
            )
        else
            # Subsequent periods: balance against previous period
            JuMP.@build_constraint(
                storage_level[period] - storage_level[period-1] - incoming + outgoing ==
                inflows_sum
            )
        end

        # Verify constraint matches expected form
        observed_cons = _get_cons_object(energy_problem.model, cons_name)[period]
        @test _is_constraint_equal(expected_cons, observed_cons)
    end
end

@testitem "Test seasonal storage balance constraints - two scenarios" setup =
    [CommonSetup, StorageSetup] tags = [:unit, :validation, :fast] begin
    using DuckDB: DuckDB
    using JuMP: JuMP

    # Seasonal storage aggregates across representative periods using weights.
    # This test uses two scenarios to verify the constraint formulation.

    # Setup test parameters
    storage_asset = "seasonal_storage"
    config = STORAGE_CONFIGS[storage_asset]
    year = 2030
    inflows_profile = Dict(
        (storage_asset, year, 1) => [1.0, 5.5, 10.0], # Scenario 1
        (storage_asset, year, 2) => [10.0, 5.5, 1.0], # Scenario 2
    ) # keys = (asset, year, scenario)
    periods = 1:length(inflows_profile[(storage_asset, year, 1)])
    scenarios = 1:2
    period_duration = 1
    num_rps = 2

    # Create and configure the test problem
    connection = create_storage_balance_problem(;
        inflows_profile = inflows_profile,
        period_duration = period_duration,
        num_rps = num_rps,
    )
    TEM.populate_with_defaults!(connection)
    energy_problem = TEM.EnergyProblem(connection)
    TEM.create_model!(energy_problem; model_file_name = "seasonal_storage_balance_two_scenarios.lp")

    # Extract model variables
    flow = energy_problem.variables[:flow].container
    storage_level = energy_problem.variables[:storage_level_over_clustered_year].container

    # Build period-to-representative-period weight mapping
    rep_periods_mapping = TulipaIO.get_table(connection, "rep_periods_mapping")
    period_weight_map = Dict{Tuple{Int,Int,Int},Float64}(
        (row.scenario, row.period, row.rep_period) => get(row, :weight, 0.0) for
        row in eachrow(rep_periods_mapping)
    )

    # Get inflow profiles for this storage asset
    profiles = TulipaIO.get_table(connection, "profiles_rep_periods")
    profiles = filter(row -> occursin(storage_asset, row.profile_name), profiles)

    # Get flow IDs for charging and discharging
    incoming_flow_ids, outgoing_flow_ids =
        get_flow_ids(connection, storage_asset, num_rps, period_duration)

    # Get storage level variable IDs for all periods and scenarios
    storage_level_ids = get_storage_ids(connection, storage_asset, scenarios, periods)

    # Verify all expected constraints exist
    cons_name = :balance_storage_over_clustered_year
    constraint_ids = [
        row.id for row in DuckDB.query(
            connection,
            "SELECT id FROM cons_$cons_name WHERE asset = '$storage_asset'",
        )
    ]
    @test length(constraint_ids) == length(periods) * length(scenarios)

    # Test each scenario and period
    for scenario in scenarios, period in periods
        # Compute expected terms aggregated over all representative periods
        incoming, outgoing, inflows_sum = compute_expected_terms_seasonal_storage(
            flow,
            incoming_flow_ids,
            outgoing_flow_ids,
            period_weight_map,
            profiles,
            scenario,
            period,
            num_rps,
            period_duration,
            config,
        )
        # Build expected constraint based on position in time series
        expected_cons = if period == 1
            # First period: balance includes initial storage level
            JuMP.@build_constraint(
                storage_level[storage_level_ids[(scenario, period)]] - incoming + outgoing ==
                inflows_sum + config.initial_storage_level
            )
        else
            # Subsequent periods: balance against previous period
            JuMP.@build_constraint(
                storage_level[storage_level_ids[(scenario, period)]] -
                storage_level[storage_level_ids[(scenario, period - 1)]] - incoming +
                outgoing == inflows_sum
            )
        end

        # Verify constraint matches expected form
        observed_cons_id = maximum(periods) * (scenario - 1) + period # constraints are ordered by scenario and period
        observed_cons = _get_cons_object(energy_problem.model, cons_name)[observed_cons_id]
        @test _is_constraint_equal(expected_cons, observed_cons)
    end
end
