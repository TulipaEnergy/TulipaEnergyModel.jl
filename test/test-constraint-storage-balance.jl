@testitem "Test storage balance constraints - single scenario" setup = [CommonSetup] tags =
    [:unit, :validation, :fast] begin
    using DuckDB
    using JuMP
    using TulipaEnergyModel: TulipaEnergyModel as TEM
    using TulipaClustering: TulipaClustering as TC
    using TulipaBuilder: TulipaBuilder as TB

    # We create a simple tulipa problem with two storage assets
    tulipa = TB.TulipaData()

    storage_data = Dict(
        "storageA" => Dict(
            "inflows" => 10,
            "is_seasonal" => true,
            "initial_units" => 1,
            "initial_storage_units" => 1,
            "storage_charging_efficiency" => 0.85,
            "storage_discharging_efficiency" => 0.8,
            "initial_storage_level" => 0.5,
            "capacity" => 1,
            "capacity_storage_energy" => 168,
        ),
        "storageB" => Dict(
            "inflows" => 0.0,
            "is_seasonal" => false,
            "initial_units" => 1,
            "initial_storage_units" => 1,
            "storage_charging_efficiency" => 0.9,
            "storage_discharging_efficiency" => 0.95,
            "initial_storage_level" => 0.0,
            "capacity" => 1,
            "capacity_storage_energy" => 4,
        ),
    )
    TB.add_asset!(tulipa, "generator", :producer)
    TB.add_asset!(tulipa, "consumer", :consumer)
    TB.add_flow!(tulipa, "generator", "consumer")
    TB.add_flow!(tulipa, "consumer", "storageB")
    TB.add_flow!(tulipa, "storageB", "consumer")

    for storage_asset in ("storageA", "storageB")
        TB.add_asset!(
            tulipa,
            storage_asset,
            :storage;
            storage_inflows = storage_data[storage_asset]["inflows"],
            is_seasonal = storage_data[storage_asset]["is_seasonal"],
            initial_units = storage_data[storage_asset]["initial_units"],
            initial_storage_units = storage_data[storage_asset]["initial_storage_units"],
            storage_charging_efficiency = storage_data[storage_asset]["storage_charging_efficiency"],
            storage_discharging_efficiency = storage_data[storage_asset]["storage_discharging_efficiency"],
            initial_storage_level = storage_data[storage_asset]["initial_storage_level"],
            capacity = storage_data[storage_asset]["capacity"],
            capacity_storage_energy = storage_data[storage_asset]["capacity_storage_energy"],
        )
        TB.add_flow!(tulipa, "consumer", storage_asset)
        TB.add_flow!(tulipa, storage_asset, "consumer")
    end

    # Attach profile to storageA
    inflows_profile = [1; 5.5; 10]
    periods = 1:length(inflows_profile)
    TB.attach_profile!(tulipa, "storageA", :inflows, 2030, inflows_profile)

    connection = TB.create_connection(tulipa)

    # Cluster, populate_with_defaults, and create model
    period_duration = 1
    num_rps = 2
    clusters = TC.cluster!(
        connection,
        period_duration,
        num_rps;
        method = :convex_hull,
        weight_type = :convex,
        tol = 1e-6,
        weight_fitting_kwargs = Dict(:learning_rate => 0.001, :niters => 1000),
    )
    TEM.populate_with_defaults!(connection)
    energy_problem = TEM.EnergyProblem(connection)
    TEM.create_model!(energy_problem; model_file_name = joinpath(@__DIR__, "test_storage.lp"))

    # Test for the StorageA
    storage_asset = "storageA"
    flow = energy_problem.variables[:flow].container
    storage_level_over_clustered_year =
        energy_problem.variables[:storage_level_over_clustered_year].container
    rep_periods_mapping = TulipaIO.get_table(connection, "rep_periods_mapping")
    map = Dict(
        (row.period, row.rep_period) => get(row, :weight, 0.0) for
        row in eachrow(rep_periods_mapping)
    )
    profiles_rep_periods = TulipaIO.get_table(connection, "profiles_rep_periods")
    cons_name = :balance_storage_over_clustered_year

    incoming_flow_ids = Dict{Int32,Vector{Int32}}(rp => Int32[] for rp in 1:num_rps)
    outgoing_flow_ids = Dict{Int32,Vector{Int32}}(rp => Int32[] for rp in 1:num_rps)
    for rp in 1:num_rps
        incoming_flow_ids[rp] = [
            row.id for row in DuckDB.query(
                connection,
                "SELECT id FROM var_flow WHERE to_asset = '$storage_asset' AND rep_period = $rp",
            )
        ]
        outgoing_flow_ids[rp] = [
            row.id for row in DuckDB.query(
                connection,
                "SELECT id FROM var_flow WHERE from_asset = '$storage_asset' AND rep_period = $rp",
            )
        ]
    end

    cons_id = [row.id for row in DuckDB.query(
        connection,
        """
        SELECT id
        FROM cons_$cons_name
        WHERE asset = '$storage_asset'
        """,
    )]

    @test length(cons_id) == periods |> length

    for period in periods
        incoming = JuMP.AffExpr(0.0)
        outgoing = JuMP.AffExpr(0.0)
        inflows = 0.0
        for rp in 1:num_rps
            incoming +=
                sum(flow[id] for id in incoming_flow_ids[rp]) *
                get(map, (period, rp), 0.0) *
                storage_data[storage_asset]["storage_charging_efficiency"]
            outgoing +=
                sum(flow[id] for id in outgoing_flow_ids[rp]) * get(map, (period, rp), 0.0) /
                storage_data[storage_asset]["storage_discharging_efficiency"]
            inflows +=
                get(map, (period, rp), 0.0) *
                profiles_rep_periods[rp, :value] *
                storage_data[storage_asset]["inflows"]
        end
        @show period incoming outgoing inflows
        if period == 1
            expected_cons = JuMP.@build_constraint(
                storage_level_over_clustered_year[period] - incoming + outgoing ==
                inflows + storage_data[storage_asset]["initial_storage_level"]
            )
        else
            expected_cons = JuMP.@build_constraint(
                storage_level_over_clustered_year[period] -
                storage_level_over_clustered_year[period-1] - incoming + outgoing == inflows
            )
        end
        observed_cons = _get_cons_object(energy_problem.model, cons_name)[period]
        @test _is_constraint_equal(expected_cons, observed_cons)
    end
end
