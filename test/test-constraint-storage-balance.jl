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
        create_storage_balance_problem(; inflows_profile, num_timesteps, num_rps)

    Create a storage balance test problem with two storage assets.
    Returns the database connection with configured storage assets and clustering.
    """
    function create_storage_balance_problem(;
        inflows_profile::Dict{Tuple{String,Int,Int},Vector{Float64}} = Dict(
            ("seasonal_storage", 2030, 1) => [1.0, 5.5, 10.0],
        ),
        num_timesteps::Int = 1,
        num_rps::Int = 2,
    )
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

            # Attach inflows profiles per  storage asset, milestone_year and scenario
            for ((asset, milestone_year, scenario), values) in inflows_profile
                if asset == storage_name
                    TB.attach_profile!(
                        tulipa,
                        storage_name,
                        :inflows,
                        milestone_year,
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
            num_timesteps,
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
        incoming, outgoing = get_flow_ids(connection, storage_asset, num_rps, num_timesteps)

    Query incoming and outgoing flow IDs for a storage asset across all time blocks.
    Returns two dictionaries indexed by (rep_period, time_block_start).

    Optimized to use a single batched query instead of multiple queries.
    """
    function get_flow_ids(
        connection::DuckDB.DB,
        storage_asset::String,
        num_rps::Int,
        num_timesteps::Int,
    )
        # Pre-allocate dictionaries for all time blocks
        incoming = Dict{Tuple{Int,Int},Vector{Int}}()
        outgoing = Dict{Tuple{Int,Int},Vector{Int}}()

        # Initialize empty vectors for each time block
        for rp in 1:num_rps, tb in 1:num_timesteps
            incoming[(rp, tb)] = Int[]
            outgoing[(rp, tb)] = Int[]
        end

        # Batch query for both incoming and outgoing flows
        query_incoming = """
            SELECT id, rep_period, time_block_start
            FROM var_flow
            WHERE to_asset = '$storage_asset'
            ORDER BY rep_period, time_block_start
        """
        query_outgoing = """
            SELECT id, rep_period, time_block_start
            FROM var_flow
            WHERE from_asset = '$storage_asset'
            ORDER BY rep_period, time_block_start
        """

        # Process incoming flows
        for row in DuckDB.query(connection, query_incoming)
            key = (Int(row.rep_period), Int(row.time_block_start))
            push!(incoming[key], row.id)
        end

        # Process outgoing flows
        for row in DuckDB.query(connection, query_outgoing)
            key = (Int(row.rep_period), Int(row.time_block_start))
            push!(outgoing[key], row.id)
        end

        return (incoming, outgoing)
    end

    """
        get_storage_ids(connection, storage_asset, scenarios, periods) -> storage_level_ids

    Query storage level over_clustered_year IDs for a storage asset for each scenario and period block.
    Returns a dictionary indexed by (scenario, period).

    Optimized to use a single batched query instead of multiple queries.
    """
    function get_storage_ids(
        connection::DuckDB.DB,
        storage_asset::String,
        scenarios::UnitRange{Int},
        periods::UnitRange{Int},
    )
        storage_level_ids = Dict{Tuple{Int,Int},Int}()
        sizehint!(storage_level_ids, length(scenarios) * length(periods))

        # Batch query for all scenarios and periods
        query = """
            SELECT id, scenario, period_block_start
            FROM var_storage_level_over_clustered_year
            WHERE asset = '$storage_asset'
            ORDER BY scenario, period_block_start
        """

        for row in DuckDB.query(connection, query)
            key = (Int(row.scenario), Int(row.period_block_start))
            storage_level_ids[key] = row.id
        end

        return storage_level_ids
    end

    """
        get_inflow_value(profiles_rep_periods, rp, tb) -> Float64

    Extract inflow value for a given representative period and time block.
    Returns 0.0 if no matching profile is found.
    """
    function get_inflow_value(profiles_rep_periods::DataFrame, rp::Int, tb::Int)
        filtered = profiles_rep_periods[
            (profiles_rep_periods.rep_period.==rp).&(profiles_rep_periods.timestep.==tb),
            :value,
        ]
        return isempty(filtered) ? 0.0 : filtered[1]
    end

    """
        compute_flow_terms(flow, flow_ids, efficiency) -> JuMP.AffExpr

    Compute weighted flow term for charging or discharging.
    Returns zero if flow_ids is empty.
    """
    function compute_flow_terms(
        flow::Vector{JuMP.VariableRef},
        flow_ids::Vector{Int},
        efficiency::Float64,
    )
        isempty(flow_ids) && return JuMP.AffExpr(0.0)
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
        num_timesteps::Int,
        config::StorageConfig,
    )
        incoming_expr = JuMP.AffExpr(0.0)
        outgoing_expr = JuMP.AffExpr(0.0)
        total_inflows = 0.0

        # Precompute discharge efficiency inverse for better performance
        discharge_efficiency_inv = 1.0 / config.discharging_efficiency

        for rp in 1:num_rps
            weight = get(period_weight_map, (scenario, period, rp), 0.0)
            iszero(weight) && continue  # Skip zero-weight periods

            for tb in 1:num_timesteps
                # Compute weighted charging flows
                charging_flow = compute_flow_terms(
                    flow,
                    incoming_flow_ids[(rp, tb)],
                    config.charging_efficiency,
                )
                JuMP.add_to_expression!(incoming_expr, charging_flow, weight)

                # Compute weighted discharging flows
                discharging_flow =
                    compute_flow_terms(flow, outgoing_flow_ids[(rp, tb)], discharge_efficiency_inv)
                JuMP.add_to_expression!(outgoing_expr, discharging_flow, weight)

                # Aggregate weighted inflows
                profile_value = get_inflow_value(profiles_rep_periods, rp, tb)
                total_inflows += weight * profile_value * config.inflows
            end
        end

        return (incoming_expr, outgoing_expr, total_inflows)
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
    )
        # Precompute discharge efficiency inverse
        discharge_efficiency_inv = 1.0 / config.discharging_efficiency

        # Compute charging and discharging flows
        incoming_expr =
            compute_flow_terms(flow, incoming_flow_ids[(rp, tb)], config.charging_efficiency)
        outgoing_expr =
            compute_flow_terms(flow, outgoing_flow_ids[(rp, tb)], discharge_efficiency_inv)

        # Get inflows for this time block
        profile_value = get_inflow_value(profiles_rep_periods, rp, tb)
        total_inflows = profile_value * config.inflows

        return (incoming_expr, outgoing_expr, total_inflows)
    end

    """
        verify_constraint_balance(model, cons_name, id, expected_cons) -> Bool

    Helper function to verify that a constraint matches the expected form.
    Returns true if constraints are equal, false otherwise.
    """
    function verify_constraint_balance(
        model::JuMP.Model,
        cons_name::Symbol,
        id::Int,
        expected_cons,
    )::Bool
        observed_cons = _get_cons_object(model, cons_name)[id]
        return _is_constraint_equal(expected_cons, observed_cons)
    end

    """
        setup_test_problem(storage_asset, inflows_profile, num_timesteps, num_rps)

    Common setup function for creating and configuring test problems.
    Returns connection, energy_problem, flow, profiles, incoming_flow_ids, and outgoing_flow_ids.
    """
    function setup_test_problem(
        storage_asset::String,
        inflows_profile::Dict{Tuple{String,Int,Int},Vector{Float64}},
        num_timesteps::Int,
        num_rps::Int,
    )
        # Create and configure the test problem
        connection = create_storage_balance_problem(;
            inflows_profile = inflows_profile,
            num_timesteps = num_timesteps,
            num_rps = num_rps,
        )
        TEM.populate_with_defaults!(connection)
        energy_problem = TEM.EnergyProblem(connection)
        TEM.create_model!(energy_problem)

        # Extract model variables
        flow = energy_problem.variables[:flow].container

        # Get inflow profiles for this storage asset
        profiles = TulipaIO.get_table(connection, "profiles_rep_periods")
        profiles = filter(row -> occursin(storage_asset, row.profile_name), profiles)

        # Get flow IDs for charging and discharging
        incoming_flow_ids, outgoing_flow_ids =
            get_flow_ids(connection, storage_asset, num_rps, num_timesteps)

        return (connection, energy_problem, flow, profiles, incoming_flow_ids, outgoing_flow_ids)
    end
