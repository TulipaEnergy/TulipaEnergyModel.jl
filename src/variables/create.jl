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
            :storage_level_intra_rp,
            :storage_level_inter_rp,
            :flows_investment,
            :assets_investment,
            :assets_decommission_simple_method,
            :assets_decommission_compact_method,
            :flows_decommission_using_simple_method,
            :assets_investment_energy,
            :assets_decommission_energy_simple_method,
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
        CREATE OR REPLACE TABLE var_storage_level_intra_rp AS
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
        ",
    )

    DuckDB.query(
        connection,
        "CREATE OR REPLACE TEMP SEQUENCE id START 1;
        CREATE OR REPLACE TABLE var_storage_level_inter_rp AS
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
            asset.type = 'storage'
        ",
    )

    DuckDB.query(
        connection,
        "CREATE OR REPLACE TEMP SEQUENCE id START 1;
        CREATE OR REPLACE TABLE var_flows_investment AS
        SELECT
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
    )

    DuckDB.query(
        connection,
        "CREATE OR REPLACE TEMP SEQUENCE id START 1;
        CREATE OR REPLACE TABLE var_assets_investment AS
        SELECT
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
        CREATE OR REPLACE TABLE var_assets_decommission_simple_method AS
        SELECT
            asset.asset,
            asset_milestone.milestone_year,
            asset.investment_integer,
        FROM asset_milestone
        LEFT JOIN asset
            ON asset.asset = asset_milestone.asset
        WHERE
            asset.investment_method = 'simple'",
    )

    DuckDB.query(
        connection,
        "CREATE OR REPLACE TEMP SEQUENCE id START 1;
        CREATE OR REPLACE TABLE var_assets_decommission_compact_method AS
        SELECT
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
    )

    DuckDB.query(
        connection,
        "CREATE OR REPLACE TEMP SEQUENCE id START 1;
        CREATE OR REPLACE TABLE var_flows_decommission_using_simple_method AS
        SELECT
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
    )

    DuckDB.query(
        connection,
        "CREATE OR REPLACE TEMP SEQUENCE id START 1;
        CREATE OR REPLACE TABLE var_assets_investment_energy AS
        SELECT
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
    )

    DuckDB.query(
        connection,
        "CREATE OR REPLACE TEMP SEQUENCE id START 1;
        CREATE OR REPLACE TABLE var_assets_decommission_energy_simple_method AS
        SELECT
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
    )

    return
end
