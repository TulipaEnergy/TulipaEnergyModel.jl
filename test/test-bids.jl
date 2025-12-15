@testsnippet BidsSetup begin
    function create_bids_tables!(connection, bids)
        # Bids
        # bidding_window = 1:24
        lookup = Dict(
            (bid.customer, bid.exclusive_group, bid.profile_block) => bid_id for
            (bid_id, bid) in enumerate(bids)
        )
        bids_df = DataFrame([
            (;
                bid_id = lookup[bid.customer, bid.exclusive_group, bid.profile_block],
                asset = "bid$(lookup[bid.customer, bid.exclusive_group, bid.profile_block])",
                bid.customer,
                bid.exclusive_group,
                bid.profile_block,
                bid.price,
            ) for bid in bids
        ])
        bids_profiles_df = DataFrame([
            (;
                bid_id = lookup[bid.customer, bid.exclusive_group, bid.profile_block],
                profile_name = "bid_profiles-bid$(lookup[bid.customer, bid.exclusive_group, bid.profile_block])-demand",
                timestep = ti,
                quantity = qi,
            ) for bid in bids for (ti, qi) in zip(bid.timestep, bid.quantity)
        ])
        DuckDB.register_table(connection, bids_df, "bids")
        DuckDB.register_table(connection, bids_profiles_df, "bids_profiles")

        return nothing
    end
end

