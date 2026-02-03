@testsnippet StorageSetup begin
    using DuckDB: DuckDB
    using TulipaBuilder: TulipaBuilder as TB
    using TulipaClustering: TulipaClustering as TC

    # Storage asset configuration data
    const STORAGE_CONFIGS = Dict{String,Dict{String,Union{Float64,Bool,Int}}}(
        "seasonal_storage" => Dict{String,Union{Float64,Bool,Int}}(
            "inflows" => 10.0,
            "is_seasonal" => true,
            "initial_units" => 1.0,
            "initial_storage_units" => 1.0,
            "storage_charging_efficiency" => 0.85,
            "storage_discharging_efficiency" => 0.8,
            "initial_storage_level" => 0.5,
            "capacity" => 1.0,
            "capacity_storage_energy" => 168.0,
        ),
        "non_seasonal_storage" => Dict{String,Union{Float64,Bool,Int}}(
            "inflows" => 3.5,
            "is_seasonal" => false,
            "initial_units" => 1.0,
            "initial_storage_units" => 1.0,
            "storage_charging_efficiency" => 0.9,
            "storage_discharging_efficiency" => 0.95,
            "initial_storage_level" => 0.25,
            "capacity" => 1.0,
            "capacity_storage_energy" => 4.0,
        ),
    )

    """
        create_storage_balance_problem(; inflows_profile=[1.0, 5.5, 10.0], period_duration=1, num_rps=2)

    Create a storage balance test problem with two storage assets (seasonal_storage and non_seasonal_storage).
    Returns the connection and energy_problem ready for constraint testing.
    """
    function create_storage_balance_problem(;
        inflows_profile::Dict{Tuple{String,Int},Vector{Float64}} = Dict(
            ("seasonal_storage", 2030) => [1.0, 5.5, 10.0],
        ),
        period_duration::Int = 1,
        num_rps::Int = 2,
    )
        # Create tulipa data structure
        tulipa = TB.TulipaData()

        # Add basic producer and consumer
        TB.add_asset!(tulipa, "generator", :producer)
        TB.add_asset!(tulipa, "consumer", :consumer)
        TB.add_flow!(tulipa, "generator", "consumer")

        # Add storage assets
        for (storage_name, config) in STORAGE_CONFIGS
            TB.add_asset!(
                tulipa,
                storage_name,
                :storage;
                storage_inflows = config["inflows"],
                is_seasonal = config["is_seasonal"],
                initial_units = config["initial_units"],
                initial_storage_units = config["initial_storage_units"],
                storage_charging_efficiency = config["storage_charging_efficiency"],
                storage_discharging_efficiency = config["storage_discharging_efficiency"],
                initial_storage_level = config["initial_storage_level"],
                capacity = config["capacity"],
                capacity_storage_energy = config["capacity_storage_energy"],
            )
            TB.add_flow!(tulipa, "consumer", storage_name)
            TB.add_flow!(tulipa, storage_name, "consumer")
            # Attach inflows profiles for this storage asset
            for ((asset, year), values) in inflows_profile
                if asset == storage_name
                    TB.attach_profile!(tulipa, storage_name, :inflows, year, values)
                end
            end
        end

        # Create connection and cluster
        connection = TB.create_connection(tulipa)
        TC.cluster!(
            connection,
            period_duration,
            num_rps;
            method = :convex_hull,
            weight_type = :convex,
            tol = 1e-6,
            weight_fitting_kwargs = Dict(:learning_rate => 0.001, :niters => 1000),
        )

        return connection
    end

    """
        get_flow_ids(connection, storage_asset, num_rps, period_duration)

    Get incoming and outgoing flow IDs for a storage asset across all representative periods.
    Returns (incoming_flow_ids, outgoing_flow_ids) dictionaries indexed by rep_period and time_block_start.
    """
    function get_flow_ids(
        connection::DuckDB.DB,
        storage_asset::String,
        num_rps::Int,
        period_duration::Int,
    )::Tuple{Dict{Tuple{Int,Int},Vector{Int}},Dict{Tuple{Int,Int},Vector{Int}}}
        incoming = Dict{Tuple{Int,Int},Vector{Int}}(
            (rp, tb) => Int[] for rp in 1:num_rps for tb in 1:period_duration
        )
        outgoing = Dict{Tuple{Int,Int},Vector{Int}}(
            (rp, tb) => Int[] for rp in 1:num_rps for tb in 1:period_duration
        )

        for rp in 1:num_rps
            for tb in 1:period_duration
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
        end
        return (incoming, outgoing)
    end

    """
        compute_expected_terms_seasonal_storage(
            flow,
            incoming_flow_ids,
            outgoing_flow_ids,
            map,
            profiles_rep_periods,
            period,
            num_rps,
            charging_eff,
            discharging_eff,
            base_inflows,
        )
    Compute the expected incoming, outgoing, and inflows terms for a given period.
    """
    function compute_expected_terms_seasonal_storage(
        flow::Vector{JuMP.VariableRef},
        incoming_flow_ids::Dict{Tuple{Int,Int},Vector{Int}},
        outgoing_flow_ids::Dict{Tuple{Int,Int},Vector{Int}},
        map::Dict{Tuple{Int,Int},Float64},
        profiles_rep_periods::DataFrame,
        period::Int,
        num_rps::Int,
        period_duration::Int,
        charging_eff::Float64,
        discharging_eff::Float64,
        base_inflows::Float64,
    )::Tuple{JuMP.AffExpr,JuMP.AffExpr,Float64}
        incoming = JuMP.AffExpr(0.0)
        outgoing = JuMP.AffExpr(0.0)
        inflows = 0.0

        for rp in 1:num_rps
            weight = get(map, (period, rp), 0.0)
            for tb in 1:period_duration
                # Incoming flows (charging)
                incoming +=
                    sum(flow[id] for id in incoming_flow_ids[(rp, tb)]) * weight * charging_eff

                # Outgoing flows (discharging)
                outgoing +=
                    sum(flow[id] for id in outgoing_flow_ids[(rp, tb)]) * weight / discharging_eff

                # Inflows
                rp_inflows = let
                    filtered = profiles_rep_periods[
                        (profiles_rep_periods.rep_period.==rp).&(profiles_rep_periods.timestep.==tb),
                        :value,
                    ]
                    isempty(filtered) ? 0.0 : filtered[1]
                end
                inflows += weight * rp_inflows * base_inflows
            end
        end

        return (incoming, outgoing, inflows)
    end

    """
        compute_expected_terms_non_seasonal_storage(
            flow,
            incoming_flow_ids,
            outgoing_flow_ids,
            profiles_rep_periods,
            num_rps,
            charging_eff,
            discharging_eff,
            base_inflows,
        )
    Compute the expected incoming, outgoing, and inflows terms for a given representative period.
    """
    function compute_expected_terms_non_seasonal_storage(
        flow::Vector{JuMP.VariableRef},
        incoming_flow_ids::Dict{Tuple{Int,Int},Vector{Int}},
        outgoing_flow_ids::Dict{Tuple{Int,Int},Vector{Int}},
        profiles_rep_periods::DataFrame,
        rp::Int,
        tb::Int,
        charging_eff::Float64,
        discharging_eff::Float64,
        base_inflows::Float64,
    )::Tuple{JuMP.AffExpr,JuMP.AffExpr,Float64}
        incoming = JuMP.AffExpr(0.0)
        outgoing = JuMP.AffExpr(0.0)
        inflows = 0.0

        # Incoming flows (charging)
        incoming = sum(flow[id] for id in incoming_flow_ids[(rp, tb)]) * charging_eff

        # Outgoing flows (discharging)
        outgoing = sum(flow[id] for id in outgoing_flow_ids[(rp, tb)]) / discharging_eff

        # Inflows
        rp_inflows = let
            filtered = profiles_rep_periods[
                (profiles_rep_periods.rep_period.==rp).&(profiles_rep_periods.timestep.==tb),
                :value,
            ]
            isempty(filtered) ? 0.0 : filtered[1]
        end
        inflows = rp_inflows * base_inflows

        return (incoming, outgoing, inflows)
    end
