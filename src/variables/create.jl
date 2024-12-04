export compute_variables_indices

# TODO: Allow changing table names to make unit tests possible
# The signature should be something like `...(connection; assets_data="t_assets_data", ...)`
function compute_variables_indices(connection)
    # TODO: Format SQL queries consistently (is there a way to add a linter/formatter?)
    variables = Dict{Symbol,TulipaVariable}()

    variables[:flow] = TulipaVariable(
        DuckDB.query(
            connection,
            "CREATE OR REPLACE TEMP SEQUENCE id START 1;
            SELECT
                nextval('id') as index,
                from_asset as from,
                to_asset as to,
                year,
                rep_period,
                efficiency,
                time_block_start,
                time_block_end
            FROM flow_time_resolution
            ",
        ) |> DataFrame,
    )

    variables[:units_on] = TulipaVariable(
        DuckDB.query(
            connection,
            "CREATE OR REPLACE TEMP SEQUENCE id START 1;
            SELECT
                nextval('id') as index,
                atr.asset,
                atr.year,
                atr.rep_period,
                atr.time_block_start,
                atr.time_block_end
            FROM asset_time_resolution AS atr
            LEFT JOIN asset
                ON asset.asset = atr.asset
            WHERE
                asset.type IN ('producer','conversion')
                AND asset.unit_commitment = true
            ",
        ) |> DataFrame,
    )

    variables[:is_charging] = TulipaVariable(
        DuckDB.query(
            connection,
            "CREATE OR REPLACE TEMP SEQUENCE id START 1;
            SELECT
                nextval('id') as index,
                t_low.asset,
                t_low.year,
                t_low.rep_period,
                t_low.time_block_start,
                t_low.time_block_end
            FROM t_lowest_all_flows AS t_low
            LEFT JOIN asset
                ON t_low.asset = asset.asset
            WHERE
                asset.type = 'storage'
                AND asset.use_binary_storage_method = true
            ",
        ) |> DataFrame,
    )

    variables[:storage_level_intra_rp] = TulipaVariable(
        DuckDB.query(
            connection,
            "CREATE OR REPLACE TEMP SEQUENCE id START 1;
            CREATE OR REPLACE TABLE storage_level_intra_rp AS
            SELECT
                nextval('id') as index,
                t_low.asset,
                t_low.year,
                t_low.rep_period,
                t_low.time_block_start,
                t_low.time_block_end
            FROM t_lowest_all AS t_low
            LEFT JOIN asset
                ON t_low.asset = asset.asset
            WHERE
                asset.type = 'storage'
                AND asset.is_seasonal = false;
            SELECT * FROM storage_level_intra_rp
            ",
        ) |> DataFrame,
    )

    variables[:storage_level_inter_rp] = TulipaVariable(
        DuckDB.query(
            connection,
            "CREATE OR REPLACE TEMP SEQUENCE id START 1;
            CREATE OR REPLACE TABLE storage_level_inter_rp AS
            SELECT
                nextval('id') as index,
                asset.asset,
                attr.year,
                attr.period_block_start,
                attr.period_block_end,
            FROM asset_timeframe_time_resolution AS attr
            LEFT JOIN asset
                ON attr.asset = asset.asset
            WHERE
                asset.type = 'storage';
            SELECT * FROM storage_level_inter_rp
            ",
        ) |> DataFrame,
    )

    variables[:flows_investment] = TulipaVariable(
        DuckDB.query(
            connection,
            "SELECT
                flow.from_asset,
                flow.to_asset,
                flow_milestone.milestone_year,
                flow.investment_integer,
            FROM flow_milestone
            LEFT JOIN flow
                ON flow.from_asset = flow_milestone.from_asset
                AND flow.to_asset = flow_milestone.to_asset
            WHERE
                flow_milestone.investable = true",
        ) |> DataFrame,
    )

    variables[:assets_investment] = TulipaVariable(
        DuckDB.query(
            connection,
            "SELECT
                asset.asset,
                asset_milestone.milestone_year,
                asset.investment_integer,
                asset.capacity,
                --asset.investment_limit,
                asset.capacity_storage_energy,
                --asset.investment_limit_storage_energy,
            FROM asset_milestone
            LEFT JOIN asset
                ON asset.asset = asset_milestone.asset
            WHERE
                asset_milestone.investable = true",
        ) |> DataFrame,
    )

    variables[:assets_decommission_simple_method] = TulipaVariable(
        DuckDB.query(
            connection,
            "SELECT
                asset.asset,
                asset_milestone.milestone_year,
                asset.investment_integer,
            FROM asset_milestone
            LEFT JOIN asset
                ON asset.asset = asset_milestone.asset
            WHERE
                asset.investment_method = 'simple'",
        ) |> DataFrame,
    )

    variables[:assets_decommission_compact_method] = TulipaVariable(
        DuckDB.query(
            connection,
            "SELECT
                asset_both.asset,
                asset_both.milestone_year,
                asset_both.commission_year,
                asset_both.decommissionable,
                asset.investment_integer
            FROM asset_both
            LEFT JOIN asset
                ON asset.asset = asset_both.asset
            WHERE
                asset_both.decommissionable = true
                AND asset.investment_method = 'compact'
            ",
        ) |> DataFrame,
    )

    variables[:flows_decommission_using_simple_method] = TulipaVariable(
        DuckDB.query(
            connection,
            "SELECT
                flow.from_asset,
                flow.to_asset,
                flow_milestone.milestone_year
            FROM flow_milestone
            LEFT JOIN flow
                ON flow.from_asset = flow_milestone.from_asset
                AND flow.to_asset = flow_milestone.to_asset
            WHERE
                flow.is_transport = true
            ",
        ) |> DataFrame,
    )

    variables[:assets_investment_energy] = TulipaVariable(
        DuckDB.query(
            connection,
            "SELECT
                asset.asset,
                asset_milestone.milestone_year,
                asset.investment_integer_storage_energy,
            FROM asset_milestone
            LEFT JOIN asset
                ON asset.asset = asset_milestone.asset
            WHERE
                asset.storage_method_energy = true
                AND asset_milestone.investable = true
                AND asset.type = 'storage'
                AND asset.investment_method = 'simple'
            ",
        ) |> DataFrame,
    )

    variables[:assets_decommission_energy_simple_method] = TulipaVariable(
        DuckDB.query(
            connection,
            "SELECT
                asset.asset,
                asset_milestone.milestone_year,
                asset.investment_integer_storage_energy,
            FROM asset_milestone
            LEFT JOIN asset
                ON asset.asset = asset_milestone.asset
            WHERE
                asset.storage_method_energy = true
                AND asset.type = 'storage'
                AND asset.investment_method = 'simple'",
        ) |> DataFrame,
    )

    return variables
end
