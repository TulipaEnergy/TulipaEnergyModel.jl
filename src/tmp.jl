# This here are either because they don't have a place yet, or are necessary to help in the refactor

function _append_given_durations(appender, row, durations)
    s = 1
    for Δ in durations
        e = s + Δ - 1
        if haskey(row, :asset)
            DuckDB.append(appender, row.asset)
        else
            DuckDB.append(appender, row.from_asset)
            DuckDB.append(appender, row.to_asset)
        end
        DuckDB.append(appender, row.year)
        if haskey(row, :rep_period)
            DuckDB.append(appender, row.rep_period)
        end
        if haskey(row, :efficiency)
            DuckDB.append(appender, row.efficiency)
        end
        DuckDB.append(appender, s)
        DuckDB.append(appender, e)
        DuckDB.end_row(appender)
        s = e + 1
    end
    return
end

"""
    tmp_create_partition_tables(connection)

Create the unrolled partition tables using only tables.

The table `explicit_assets_rep_periods_partitions` is the explicit version of
`assets_rep_periods_partitions`, i.e., it adds the rows not defined in that
table by setting the specification to 'uniform' and the partition to '1'.

The table `asset_time_resolution` is the unrolled version of the table above,
i.e., it takes the specification and partition and expands into a series of
time blocks. The columns `time_block_start` and `time_block_end` replace the
`specification` and `partition` columns.

Similarly, `flow` tables are created as well.
"""
function tmp_create_partition_tables(connection)
    # DISTINCT is required because without commission year, it can be repeated
    DBInterface.execute(
        connection,
        "CREATE OR REPLACE TABLE explicit_assets_rep_periods_partitions AS
        SELECT
            asset.asset,
            rep_periods_data.year,
            rep_periods_data.rep_period,
            COALESCE(arpp.specification, 'uniform') AS specification,
            COALESCE(arpp.partition, '1') AS partition,
            rep_periods_data.num_timesteps,
        FROM asset
        CROSS JOIN rep_periods_data
        LEFT JOIN asset_commission
            ON asset.asset = asset_commission.asset
            AND rep_periods_data.year = asset_commission.commission_year
        LEFT JOIN assets_rep_periods_partitions as arpp
            ON asset.asset = arpp.asset
            AND rep_periods_data.year = arpp.year
            AND rep_periods_data.rep_period = arpp.rep_period
        LEFT JOIN (
            SELECT
                asset,
                milestone_year,
                MIN(active) AS active,
            FROM asset_both
            GROUP BY
                asset, milestone_year
        ) AS t
            ON asset.asset = t.asset
            AND rep_periods_data.year = t.milestone_year
        WHERE
            t.active = true
        ORDER BY rep_periods_data.year, rep_periods_data.rep_period
        ",
    )

    DBInterface.execute(
        connection,
        "CREATE OR REPLACE TABLE explicit_flows_rep_periods_partitions AS
        SELECT
            flow.from_asset,
            flow.to_asset,
            rep_periods_data.year,
            rep_periods_data.rep_period,
            COALESCE(frpp.specification, 'uniform') AS specification,
            COALESCE(frpp.partition, '1') AS partition,
            flow_commission.efficiency,
            rep_periods_data.num_timesteps,
        FROM flow
        CROSS JOIN rep_periods_data
        LEFT JOIN flow_commission
            ON flow.from_asset = flow_commission.from_asset
            AND flow.to_asset = flow_commission.to_asset
            AND rep_periods_data.year = flow_commission.commission_year
        LEFT JOIN flows_rep_periods_partitions as frpp
            ON flow.from_asset = frpp.from_asset
            AND flow.to_asset = frpp.to_asset
            AND rep_periods_data.year = frpp.year
            AND rep_periods_data.rep_period = frpp.rep_period
        LEFT JOIN (
            SELECT
                from_asset,
                to_asset,
                milestone_year,
                MIN(active) AS active,
            FROM flow_both
            GROUP BY
                from_asset, to_asset, milestone_year
        ) AS t
            ON flow.from_asset = t.from_asset
            AND flow.to_asset = t.to_asset
            AND rep_periods_data.year = t.milestone_year
        WHERE
            t.active = true
        ORDER BY rep_periods_data.year, rep_periods_data.rep_period
        ",
    )

    DBInterface.execute(
        connection,
        "CREATE OR REPLACE TABLE asset_time_resolution(
            asset STRING,
            year INT,
            rep_period INT,
            time_block_start INT,
            time_block_end INT
        )",
    )

    appender = DuckDB.Appender(connection, "asset_time_resolution")
    for row in TulipaIO.get_table(Val(:raw), connection, "explicit_assets_rep_periods_partitions")
        durations = if row.specification == "uniform"
            step = parse(Int, row.partition)
            durations = Iterators.repeated(step, div(row.num_timesteps, step))
        elseif row.specification == "explicit"
            durations = parse.(Int, split(row.partition, ";"))
        elseif row.specification == "math"
            atoms = split(row.partition, "+")
            durations =
                (
                    begin
                        r, d = parse.(Int, split(atom, "x"))
                        Iterators.repeated(d, r)
                    end for atom in atoms
                ) |> Iterators.flatten
        else
            error("Row specification '$(row.specification)' is not valid")
        end
        _append_given_durations(appender, row, durations)
    end
    DuckDB.close(appender)

    DBInterface.execute(
        connection,
        "CREATE OR REPLACE TABLE flow_time_resolution(
            from_asset STRING,
            to_asset STRING,
            year INT,
            rep_period INT,
            efficiency DOUBLE,
            time_block_start INT,
            time_block_end INT
        )",
    )

    appender = DuckDB.Appender(connection, "flow_time_resolution")
    for row in TulipaIO.get_table(Val(:raw), connection, "explicit_flows_rep_periods_partitions")
        durations = if row.specification == "uniform"
            step = parse(Int, row.partition)
            durations = Iterators.repeated(step, div(row.num_timesteps, step))
        elseif row.specification == "explicit"
            durations = parse.(Int, split(row.partition, ";"))
        elseif row.specification == "math"
            atoms = split(row.partition, "+")
            durations =
                (
                    begin
                        r, d = parse.(Int, split(atom, "x"))
                        Iterators.repeated(d, r)
                    end for atom in atoms
                ) |> Iterators.flatten
        else
            error("Row specification '$(row.specification)' is not valid")
        end
        _append_given_durations(appender, row, durations)
    end
    DuckDB.close(appender)

    DBInterface.execute(
        connection,
        "CREATE OR REPLACE TABLE explicit_assets_timeframe_partitions AS
        SELECT
            asset.asset,
            asset_commission.commission_year AS year,
            COALESCE(atp.specification, 'uniform') AS specification,
            COALESCE(atp.partition, '1') AS partition,
        FROM asset AS asset
        LEFT JOIN asset_commission
            ON asset.asset = asset_commission.asset
        LEFT JOIN assets_timeframe_partitions AS atp
            ON asset.asset = atp.asset
            AND asset_commission.commission_year = atp.year
        WHERE
            asset.is_seasonal
        ",
    )

    DBInterface.execute(
        connection,
        "CREATE OR REPLACE TABLE asset_timeframe_time_resolution(
            asset STRING,
            year INT,
            period_block_start INT,
            period_block_end INT
        )",
    )

    appender = DuckDB.Appender(connection, "asset_timeframe_time_resolution")
    for row in DuckDB.query(
        connection,
        "SELECT asset, sub.year, specification, partition, num_periods AS num_periods
        FROM explicit_assets_timeframe_partitions AS main
        LEFT JOIN (
            SELECT year, MAX(period) AS num_periods
            FROM timeframe_data
            GROUP BY year
        ) AS sub
            ON main.year = sub.year
        ",
    )
        durations = if row.specification == "uniform"
            step = parse(Int, row.partition)
            durations = Iterators.repeated(step, div(row.num_periods, step))
        elseif row.specification == "explicit"
            durations = parse.(Int, split(row.partition, ";"))
        elseif row.specification == "math"
            atoms = split(row.partition, "+")
            durations =
                (
                    begin
                        r, d = parse.(Int, split(atom, "x"))
                        Iterators.repeated(d, r)
                    end for atom in atoms
                ) |> Iterators.flatten
        else
            error("Row specification '$(row.specification)' is not valid")
        end
        _append_given_durations(appender, row, durations)
    end
    DuckDB.close(appender)
    return