end

@testitem "Test non seasonal storage balance constraints" setup = [CommonSetup, StorageSetup] tags =
    [:unit, :validation, :fast] begin
    using DuckDB: DuckDB
    using JuMP: JuMP

    # Non-seasonal storage (intra-day/week) only depends on representative periods,
    # not on scenarios, so we test with a single scenario.

    # Test parameters
    storage_asset = "non_seasonal_storage"
    config = STORAGE_CONFIGS[storage_asset]
    milestone_year = 2030
    scenario = 1
    inflows_profile = Dict((storage_asset, milestone_year, scenario) => [1.0, 5.5, 10.0, 2.5])
    num_timesteps = 2
    num_rps = 2

    # Setup test problem with common helper
    connection, energy_problem, flow, profiles, incoming_flow_ids, outgoing_flow_ids =
        setup_test_problem(storage_asset, inflows_profile, num_timesteps, num_rps)

    # Extract storage level variable
    storage_level = energy_problem.variables[:storage_level_rep_period].container

    # Verify all expected constraints exist
    cons_name = :balance_storage_rep_period
    constraint_data = DuckDB.query(
        connection,
        "SELECT id, rep_period, time_block_start
         FROM cons_$cons_name
         WHERE asset = '$storage_asset'
         ORDER BY rep_period, time_block_start",
    )
    num_constraints = constraint_data |> collect |> length
    @test num_constraints == num_rps * num_timesteps

    # Test each constraint for proper formulation
    for row in constraint_data
        rp, tb, id = Int(row.rep_period), Int(row.time_block_start), row.id

        # Compute expected terms for this time block
        incoming_expr, outgoing_expr, total_inflows = compute_expected_terms_non_seasonal_storage(
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
                storage_level[id] - incoming_expr + outgoing_expr ==
                total_inflows + config.initial_storage_level
            )
        else
            # Subsequent time blocks: balance against previous time block
            JuMP.@build_constraint(
                storage_level[id] - storage_level[id-1] - incoming_expr + outgoing_expr ==
                total_inflows
            )
        end

        # Verify constraint matches expected form
        @test verify_constraint_balance(energy_problem.model, cons_name, id, expected_cons)
    end