@testitem "Making bids" setup = [CommonSetup, BidsSetup] tags = [:case_study, :integration, :slow] begin
    # Normal input
    dir = joinpath(INPUT_FOLDER, "Rolling Horizon")
    connection = DBInterface.connect(DuckDB.DB)
    _read_csv_folder(connection, dir)

    sql(str) = DuckDB.query(connection, str)
    insert_into(table, what) = sql("INSERT INTO $table BY NAME ($what)")
    insert_into(table, columns, from) = insert_into(table, "SELECT $columns FROM $from")
    from_bids_insert_into(table, columns) = insert_into(table, columns, "bids")

    # Normal solution
    energy_problem = TulipaEnergyModel.run_scenario(connection; show_log = false)
    @test energy_problem.objective_value ≈ 410873.9 rtol = 1e-5

    # New connection
    close(connection)
    connection = DBInterface.connect(DuckDB.DB)
    _read_csv_folder(connection, dir)

    bid_blocks = [
        (
            customer = "A",
            exclusive_group = 1,
            profile_block = 1,
            timestep = 9:9,
            quantity = [10],
            price = 500.0,
        ),
        (
            customer = "A",
            exclusive_group = 2,
            profile_block = 1,
            timestep = 7:8,
            quantity = [70, 30],
            price = 1.5,
        ),
        (
            customer = "A",
            exclusive_group = 2,
            profile_block = 2,
            timestep = 7:8,
            quantity = [80, 20],
            price = 1.5,
        ),
        (
            customer = "B",
            exclusive_group = 3,
            profile_block = 1,
            timestep = 7:13,
            quantity = (1:7) .* (7:-1:1),
            price = 0.001,
        ),
    ]
    create_bids_tables!(connection, bid_blocks)

    # Modifications to make bids work
    year =
        [
            row.year for row in
            DuckDB.query(connection, "SELECT DISTINCT milestone_year AS year FROM asset_milestone")
        ] |> only
    timestep_window = only([
        row for row in DuckDB.query(
            connection,
            "SELECT MIN(timestep) AS timestep_start, MAX(timestep) AS timestep_end
            FROM profiles_rep_periods",
        )
    ])
    timestep_start = timestep_window.timestep_start
    timestep_end = timestep_window.timestep_end
    # asset = "'bid' || bid_id::VARCHAR AS asset"

    # Creating new assets to make this bid possible
    from_bids_insert_into(
        "asset",
        """asset,
        'consumer' AS type,
        1.0 AS capacity,
        '==' AS consumer_balance_sense,
        1.0 AS min_operating_point,
        true AS unit_commitment,
        true AS unit_commitment_integer,
        'basic' AS unit_commitment_method
        """,
    )

    milestone_year = "$year AS milestone_year"
    commission_year = "$year AS commission_year"

    from_bids_insert_into("asset_milestone", "asset, $milestone_year, 1.0 AS peak_demand")
    from_bids_insert_into("asset_commission", "asset, $commission_year")
    from_bids_insert_into(
        "asset_both",
        "asset, $commission_year, $milestone_year, 1.0 AS initial_units",
    )
    rep_period = "1 AS rep_period"
    specification = "'uniform' AS specification"
    partition = "'$(timestep_end - timestep_start + 1)' AS partition"
    # Creating assets_rep_periods_partitions if necessary
    DuckDB.query(
        connection,
        """CREATE TABLE IF NOT EXISTS assets_rep_periods_partitions
            (asset VARCHAR, year INTEGER, rep_period INTEGER, specification VARCHAR, partition VARCHAR);
        """,
    )
    from_bids_insert_into(
        "assets_rep_periods_partitions",
        "asset, $year AS year, $rep_period, $specification, $partition",
    )

    consumer_used_for_bids = only([
        row.asset for row in DuckDB.query(
            connection,
            "SELECT ANY_VALUE(asset) AS asset FROM asset WHERE type = 'consumer'",
        )
    ])
    from_asset = "'$consumer_used_for_bids' AS from_asset"
    to_asset = "asset AS to_asset"

    from_bids_insert_into("flow", "$from_asset, $to_asset")
    from_bids_insert_into(
        "flow_milestone",
        "$from_asset, $to_asset, $milestone_year, -bids.price AS operational_cost",
    )
    from_bids_insert_into("flow_commission", "$from_asset, $to_asset, $commission_year")

    # loops
    from_bids_insert_into("flow", "asset AS from_asset, asset AS to_asset")
    from_bids_insert_into(
        "flow_milestone",
        "asset AS from_asset, asset AS to_asset, $milestone_year",
    )
    from_bids_insert_into(
        "flow_commission",
        "asset AS from_asset, asset AS to_asset, $commission_year",
    )

    profile_name = "'bid_profiles-bid' || bid_id::VARCHAR || '-demand' AS profile_name"
    from_bids_insert_into(
        "assets_profiles",
        "asset, $commission_year, $profile_name, 'demand' AS profile_type",
    )

    insert_into(
        "profiles_rep_periods",
        """
        WITH cte_profile_names AS (SELECT DISTINCT profile_name FROM bids_profiles),
        cte_clean_profiles AS (
            SELECT
                profile_name,
                t AS timestep,
                0.0 AS value,
            FROM cte_profile_names
            CROSS JOIN generate_series(1, $(timestep_end - timestep_start + 1)) s(t)
        )
        SELECT
            cte_clean_profiles.profile_name,
            $year AS year,
            $rep_period,
            cte_clean_profiles.timestep,
            COALESCE(bids_profiles.quantity, 0.0) AS value,
        FROM cte_clean_profiles
        LEFT JOIN bids_profiles
            ON cte_clean_profiles.profile_name = bids_profiles.profile_name
            AND cte_clean_profiles.timestep = bids_profiles.timestep
        """,
    )

    TulipaEnergyModel.populate_with_defaults!(connection)
    energy_problem = TulipaEnergyModel.EnergyProblem(connection)
    TulipaEnergyModel.create_model!(energy_problem)

    for row in sql("""
        SELECT customer, exclusive_group, array_agg(var_units_on.id) AS units_on_ids
        FROM bids
        LEFT JOIN var_units_on
            ON 'bid' || bids.bid_id::VARCHAR = var_units_on.asset
        GROUP BY customer, exclusive_group
        """)
        units_on_ids = row.units_on_ids
        if length(units_on_ids) > 1
            var = energy_problem.variables[:units_on].container
            JuMP.@constraint(
                energy_problem.model,
                sum(var[id] for id in units_on_ids) <= 1,
                base_name = "exclusive_group[$(row.customer),$(row.exclusive_group)]"
            )
        end
    end

    TulipaEnergyModel.solve_model!(energy_problem)
    TulipaEnergyModel.save_solution!(energy_problem; compute_duals = true)

    println(DataFrame(sql("FROM var_units_on")))

    @test energy_problem.solved
    @test energy_problem.objective_value ≈ 410873.9 - 10 * 500 rtol = 1e-5
end
