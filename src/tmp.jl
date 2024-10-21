# This here are either because they don't have a place yet, or are necessary to help in the refactor

function _append_given_durations(appender, row, durations, ids...)
    s = 1
    for Δ in durations
        e = s + Δ - 1
        for id in ids
            DuckDB.append(appender, id)
        end
        DuckDB.append(appender, row.year)
        DuckDB.append(appender, row.rep_period)
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
    DBInterface.execute(
        connection,
        "CREATE OR REPLACE TABLE explicit_assets_rep_periods_partitions AS
        SELECT
            t_assets.name AS asset,
            t_assets.year AS year,
            t_rp.rep_period AS rep_period,
            COALESCE(t_partition.specification, 'uniform') AS specification,
            COALESCE(t_partition.partition, '1') AS partition,
            t_rp.num_timesteps,
        FROM assets_data AS t_assets
        LEFT JOIN assets_rep_periods_partitions as t_partition
            ON t_assets.name=t_partition.asset
                AND t_assets.year=t_partition.year
            LEFT JOIN rep_periods_data as t_rp
                ON t_rp.year=t_assets.year
        ORDER BY year, rep_period
        ",
    )

    DBInterface.execute(
        connection,
        "CREATE OR REPLACE TABLE explicit_flows_rep_periods_partitions AS
        SELECT
            t_flows.from_asset,
            t_flows.to_asset,
            t_flows.year AS year,
            t_rp.rep_period AS rep_period,
            COALESCE(t_partition.specification, 'uniform') AS specification,
            COALESCE(t_partition.partition, '1') AS partition,
            t_rp.num_timesteps,
        FROM flows_data AS t_flows
        LEFT JOIN flows_rep_periods_partitions as t_partition
            ON t_flows.from_asset=t_partition.from_asset
                AND t_flows.to_asset=t_partition.to_asset
                AND t_flows.year=t_partition.year
            LEFT JOIN rep_periods_data as t_rp
                ON t_rp.year=t_flows.year
        ORDER BY year, rep_period
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
            step = Meta.parse(row.partition)
            durations = fill(step, div(row.num_timesteps, step))
        elseif row.specification == "explicit"
            durations = Meta.parse.(split(row.partition, ";"))
        elseif row.specification == "math"
            atoms = split(row.partition, "+")
            durations = vcat([
                begin
                    r, d = Meta.parse.(split(atom, "x"))
                    fill(d, r)
                end for atom in atoms
            ]...)
        else
            error("Row specification '$(row.specification)' is not valid")
        end
        _append_given_durations(appender, row, durations, row.asset)
    end
    DuckDB.close(appender)

    DBInterface.execute(
        connection,
        "CREATE OR REPLACE TABLE flow_time_resolution(
            from_asset STRING,
            to_asset STRING,
            year INT,
            rep_period INT,
            time_block_start INT,
            time_block_end INT
        )",
    )

    appender = DuckDB.Appender(connection, "flow_time_resolution")
    for row in TulipaIO.get_table(Val(:raw), connection, "explicit_flows_rep_periods_partitions")
        durations = if row.specification == "uniform"
            step = Meta.parse(row.partition)
            durations = fill(step, div(row.num_timesteps, step))
        elseif row.specification == "explicit"
            durations = Meta.parse.(split(row.partition, ";"))
        elseif row.specification == "math"
            atoms = split(row.partition, "+")
            durations = vcat([
                begin
                    r, d = Meta.parse.(split(atom, "x"))
                    fill(d, r)
                end for atom in atoms
            ]...)
        else
            error("Row specification '$(row.specification)' is not valid")
        end
        _append_given_durations(appender, row, durations, row.from_asset, row.to_asset)
    end
    DuckDB.close(appender)
end