end

@testitem "Test seasonal storage balance constraints - single scenario" setup =
    [CommonSetup, StorageSetup] tags = [:unit, :validation, :fast] begin
    using DuckDB: DuckDB
    using JuMP: JuMP

    # Seasonal storage aggregates across representative periods using weights.
    # This test uses a single scenario to verify the constraint formulation.

    # Test parameters
    storage_asset = "seasonal_storage"
    config = STORAGE_CONFIGS[storage_asset]
    milestone_year = 2030
    scenario = 1
    inflows_profile = Dict((storage_asset, milestone_year, scenario) => [1.0, 5.5, 10.0])
    periods = 1:length(inflows_profile[(storage_asset, milestone_year, scenario)])
    num_timesteps = 1
    num_rps = 2

    # Setup test problem with common helper
    connection, energy_problem, flow, profiles, incoming_flow_ids, outgoing_flow_ids =
        setup_test_problem(storage_asset, inflows_profile, num_timesteps, num_rps)

    # Extract storage level variable
    storage_level = energy_problem.variables[:storage_level_over_clustered_year].container

    # Build period-to-representative-period weight mapping
    rep_periods_mapping = TulipaIO.get_table(connection, "rep_periods_mapping")
    period_weight_map = Dict{Tuple{Int,Int,Int},Float64}(
        (scenario, row.period, row.rep_period) => get(row, :weight, 0.0) for
        row in eachrow(rep_periods_mapping)
    )

    # Verify all expected constraints exist
    cons_name = :balance_storage_over_clustered_year
    constraint_data = DuckDB.query(
        connection,
        "SELECT id
         FROM cons_$cons_name
         WHERE asset = '$storage_asset'",
    )
    num_constraints = constraint_data |> collect |> length
    @test num_constraints == length(periods)

    # Test each period's constraint
    for period in periods
        # Compute expected terms aggregated over all representative periods
        incoming_expr, outgoing_expr, total_inflows = compute_expected_terms_seasonal_storage(
            flow,
            incoming_flow_ids,
            outgoing_flow_ids,
            period_weight_map,
            profiles,
            scenario,
            period,
            num_rps,
            num_timesteps,
            config,
        )

        # Build expected constraint based on position in time series
        expected_cons = if period == 1
            # First period: balance includes initial storage level
            JuMP.@build_constraint(
                storage_level[period] - incoming_expr + outgoing_expr ==
                total_inflows + config.initial_storage_level
            )
        else
            # Subsequent periods: balance against previous period
            JuMP.@build_constraint(
                storage_level[period] - storage_level[period-1] - incoming_expr + outgoing_expr == total_inflows
            )
        end

        # Verify constraint matches expected form
        @test verify_constraint_balance(energy_problem.model, cons_name, period, expected_cons)
    end