end

function tmp_create_union_tables(connection)
    # These are equivalent to the partitions in time-resolution.jl
    # But computed in a more general context to be used by variables as well

    # Incoming flows
    DuckDB.execute(
        connection,
        "CREATE OR REPLACE TEMP TABLE t_union_in_flows AS
        SELECT DISTINCT to_asset as asset, year, rep_period, time_block_start, time_block_end
        FROM flow_time_resolution
        ",
    )

    # Outgoing flows
    DuckDB.execute(
        connection,
        "CREATE OR REPLACE TEMP TABLE t_union_out_flows AS
        SELECT DISTINCT from_asset as asset, year, rep_period, time_block_start, time_block_end
        FROM flow_time_resolution
        ",
    )

    # Union of all assets and outgoing flows
    DuckDB.execute(
        connection,
        "CREATE OR REPLACE TEMP TABLE t_union_assets_and_out_flows AS
        SELECT DISTINCT asset, year, rep_period, time_block_start, time_block_end
        FROM asset_time_resolution
        UNION
        FROM t_union_out_flows
        ",
    )

    # Union of all incoming and outgoing flows
    DuckDB.execute(
        connection,
        "CREATE OR REPLACE TEMP TABLE t_union_all_flows AS
        FROM t_union_in_flows
        UNION
        FROM t_union_out_flows
        ",
    )

    # Union of all assets, and incoming and outgoing flows
    DuckDB.execute(
        connection,
        "CREATE OR REPLACE TEMP TABLE t_union_all AS
        SELECT DISTINCT asset, year, rep_period, time_block_start, time_block_end
        FROM asset_time_resolution
        UNION
        FROM t_union_all_flows
        ",
    )
    return
