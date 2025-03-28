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
        if haskey(row, :flow_coefficient_in_capacity_constraint)
            DuckDB.append(appender, row.flow_coefficient_in_capacity_constraint)
        end
        DuckDB.append(appender, s)
        DuckDB.append(appender, e)
        DuckDB.end_row(appender)
        s = e + 1
    end
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

"""
    create_unrolled_partition_table!(connection)

Create unrolled partitions tables from existing DuckDB tables, i.e., adds the time block start and end information.

## Input

The following tables are expected to exist in the `connection`, containing the
partition of some, or all, assets or flows, with their respective time information.

- `assets_rep_periods_partitions`
- `flows_rep_periods_partitions`
- `assets_timeframe_partitions`

## Output

The generated tables are the unrolled version of the tables above.
It transforms each row in (possibly) multiple rows.
The columns `specification` and `partition` are used to determine the time
blocks, and are replaced by columns `time_block_start` and `time_block_end`.

- `asset_time_resolution_rep_period`
- `flow_time_resolution_rep_period`
- `asset_time_resolution_over_clustered_year`

"""
function create_unrolled_partition_tables!(connection)
    DBInterface.execute(
        connection,
        "CREATE OR REPLACE TABLE t_explicit_assets_rep_periods_partitions AS
        SELECT
            asset.asset,
            rep_periods_data.year,
            rep_periods_data.rep_period,
            COALESCE(arpp.specification, 'uniform') AS specification,
            COALESCE(arpp.partition, '1') AS partition,
            rep_periods_data.num_timesteps,
        FROM asset
        CROSS JOIN rep_periods_data
        LEFT JOIN assets_rep_periods_partitions as arpp
            ON asset.asset = arpp.asset
            AND rep_periods_data.year = arpp.year
            AND rep_periods_data.rep_period = arpp.rep_period
        ORDER BY rep_periods_data.year, rep_periods_data.rep_period
        ",
    )

    DBInterface.execute(
        connection,
        "CREATE OR REPLACE TABLE t_explicit_flows_rep_periods_partitions AS
        SELECT
            flow.from_asset,
            flow.to_asset,
            rep_periods_data.year,
            rep_periods_data.rep_period,
            COALESCE(frpp.specification, 'uniform') AS specification,
            COALESCE(frpp.partition, '1') AS partition,
            flow_commission.efficiency,
            flow_commission.flow_coefficient_in_capacity_constraint,
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
            FROM flow_both
            GROUP BY
                from_asset, to_asset, milestone_year
        ) AS t
            ON flow.from_asset = t.from_asset
            AND flow.to_asset = t.to_asset
            AND rep_periods_data.year = t.milestone_year
        ORDER BY rep_periods_data.year, rep_periods_data.rep_period
        ",
    )

    DBInterface.execute(
        connection,
        "CREATE OR REPLACE TABLE asset_time_resolution_rep_period(
            asset STRING,
            year INT,
            rep_period INT,
            time_block_start INT,
            time_block_end INT
        )",
    )

    appender = DuckDB.Appender(connection, "asset_time_resolution_rep_period")
    for row in TulipaIO.get_table(Val(:raw), connection, "t_explicit_assets_rep_periods_partitions")
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
        "CREATE OR REPLACE TABLE flow_time_resolution_rep_period(
            from_asset STRING,
            to_asset STRING,
            year INT,
            rep_period INT,
            efficiency DOUBLE,
            flow_coefficient_in_capacity_constraint DOUBLE,
            time_block_start INT,
            time_block_end INT
        )",
    )

    appender = DuckDB.Appender(connection, "flow_time_resolution_rep_period")
    for row in TulipaIO.get_table(Val(:raw), connection, "t_explicit_flows_rep_periods_partitions")
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
        "CREATE OR REPLACE TABLE t_explicit_assets_timeframe_partitions AS
        WITH t_relevant_assets AS (
            SELECT DISTINCT
                asset.asset,
                timeframe_data.year,
            FROM asset
            CROSS JOIN timeframe_data
            WHERE asset.is_seasonal
        )
        SELECT
            t_relevant_assets.asset,
            t_relevant_assets.year,
            COALESCE(atp.specification, 'uniform') AS specification,
            COALESCE(atp.partition, '1') AS partition,
        FROM t_relevant_assets
        LEFT JOIN assets_timeframe_partitions AS atp
            ON t_relevant_assets.asset = atp.asset
            AND t_relevant_assets.year = atp.year
        ",
    )

    DBInterface.execute(
        connection,
        "CREATE OR REPLACE TABLE asset_time_resolution_over_clustered_year(
            asset STRING,
            year INT,
            period_block_start INT,
            period_block_end INT
        )",
    )

    appender = DuckDB.Appender(connection, "asset_time_resolution_over_clustered_year")
    for row in DuckDB.query(
        connection,
        "SELECT asset, sub.year, specification, partition, num_periods AS num_periods
        FROM t_explicit_assets_timeframe_partitions AS main
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

"""
create_merged_tables!(connection)

Create the internal tables of merged flows and assets time partitions to be used in the computation of the lowest and highest resolution tables.
The inputs tables are the flows table `flow_time_resolution_rep_period` and the assets table `asset_time_resolution_rep_period`.

All merged tables have the same columns: `asset`, `year`, `rep_period`, `time_block_start`, and `time_block_end`.
Given a "group" `(asset, year, rep_period)`, the table will have the list of all partitions that should be used to compute the resolution tables.
These are the output tables:

- `merged_in_flows`: Set `asset = from_asset` and drop `to_asset` from `flow_time_resolution_rep_period`.
- `merged_out_flows`: Set `asset = to_asset` and drop `from_asset` from `flow_time_resolution_rep_period`.
- `merged_assets_and_out_flows`: Union of `merged_out_flows` and `asset_time_resolution_rep_period`.
- `merged_all_flows`: Union (i.e., vertically concatenation) of the tables above.
- `merged_all`: Union of `merged_all_flows` and `asset_time_resolution_rep_period`.

This function is intended for internal use.
"""
function create_merged_tables!(connection)

    # Incoming flows
    DuckDB.execute(
        connection,
        "CREATE OR REPLACE TEMP TABLE merged_in_flows AS
        SELECT DISTINCT to_asset as asset, year, rep_period, time_block_start, time_block_end
        FROM flow_time_resolution_rep_period
        ",
    )

    # Outgoing flows
    DuckDB.execute(
        connection,
        "CREATE OR REPLACE TEMP TABLE merged_out_flows AS
        SELECT DISTINCT from_asset as asset, year, rep_period, time_block_start, time_block_end
        FROM flow_time_resolution_rep_period
        ",
    )

    # Union of all assets and outgoing flows
    DuckDB.execute(
        connection,
        "CREATE OR REPLACE TEMP TABLE merged_assets_and_out_flows AS
        SELECT DISTINCT asset, year, rep_period, time_block_start, time_block_end
        FROM asset_time_resolution_rep_period
        UNION
        FROM merged_out_flows
        ",
    )

    # Union of all incoming and outgoing flows
    DuckDB.execute(
        connection,
        "CREATE OR REPLACE TEMP TABLE merged_all_flows AS
        FROM merged_in_flows
        UNION
        FROM merged_out_flows
        ",
    )

    # Union of all assets, and incoming and outgoing flows
    DuckDB.execute(
        connection,
        "CREATE OR REPLACE TEMP TABLE merged_all AS
        SELECT DISTINCT asset, year, rep_period, time_block_start, time_block_end
        FROM asset_time_resolution_rep_period
        UNION
        FROM merged_all_flows
        ",
    )
    return
end

function create_flow_rep_periods_partitions_table!(connection)
    # This function calculates the flow representative period partitions,
    # using the information of the assets. This is a (complex) calculation and therefore not provided by the user.

    ```
               from_partition = partition of from_asset
               to_partition = partition of to_asset

               for each row:
               if from_ and to_partition exist
                   if flow is transport
                       flow_partition = max(from_partition, to_partition)
                   else (if flow not transport)
                       flow_partition = min(ditto)
                   end
               elseif from_ only exists
                   flow_partition = from_partition
               elseif to_ only exists
                   flow_partition = to_partition
               end

               ```
    return
end

function create_lowest_resolution_table!(connection)
    # These are generic tables to be used to create some variables and constraints
    # Following the lowest resolution merge strategy

    # The logic:
    # - merged table is ordered by groups (asset, year, rep_period), so every new group starts the same way
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

    for merged_table in ("merged_all_flows", "merged_all")
        table_name = replace(merged_table, "merged" => "t_lowest")
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
            "SELECT merged.* FROM $merged_table AS merged
            ORDER BY
                merged.asset,
                merged.year,
                merged.rep_period,
                merged.time_block_start
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

function create_highest_resolution_table!(connection)
    # These are generic tables to be used to create some variables and constraints
    # Following the highest resolution merge strategy

    # The logic:
    # - for each group (asset, year, rep_period) in merged
    # - keep all unique time_block_start
    # - create corresponing time_block_end

    for merged_table in
        ("merged_" * x for x in ("in_flows", "out_flows", "assets_and_out_flows", "all_flows"))
        table_name = replace(merged_table, "merged" => "t_highest")
        DuckDB.execute(
            connection,
            "CREATE OR REPLACE TABLE $table_name AS
            SELECT
                merged.asset,
                merged.year,
                merged.rep_period,
                merged.time_block_start,
                lead(merged.time_block_start - 1, 1, rep_periods_data.num_timesteps)
                    OVER (PARTITION BY merged.asset, merged.year, merged.rep_period ORDER BY merged.time_block_start)
                    AS time_block_end
            FROM (
                SELECT DISTINCT asset, year, rep_period, time_block_start
                FROM $merged_table
            ) AS merged
            LEFT JOIN rep_periods_data
                ON merged.year = rep_periods_data.year
                    AND merged.rep_period = rep_periods_data.rep_period
            ORDER BY merged.asset, merged.year, merged.rep_period, time_block_start
            ",
        )
    end
end
