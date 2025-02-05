export compute_variables_indices

# TODO: Allow changing table names to make unit tests possible
# The signature should be something like `...(connection; assets_data="t_assets_data", ...)`
function compute_variables_indices(connection)
    # TODO: Format SQL queries consistently (is there a way to add a linter/formatter?)
    _create_variables_tables(connection)

    variables = Dict{Symbol,TulipaVariable}(
        key => TulipaVariable(connection, "var_$key") for key in (
            :flow,
            :units_on,
            :is_charging,
            :storage_level_rep_period,
            :storage_level_over_clustered_year,
            :assets_investment,
            :assets_decommission,
            :flows_investment,
            :flows_decommission,
            :assets_investment_energy,
            :assets_decommission_energy,
        )
    )

    return variables
end

function _create_variables_tables(connection)
    DuckDB.query(
        connection,
        "CREATE OR REPLACE TEMP SEQUENCE id START 1;
        CREATE OR REPLACE TABLE var_flow AS
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
    )

    DuckDB.query(
        connection,
        "CREATE OR REPLACE TEMP SEQUENCE id START 1;
        CREATE OR REPLACE TABLE var_units_on AS
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
    )

    DuckDB.query(
        connection,
        "CREATE OR REPLACE TEMP SEQUENCE id START 1;
        CREATE OR REPLACE TABLE var_is_charging AS
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
    )

    DuckDB.query(
        connection,
        "CREATE OR REPLACE TEMP SEQUENCE id START 1;
        CREATE OR REPLACE TABLE var_storage_level_rep_period AS
        WITH filtered_assets AS (
            SELECT
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
                AND asset.is_seasonal = false
            ORDER BY
                t_low.asset,
                t_low.year,
                t_low.rep_period,
                t_low.time_block_start
        )
        SELECT
            nextval('id') AS index,
            filtered_assets.*
        FROM filtered_assets
        ",
    )

    DuckDB.query(
        connection,
        "CREATE OR REPLACE TEMP SEQUENCE id START 1;
         CREATE OR REPLACE TABLE var_storage_level_over_clustered_year AS
         WITH filtered_assets AS (
            SELECT
                attr.asset,
                attr.year,
                attr.period_block_start,
                attr.period_block_end
            FROM asset_timeframe_time_resolution AS attr
            LEFT JOIN asset
                ON attr.asset = asset.asset
            WHERE
                asset.type = 'storage'
                AND asset.is_seasonal = true
            ORDER BY
                attr.asset,
                attr.year,
                attr.period_block_start
        )
        SELECT
            nextval('id') AS index,
            filtered_assets.*
        FROM filtered_assets
        ",
    )

    DuckDB.query(
        connection,
        "CREATE OR REPLACE TEMP SEQUENCE id START 1;
        CREATE OR REPLACE TABLE var_flows_investment AS
        SELECT
            nextval('id') as index,
            flow.from_asset,
            flow.to_asset,
            flow_milestone.milestone_year,
            flow.investment_integer,
            flow.capacity,
            flow_commission.investment_limit,
        FROM flow_milestone
        LEFT JOIN flow
            ON flow.from_asset = flow_milestone.from_asset
            AND flow.to_asset = flow_milestone.to_asset
        LEFT JOIN flow_commission
            ON flow_commission.from_asset = flow_milestone.from_asset
                AND flow_commission.to_asset = flow_milestone.to_asset
                AND flow_commission.commission_year = flow_milestone.milestone_year
        WHERE
            flow_milestone.investable = true",
    )

    DuckDB.query(
        connection,
        "CREATE OR REPLACE TEMP SEQUENCE id START 1;
        CREATE OR REPLACE TABLE var_assets_investment AS
        SELECT
            nextval('id') as index,
            asset.asset,
            asset_milestone.milestone_year,
            asset.investment_integer,
            asset.capacity,
            asset_commission.investment_limit,
        FROM asset_milestone
        LEFT JOIN asset
            ON asset.asset = asset_milestone.asset
        LEFT JOIN asset_commission
            ON asset_commission.asset = asset_milestone.asset
                AND asset_commission.commission_year = asset_milestone.milestone_year
        WHERE
            asset_milestone.investable = true",
    )

    DuckDB.query(
        connection,
        "CREATE OR REPLACE TEMP SEQUENCE id START 1;
        CREATE OR REPLACE TABLE var_assets_decommission AS
        SELECT
            nextval('id') as index,
            asset_both.asset,
            asset_both.milestone_year,
            asset_both.commission_year,
            asset_both.decommissionable,
            asset_both.initial_units,
            asset.investment_integer
        FROM asset_both
        LEFT JOIN asset
            ON asset.asset = asset_both.asset
        WHERE asset_both.decommissionable
            AND asset_both.milestone_year != asset_both.commission_year
        ",
    )

    DuckDB.query(
        connection,
        "CREATE OR REPLACE TEMP SEQUENCE id START 1;
        CREATE OR REPLACE TABLE var_flows_decommission AS
        SELECT
            nextval('id') as index,
            flow.from_asset,
            flow.to_asset,
            flow_both.milestone_year,
            flow_both.commission_year,
        FROM flow_both
        LEFT JOIN flow
            ON flow.from_asset = flow_both.from_asset
            AND flow.to_asset = flow_both.to_asset
        WHERE
            flow.is_transport = true
            AND flow_both.decommissionable
            AND flow_both.commission_year != flow_both.milestone_year
        ",
    )

    DuckDB.query(
        connection,
        "CREATE OR REPLACE TEMP SEQUENCE id START 1;
        CREATE OR REPLACE TABLE var_assets_investment_energy AS
        SELECT
            nextval('id') as index,
            asset.asset,
            asset_milestone.milestone_year,
            asset.investment_integer_storage_energy,
            asset.capacity_storage_energy,
            asset_commission.investment_limit_storage_energy,
        FROM asset_milestone
        LEFT JOIN asset
            ON asset.asset = asset_milestone.asset
        LEFT JOIN asset_commission
            ON asset_commission.asset = asset_milestone.asset
                AND asset_commission.commission_year = asset_milestone.milestone_year
        WHERE
            asset.storage_method_energy = true
            AND asset_milestone.investable = true
            AND asset.type = 'storage'
            AND asset.investment_method = 'simple'
        ",
    )

    DuckDB.query(
        connection,
        "CREATE OR REPLACE TEMP SEQUENCE id START 1;
        CREATE OR REPLACE TABLE var_assets_decommission_energy AS
        SELECT
            nextval('id') as index,
            asset.asset,
            asset_both.milestone_year,
            asset_both.commission_year,
            asset.investment_integer_storage_energy,
        FROM asset_both
        LEFT JOIN asset
            ON asset.asset = asset_both.asset
        WHERE
            asset.storage_method_energy = true
            AND asset.type = 'storage'
            AND asset.investment_method = 'simple' -- TODO: Keep this or not?
            AND asset_both.decommissionable
            AND asset_both.commission_year != asset_both.milestone_year
        ",
    )

    return
end