end

@testitem "Test non seasonal storage balance constraints" setup = [CommonSetup, StorageSetup] tags =
    [:unit, :validation, :fast] begin
    using DuckDB: DuckDB
    using JuMP: JuMP

    """
    Note: Non-seasonal storage (a.k.a. short-term storage, intra-day/week storage)
          does not depend on the set scenario. It only depends on the representative periods.
          Therefore, we only need to test it once (no need for multiple scenarios).
    """

    # Test storage balance for non_seasonal_storage
    storage_asset = "non_seasonal_storage"
    storage_config = STORAGE_CONFIGS[storage_asset]

    # Create the test problem for only one scenario in year
    year = 2030
    inflows_profile = Dict((storage_asset, year) => [1.0, 5.5, 10.0, 2.5])
    periods = 1:length(inflows_profile[(storage_asset, year)])
    period_duration = 2
    num_rps = 2
    connection = create_storage_balance_problem(;
        inflows_profile = inflows_profile,
        period_duration = period_duration,
        num_rps = num_rps,
    )

    # Populate defaults and create energy problem
    TEM.populate_with_defaults!(connection)
    energy_problem = TEM.EnergyProblem(connection)
    TEM.create_model!(energy_problem; model_file_name = joinpath(@__DIR__, "test_storage.lp"))

    # Extract variables and data
    flow = energy_problem.variables[:flow].container
    storage_level = energy_problem.variables[:storage_level_rep_period].container

    # Get inflow profiles by representative period
    profiles_rep_periods::DataFrame = TulipaIO.get_table(connection, "profiles_rep_periods")
    profiles_rep_periods =
        filter(row -> occursin(storage_asset, row.profile_name), profiles_rep_periods)

    # Get flow IDs for the storage asset
    incoming_flow_ids, outgoing_flow_ids =
        get_flow_ids(connection, storage_asset, num_rps, period_duration)

    # Verify constraint exists for all periods since we didn't define flexible temporal resolution data
    cons_name = :balance_storage_rep_period
    constraint_data = [row for row in DuckDB.query(
        connection,
        "SELECT id, rep_period, time_block_start
         FROM cons_$cons_name
         WHERE asset = '$storage_asset'
         ORDER BY rep_period, time_block_start",
    )]
    @test length(constraint_data) == num_rps * period_duration

    # Test each representative period's constraint per time block
    for row in constraint_data
        rp = Int(row.rep_period)
        tb = Int(row.time_block_start)
        id = row.id

        # Compute expected terms
        incoming, outgoing, inflows = compute_expected_terms_non_seasonal_storage(
            flow,
            incoming_flow_ids,
            outgoing_flow_ids,
            profiles_rep_periods,
            rp,
            tb,
            storage_config["storage_charging_efficiency"],
            storage_config["storage_discharging_efficiency"],
            storage_config["inflows"],
        )

        # Build expected constraint
        if tb == 1
            # First time block: includes initial storage level
            expected_cons = JuMP.@build_constraint(
                storage_level[id] - incoming + outgoing ==
                inflows + storage_config["initial_storage_level"]
            )
        else
            # Subsequent time blocks: balance against previous time block
            expected_cons = JuMP.@build_constraint(
                storage_level[id] - storage_level[id-1] - incoming + outgoing == inflows
            )
        end

        # Compare with actual constraint
        observed_cons = _get_cons_object(energy_problem.model, cons_name)[id]
        @test _is_constraint_equal(expected_cons, observed_cons)
    end
