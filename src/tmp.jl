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
        FROM assets_timeframe_partitions AS main
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
end

function tmp_create_union_tables(connection)
    # These are equivalent to the partitions in time-resolution.jl
    # But computed in a more general context to be used by variables as well

    # Union of all incoming and outgoing flows
    DuckDB.execute(
        connection,
        "CREATE OR REPLACE TEMP TABLE t_union_all_flows AS
        SELECT from_asset as asset, year, rep_period, time_block_start, time_block_end
        FROM flow_time_resolution
        UNION
        SELECT to_asset as asset, year, rep_period, time_block_start, time_block_end
        FROM flow_time_resolution
        ",
    )

    # Union of all assets, and incoming and outgoing flows
    DuckDB.execute(
        connection,
        "CREATE OR REPLACE TEMP TABLE t_union_all AS
        SELECT asset, year, rep_period, time_block_start, time_block_end
        FROM asset_time_resolution
        UNION
        SELECT asset, year, rep_period, time_block_start, time_block_end
        FROM t_union_all_flows
        ",
    )
end

function _append_lowest_helper(appender, group, s, e)
    for x in group
        DuckDB.append(appender, x)
    end
    DuckDB.append(appender, s)
    DuckDB.append(appender, e)
    DuckDB.end_row(appender)
end

function tmp_create_lowest_resolution_table(connection)
    # These are generic tables to be used to create some variables and constraints

    # The logic:
    # - t_union has groups in order, then s:e ordered by s increasing and e decreasing
    # - in a group (asset, year, rep_period) we can take the first range then
    # - continue in the sequence selecting the next largest e

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
        s = 0
        e_candidate = 0
        current_group = ("", 0, 0)
        @timeit to "append $table_name rows" for row in DuckDB.query(
            connection,
            "SELECT * FROM $union_table
            ORDER BY asset, year, rep_period, time_block_start, time_block_end DESC
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

function tmp_create_constraints_indices(connection)
    # Create a list of all (asset, year, rp) and also data used in filtering
    DBInterface.execute(
        connection,
        "CREATE OR REPLACE TABLE t_cons_indices AS
        SELECT DISTINCT
            asset_both.asset as asset,
            asset_both.milestone_year as year,
            rep_periods_data.rep_period,
            asset.type,
            rep_periods_data.num_timesteps,
            asset.unit_commitment,
        FROM asset_both
        LEFT JOIN asset
            ON asset_both.asset=asset.asset
        LEFT JOIN rep_periods_data
            ON asset_both.milestone_year=rep_periods_data.year
        WHERE asset_both.active=true
        ORDER BY asset_both.milestone_year, rep_periods_data.rep_period
        ",
    )

    # -- The previous attempt used
    # The idea below is to find all unique time_block_start values because
    # this is uses strategy 'highest'. By ordering them, and making
    # time_block_end[i] = time_block_start[i+1] - 1, we have all ranges.
    # We use the `lead` function from SQL to get `time_block_start[i+1]`
    # and row.num_timesteps is the maximum value for when i+1 > length
    #
    # The query below is trying to replace the following constraints_partitions example:
    #= (
            name = :highest_in_out,
            partitions = _allflows,
            strategy = :highest,
            asset_filter = (a, y) -> graph[a].type in ["hub", "consumer"],
        ),
    =#
    # The **highest** strategy is obtained simply by computing the union of all
    # time_block_starts, since it consists of "all breakpoints".
    # The time_block_end is computed a posteriori using the next time_block_start.
    # The query below will use the WINDOW FUNCTION `lead` to compute the time
    # block end.
    # This query uses the assets, incoming flows and outgoing flows to compute partitions
    # This will be useful when we have other `partitions` instead of `_allflows`
    # SELECT asset, year, rep_period, time_block_start
    # FROM asset_time_resolution
    # UNION
    DuckDB.execute(
        connection,
        "CREATE OR REPLACE TABLE cons_indices_highest_in_out AS
        SELECT
            main.asset,
            main.year,
            main.rep_period,
            COALESCE(sub.time_block_start, 1) AS time_block_start,
            lead(sub.time_block_start - 1, 1, main.num_timesteps)
                OVER (PARTITION BY main.asset, main.year, main.rep_period ORDER BY time_block_start)
                AS time_block_end,
        FROM t_cons_indices AS main
        LEFT JOIN (
            SELECT to_asset as asset, year, rep_period, time_block_start
            FROM flow_time_resolution
            UNION
            SELECT from_asset as asset, year, rep_period, time_block_start
            FROM flow_time_resolution
        ) AS sub
            ON main.asset=sub.asset
                AND main.year=sub.year
                AND main.rep_period=sub.rep_period
        WHERE main.type in ('hub', 'consumer')
        ",
    )

    # This follows the same implementation as highest_in_out above, but using
    # only the incoming flows.
    #
    # The query below is trying to replace the following constraints_partitions example:
    #= (
    #     name = :highest_in,
    #     partitions = _inflows,
    #     strategy = :highest,
    #     asset_filter = (a, y) -> graph[a].type in ["storage"],
    # ),
    =#
    DuckDB.execute(
        connection,
        "CREATE OR REPLACE TABLE cons_indices_highest_in AS
        SELECT
            main.asset,
            main.year,
            main.rep_period,
            COALESCE(sub.time_block_start, 1) AS time_block_start,
            lead(sub.time_block_start - 1, 1, main.num_timesteps)
                OVER (PARTITION BY main.asset, main.year, main.rep_period ORDER BY time_block_start)
                AS time_block_end,
        FROM t_cons_indices AS main
        LEFT JOIN (
            SELECT to_asset as asset, year, rep_period, time_block_start
            FROM flow_time_resolution
        ) AS sub
            ON main.asset=sub.asset
                AND main.year=sub.year
                AND main.rep_period=sub.rep_period
        WHERE main.type in ('storage')
        ",
    )

    # This follows the same implementation as highest_in_out above, but using
    # only the outgoing flows.
    #
    # The query below is trying to replace the following constraints_partitions example:
    #= (
    #     name = :highest_out,
    #     partitions = _outflows,
    #     strategy = :highest,
    #     asset_filter = (a, y) -> graph[a].type in ["producer", "storage", "conversion"],
    # ),
    =#
    DuckDB.execute(
        connection,
        "CREATE OR REPLACE TABLE cons_indices_highest_out AS
        SELECT
            main.asset,
            main.year,
            main.rep_period,
            COALESCE(sub.time_block_start, 1) AS time_block_start,
            lead(sub.time_block_start - 1, 1, main.num_timesteps)
                OVER (PARTITION BY main.asset, main.year, main.rep_period ORDER BY time_block_start)
                AS time_block_end,
        FROM t_cons_indices AS main
        LEFT JOIN (
            SELECT from_asset as asset, year, rep_period, time_block_start
            FROM flow_time_resolution
        ) AS sub
            ON main.asset=sub.asset
                AND main.year=sub.year
                AND main.rep_period=sub.rep_period
        WHERE main.type in ('producer', 'storage', 'conversion')
        ",
    )
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