end

@testitem "Test seasonal storage balance constraints - two scenarios" setup =
    [CommonSetup, StorageSetup] tags = [:unit, :validation, :fast] begin
    using DuckDB: DuckDB
    using JuMP: JuMP

    # Seasonal storage aggregates across representative periods using weights.
    # This test uses two scenarios to verify the constraint formulation for multiple scenarios.

    # Test parameters
    storage_asset = "seasonal_storage"
    config = STORAGE_CONFIGS[storage_asset]
    milestone_year = 2030
    inflows_profile = Dict(
        (storage_asset, milestone_year, 1) => [1.0, 5.5, 10.0],  # Scenario 1
        (storage_asset, milestone_year, 2) => [10.0, 5.5, 1.0],  # Scenario 2
    )
    periods = 1:length(inflows_profile[(storage_asset, milestone_year, 1)])
    scenarios = 1:2
    num_timesteps = 1
    num_rps = 2

    # Setup test problem with common helper
    connection, energy_problem, flow, profiles, incoming_flow_ids, outgoing_flow_ids =
        setup_test_problem(storage_asset, inflows_profile, num_timesteps, num_rps)

    # Extract storage level variable
    storage_level = energy_problem.variables[:storage_level_over_clustered_year].container

    # Build period-to-representative-period weight mapping
    rep_periods_mapping = TulipaIO.get_table(connection, "rep_periods_mapping")
    period_weight_map = Dict{Tuple{Int,Int,Int},Float64}(
        (row.scenario, row.period, row.rep_period) => get(row, :weight, 0.0) for
        row in eachrow(rep_periods_mapping)
    )

    # Get storage level variable IDs for all periods and scenarios
    storage_level_ids = get_storage_ids(connection, storage_asset, scenarios, periods)

    # Verify all expected constraints exist
    cons_name = :balance_storage_over_clustered_year
    constraint_data = DuckDB.query(
        connection,
        "SELECT id
         FROM cons_$cons_name
         WHERE asset = '$storage_asset'",
    )
    num_constraints = constraint_data |> collect |> length
    @test num_constraints == length(periods) * length(scenarios)

    # Test each scenario and period
    max_period = maximum(periods)
    for scenario in scenarios, period in periods
        # Compute expected terms aggregated over all representative periods
        incoming_expr, outgoing_expr, total_inflows = compute_expected_terms_seasonal_storage(
            flow,
            incoming_flow_ids,
            outgoing_flow_ids,
            period_weight_map,
            profiles,
            scenario,
            period,
            num_rps,
            num_timesteps,
            config,
        )

        # Get current and previous storage level IDs
        current_storage_id = storage_level_ids[(scenario, period)]

        # Build expected constraint based on position in time series
        expected_cons = if period == 1
            # First period: balance includes initial storage level
            JuMP.@build_constraint(
                storage_level[current_storage_id] - incoming_expr + outgoing_expr ==
                total_inflows + config.initial_storage_level
            )
        else
            # Subsequent periods: balance against previous period
            previous_storage_id = storage_level_ids[(scenario, period - 1)]
            JuMP.@build_constraint(
                storage_level[current_storage_id] - storage_level[previous_storage_id] -
                incoming_expr + outgoing_expr == total_inflows
            )
        end

        # Verify constraint matches expected form
        # Constraints are ordered by scenario and period
        constraint_id = max_period * (scenario - 1) + period
        @test verify_constraint_balance(
            energy_problem.model,
            cons_name,
            constraint_id,
            expected_cons,
        )
    end
end