end

@testitem "Test seasonal storage balance constraints - single scenario" setup =
    [CommonSetup, StorageSetup] tags = [:unit, :validation, :fast] begin
    using DuckDB: DuckDB
    using JuMP: JuMP

    # Test storage balance for seasonal_storage
    storage_asset = "seasonal_storage"
    storage_config = STORAGE_CONFIGS[storage_asset]

    # Create the test problem for only one scenario
    year = 2030
    inflows_profile = Dict((storage_asset, year) => [1.0, 5.5, 10.0])
    periods = 1:length(inflows_profile[(storage_asset, year)])
    period_duration = 1
    num_rps = 2
    connection = create_storage_balance_problem(;
        inflows_profile = inflows_profile,
        period_duration = period_duration,
        num_rps = num_rps,
    )

    # Populate defaults and create energy problem
    TEM.populate_with_defaults!(connection)
    energy_problem = TEM.EnergyProblem(connection)
    TEM.create_model!(energy_problem; model_file_name = joinpath(@__DIR__, "test_storage.lp"))

    # Extract variables and data
    flow = energy_problem.variables[:flow].container
    storage_level = energy_problem.variables[:storage_level_over_clustered_year].container

    # Build period mapping: (period, rep_period) => weight
    rep_periods_mapping = TulipaIO.get_table(connection, "rep_periods_mapping")
    period_weight_map = Dict{Tuple{Int,Int},Float64}(
        (row.period, row.rep_period) => get(row, :weight, 0.0) for
        row in eachrow(rep_periods_mapping)
    )

    # Get inflow profiles by representative period and filter it by the storage_asset
    profiles_rep_periods::DataFrame = TulipaIO.get_table(connection, "profiles_rep_periods")
    profiles_rep_periods =
        filter(row -> occursin(storage_asset, row.profile_name), profiles_rep_periods)

    # Get flow IDs for the storage asset
    incoming_flow_ids, outgoing_flow_ids =
        get_flow_ids(connection, storage_asset, num_rps, period_duration)

    # Verify constraint exists for all periods since we didn't define flexible temporal resolution data
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
        # Compute expected terms
        incoming, outgoing, inflows_sum = compute_expected_terms_seasonal_storage(
            flow,
            incoming_flow_ids,
            outgoing_flow_ids,
            period_weight_map,
            profiles_rep_periods,
            period,
            num_rps,
            period_duration,
            storage_config["storage_charging_efficiency"],
            storage_config["storage_discharging_efficiency"],
            storage_config["inflows"],
        )

        # Build expected constraint
        if period == 1
            # First period: includes initial storage level
            expected_cons = JuMP.@build_constraint(
                storage_level[period] - incoming + outgoing ==
                inflows_sum + storage_config["initial_storage_level"]
            )
        else
            # Subsequent periods: balance against previous period
            expected_cons = JuMP.@build_constraint(
                storage_level[period] - storage_level[period-1] - incoming + outgoing ==
                inflows_sum
            )
        end

        # Compare with actual constraint
        observed_cons = _get_cons_object(energy_problem.model, cons_name)[period]
        @test _is_constraint_equal(expected_cons, observed_cons)
    end
end
