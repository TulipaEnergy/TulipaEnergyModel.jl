export compute_constraints_indices

function compute_constraints_indices(connection)
    constraints = Dict{Symbol,TulipaConstraint}()

    constraints[:lowest] = TulipaConstraint(
        DuckDB.query(
            connection,
            "CREATE OR REPLACE TEMP SEQUENCE id START 1;
            SELECT
                nextval('id') AS index,
                asset.asset,
                t_low.year,
                t_low.rep_period,
                t_low.time_block_start,
                t_low.time_block_end,
            FROM t_lowest_all_flows AS t_low
            LEFT JOIN asset
                ON t_low.asset = asset.asset
            WHERE
                asset.type in ('conversion', 'producer')
            ORDER BY
                asset.asset,
                t_low.year,
                t_low.rep_period,
                t_low.time_block_start
            ",
        ) |> DataFrame,
    )

    constraints[:highest_in_out] = TulipaConstraint(
        DuckDB.query(
            connection,
            "CREATE OR REPLACE TEMP SEQUENCE id START 1;
            SELECT
                nextval('id') AS index,
                t_high.*
            FROM t_highest_all_flows AS t_high
            LEFT JOIN asset
                ON t_high.asset = asset.asset
            LEFT JOIN asset_both
                ON t_high.asset = asset_both.asset
                AND t_high.year = asset_both.milestone_year
                AND t_high.year = asset_both.commission_year
            WHERE
                asset_both.active = true
                AND asset.type in ('hub', 'consumer')",
        ) |> DataFrame,
    )

    constraints[:highest_in] = TulipaConstraint(
        DuckDB.query(
            connection,
            "CREATE OR REPLACE TEMP SEQUENCE id START 1;
            SELECT
                nextval('id') AS index,
                t_high.*
            FROM t_highest_in_flows AS t_high
            LEFT JOIN asset
                ON t_high.asset = asset.asset
            LEFT JOIN asset_both
                ON t_high.asset = asset_both.asset
                AND t_high.year = asset_both.milestone_year
                AND t_high.year = asset_both.commission_year
            WHERE
                asset_both.active = true
                AND asset.type in ('storage')",
        ) |> DataFrame,
    )

    constraints[:highest_out] = TulipaConstraint(
        DuckDB.query(
            connection,
            "CREATE OR REPLACE TEMP SEQUENCE id START 1;
            SELECT
                nextval('id') AS index,
                t_high.*
            FROM t_highest_out_flows AS t_high
            LEFT JOIN asset
                ON t_high.asset = asset.asset
            LEFT JOIN asset_both
                ON t_high.asset = asset_both.asset
                AND t_high.year = asset_both.milestone_year
                AND t_high.year = asset_both.commission_year
            WHERE
                asset_both.active = true
                AND asset.type in ('producer', 'storage', 'conversion')",
        ) |> DataFrame,
    )

    constraints[:units_on_and_outflows] = TulipaConstraint(
        DuckDB.query(
            connection,
            "CREATE OR REPLACE TEMP SEQUENCE id START 1;
            CREATE OR REPLACE TABLE units_on_and_outflows AS
            SELECT
                nextval('id') AS index,
                t_high.*
            FROM t_highest_assets_and_out_flows AS t_high
            LEFT JOIN asset
                ON t_high.asset = asset.asset
            LEFT JOIN asset_both
                ON t_high.asset = asset_both.asset
                AND t_high.year = asset_both.milestone_year
                AND t_high.year = asset_both.commission_year
            WHERE
                asset_both.active = true
                AND asset.type in ('producer', 'conversion')
                AND asset.unit_commitment = true;
            SELECT * FROM units_on_and_outflows
            ",
        ) |> DataFrame,
    )

    constraints[:storage_level_intra_rp] = TulipaConstraint(
        DuckDB.query(
            connection,
            "SELECT * FROM storage_level_intra_rp
            ",
        ) |> DataFrame,
    )

    constraints[:storage_level_inter_rp] = TulipaConstraint(
        DuckDB.query(
            connection,
            "SELECT * FROM storage_level_inter_rp
            ",
        ) |> DataFrame,
    )

    constraints[:min_energy_inter_rp] = TulipaConstraint(
        DuckDB.query(
            connection,
            "CREATE OR REPLACE TEMP SEQUENCE id START 1;
            SELECT
                nextval('id') AS index,
                attr.asset,
                attr.year,
                attr.period_block_start,
                attr.period_block_end,
            FROM asset_timeframe_time_resolution AS attr
            LEFT JOIN asset_milestone
                ON attr.asset = asset_milestone.asset
                AND attr.year = asset_milestone.milestone_year
            WHERE
                asset_milestone.min_energy_timeframe_partition IS NOT NULL
            ",
        ) |> DataFrame,
    )

    # a -> any(!ismissing, values(a.max_energy_timeframe_partition)),

    constraints[:max_energy_inter_rp] = TulipaConstraint(
        DuckDB.query(
            connection,
            "CREATE OR REPLACE TEMP SEQUENCE id START 1;
            SELECT
                nextval('id') AS index,
                attr.asset,
                attr.year,
                attr.period_block_start,
                attr.period_block_end,
            FROM asset_timeframe_time_resolution AS attr
            LEFT JOIN asset_milestone
                ON attr.asset = asset_milestone.asset
                AND attr.year = asset_milestone.milestone_year
            WHERE
                asset_milestone.max_energy_timeframe_partition IS NOT NULL
            ",
        ) |> DataFrame,
    )

    return constraints
end