end

function _append_lowest_helper(appender, group, s, e)
    for x in group
        DuckDB.append(appender, x)
    end
    DuckDB.append(appender, s)
    DuckDB.append(appender, e)
    DuckDB.end_row(appender)
    return
end

function tmp_create_lowest_resolution_table(connection)
    # These are generic tables to be used to create some variables and constraints
    # Following the lowest resolution merge strategy

    # The logic:
    # - t_union is ordered by groups (asset, year, rep_period), so every new group starts the same way
    # - Inside a group, time blocks (TBs) are ordered by time_block_start, so the
    #   first row of every group starts at time_block_start = 1
    # - The objective of the lowest resolution is to iteratively find the
    #   smallest interval [s, e] that covers all blocks that (i) haven't been
    #   covered yet; and (ii) start at s or earlier.
    # - We start with an interval [1, e], then use use s = e + 1 for the next intervals
    # - To cover all blocks, we use e as the largest time_block_end of the relevant blocks
    # - Since the TBs are in order, we can simply loop over them until we find
    #   the first that starts later than s. That will be the beginning of a new TB

    # Example:
    # Consider a group with two assets/flows with the following time resolutions:
    #
    # 1: 1:3 4:6 7:9 10:12
    # 2: 1:2 3:7 8:8 9:11 12:12
    #
    # The expected lowest resolution is: 1:3 4:7 8:9 10:12
    #
    # This will be translated into the following rows (TBS ordered, not
    # necessarily TBE ordered), and ROW is the row number only for our example
    #
    # ROW TBS  TBE
    #   1   1    3
    #   2   1    2
    #   3   3    7
    #   4   4    6
    #   5   7    9
    #   6   8    8
    #   7   9   11
    #   8  10   12
    #   9  12   12
    #
    # Here's how the algorithm behaves:
    #
    # - BEGINNING OF GROUP, set s = 1, e = 0
    # - ROW 1, TB =  [1,  3]: TBS = 1 ≤ 1 = s, so e = max(e, TBE) = max(0, 3) = 3
    # - ROW 2, TB =  [1,  2]: TBS = 1 ≤ 1 = s, so e = max(e, TBE) = max(3, 2) = 3
    # - ROW 3, TB =  [3,  7]: TBS = 3 > 1 = s, so the first block is created: [s, e] = [1, 3].
    #       Start a new block with s = 3 + 1 = 4 and e = TBE = 7
    # - ROW 4, TB =  [4,  6]: TBS = 4 ≤ 4 = s, so e = max(e, TBE) = max(7, 6) = 7
    # - ROW 5, TB =  [7,  9]: TBS = 7 > 4 = s, so the second block is created: [s, e] = [4, 7].
    #       Start a new block with s = 7 + 1 = 8 and e = TBE = 9
    # - ROW 6, TB =  [8,  8]: TBS = 8 ≤ 8 = s, so e = max(e, TBE) = max(9, 8) = 9
    # - ROW 7, TB =  [9, 11]: TBS = 9 > 8 = s, so the third block is created: [s, e] = [8, 9].
    #       Start a new block with s = 9 + 1 = 10 and e = TBE = 11
    # - ROW 8, TB = [10, 12]: TBS = 10 ≤ 10 = s, so e = max(e, TBE) = max(11, 12) = 12
    # - ROW 9, TB = [12, 12]: TBS = 12 > 10 = s, so the fourth block is created: [s, e] = [10, 12].
    #       Start a new block with s = 12 + 1 = 13 and e = TBE = 12
    # - END OF GROUP: Is 1 ≤ s ≤ e? No, so this is not a valid block

    for union_table in ("t_union_all_flows", "t_union_all")
        table_name = replace(union_table, "t_union" => "t_lowest")
        DuckDB.execute(
            connection,
            "CREATE OR REPLACE TABLE $table_name(
                asset STRING,
                year INT,
                rep_period INT,
                time_block_start INT,
                time_block_end INT
            )",
        )
        appender = DuckDB.Appender(connection, table_name)
        # Dummy starting values
        s = 0
        e_candidate = 0
        current_group = ("", 0, 0)
        @timeit to "append $table_name rows" for row in DuckDB.query(
            connection,
            "SELECT t_union.* FROM $union_table AS t_union
            LEFT JOIN asset_both
                ON asset_both.asset = t_union.asset
                AND asset_both.milestone_year = t_union.year
                AND asset_both.commission_year = t_union.year
            WHERE asset_both.active = true
            ORDER BY
                t_union.asset,
                t_union.year,
                t_union.rep_period,
                t_union.time_block_start
            ",
        )
            if (row.asset, row.year, row.rep_period) != current_group
                # New group, create the last entry
                # Except for the initial case and when it was already added
                if s != 0 && s <= e_candidate
                    _append_lowest_helper(appender, current_group, s, e_candidate)
                end
                # Start of a new group
                current_group = (row.asset, row.year, row.rep_period)
                e_candidate = row.time_block_end
                s = 1
            end
            if row.time_block_start > s
                # Since it's ordered, we ran out of candidates, so this marks the beginning of a new section
                # Then, let's append and update
                _append_lowest_helper(appender, current_group, s, e_candidate)
                s = e_candidate + 1
                e_candidate = row.time_block_end
            else
                # This row has a candidate
                e_candidate = max(e_candidate, row.time_block_end)
            end
        end
        # Add the last entry
        if s > 0 && s <= e_candidate # Being safe
            _append_lowest_helper(appender, current_group, s, e_candidate)
        end
        DuckDB.close(appender)
    end
end

function tmp_create_highest_resolution_table(connection)
    # These are generic tables to be used to create some variables and constraints
    # Following the highest resolution merge strategy

    # The logic:
    # - for each group (asset, year, rep_period) in t_union
    # - keep all unique time_block_start
    # - create corresponing time_block_end

    # filtering by active
    for union_table in
        ("t_union_" * x for x in ("in_flows", "out_flows", "assets_and_out_flows", "all_flows"))
        table_name = replace(union_table, "t_union" => "t_highest")
        DuckDB.execute(
            connection,
            "CREATE OR REPLACE TABLE $table_name AS
            SELECT
                t_union.asset,
                t_union.year,
                t_union.rep_period,
                t_union.time_block_start,
                lead(t_union.time_block_start - 1, 1, rep_periods_data.num_timesteps)
                    OVER (PARTITION BY t_union.asset, t_union.year, t_union.rep_period ORDER BY t_union.time_block_start)
                    AS time_block_end
            FROM (
                SELECT DISTINCT asset, year, rep_period, time_block_start
                FROM $union_table
            ) AS t_union
            LEFT JOIN asset_both
                ON asset_both.asset = t_union.asset
                AND asset_both.milestone_year = t_union.year
                AND asset_both.commission_year = t_union.year
            LEFT JOIN rep_periods_data
                ON t_union.year = rep_periods_data.year
                    AND t_union.rep_period = rep_periods_data.rep_period
            WHERE asset_both.active = true
            ORDER BY t_union.asset, t_union.year, t_union.rep_period, time_block_start
            ",
        )
    end
end

"""
    connection, ep = tmp_example_of_flow_expression_problem()
"""
function tmp_example_of_flow_expression_problem()
    connection = DBInterface.connect(DuckDB.DB)
    schemas = TulipaEnergyModel.schema_per_table_name
    TulipaIO.read_csv_folder(connection, "test/inputs/Norse"; schemas)
    ep = EnergyProblem(connection)
    create_model!(ep)

    @info """# Example of flow expression problem

    ref: see $(@__FILE__):$(@__LINE__)

    # TODO: This is outdated
    The desired incoming and outgoing flows are:
    - ep.dataframes[:highest_in_out].incoming_flow
    - ep.dataframes[:highest_in_out].outgoing_flow

    The DuckDB relevant tables (created in this file) are
    - `asset_time_resolution`: Each asset and their unrolled time partitions
    - `flow_time_resolution`: Each flow and their unrolled time partitions
      Note: This is the equivalent to `ep.dataframes[:flows]`.
    - `cons_indices_highest_in_out`: The indices of the balance constraints.

    Objectives:
    - For each row in `cons_indices_highest_in_out`, find all incoming/outgoing
      flows that **match** (asset,year,rep_period) and with intersecting time
      block
    - Find a way to store this information to use when creating the model in a
      way that doesn't slow down when creating constraints/expressions in JuMP.
      This normally implies not having conditionals on the expresion/constraints.
      See, e.g., https://jump.dev/JuMP.jl/stable/tutorials/getting_started/sum_if/
    """

    return connection, ep
end
