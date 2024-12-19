export compute_constraints_indices

function compute_constraints_indices(connection)
    # TODO: Format SQL queries consistently (is there a way to add a linter/formatter?)
    _create_constraints_tables(connection)

    constraints = Dict{Symbol,TulipaConstraint}(
        key => TulipaConstraint(connection, "cons_$key") for key in (
            :balance_conversion,
            :balance_consumer,
            :balance_hub,
            :capacity_incoming,
            :capacity_incoming_non_investable_storage_with_binary,
            :capacity_incoming_investable_storage_with_binary,
            :capacity_outgoing,
            :capacity_outgoing_non_investable_storage_with_binary,
            :capacity_outgoing_investable_storage_with_binary,
            :limit_units_on,
            :ramping_with_unit_commitment,
            :max_output_flow_with_basic_unit_commitment,
            :max_ramp_with_unit_commitment,
            :ramping_without_unit_commitment,
            :max_ramp_without_unit_commitment,
            :balance_storage_rep_period,
            :balance_storage_over_clustered_year,
            :min_energy_over_clustered_year,
            :max_energy_over_clustered_year,
            :transport_flow_limit,
            :group_max_investment_limit,
            :group_min_investment_limit,
        )
    )

    return constraints
end

function _create_constraints_tables(connection)
    DuckDB.query(
        connection,
        "CREATE OR REPLACE TEMP SEQUENCE id START 1;
        CREATE OR REPLACE TABLE cons_balance_conversion AS
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
            asset.type in ('conversion')
        ORDER BY
            asset.asset,
            t_low.year,
            t_low.rep_period,
            t_low.time_block_start
        ",
    )

    DuckDB.query(
        connection,
        "CREATE OR REPLACE TEMP SEQUENCE id START 1;
        CREATE OR REPLACE TABLE cons_balance_consumer AS
        SELECT
            nextval('id') AS index,
            t_high.*
        FROM t_highest_all_flows AS t_high
        LEFT JOIN asset
            ON t_high.asset = asset.asset
        WHERE
            asset.type = 'consumer';
        ",
    )

    DuckDB.query(
        connection,
        "CREATE OR REPLACE TEMP SEQUENCE id START 1;
        CREATE OR REPLACE TABLE cons_balance_hub AS
        SELECT
            nextval('id') AS index,
            t_high.*
        FROM t_highest_all_flows AS t_high
        LEFT JOIN asset
            ON t_high.asset = asset.asset
        WHERE
            asset.type = 'hub';
        ",
    )

    DuckDB.query(
        connection,
        "CREATE OR REPLACE TEMP SEQUENCE id START 1;
        CREATE OR REPLACE TABLE cons_capacity_incoming AS
        SELECT
            nextval('id') AS index,
            t_high.*
        FROM t_highest_in_flows AS t_high
        LEFT JOIN asset
            ON t_high.asset = asset.asset
        WHERE
            asset.type in ('storage')",
    )

    DuckDB.query(
        connection,
        "CREATE OR REPLACE TEMP SEQUENCE id START 1;
        CREATE OR REPLACE TABLE cons_capacity_incoming_non_investable_storage_with_binary AS
        SELECT
            nextval('id') AS index,
            t_high.*
        FROM t_highest_in_flows AS t_high
        LEFT JOIN asset
            ON t_high.asset = asset.asset
        LEFT JOIN asset_milestone
            ON t_high.asset = asset_milestone.asset
            AND t_high.year = asset_milestone.milestone_year
        WHERE
            asset.type in ('storage')
            AND asset.use_binary_storage_method in ('binary', 'relaxed_binary')
            AND NOT asset_milestone.investable
        ",
    )

    DuckDB.query(
        connection,
        "CREATE OR REPLACE TEMP SEQUENCE id START 1;
        CREATE OR REPLACE TABLE cons_capacity_incoming_investable_storage_with_binary AS
        SELECT
            nextval('id') AS index,
            t_high.*
        FROM t_highest_in_flows AS t_high
        LEFT JOIN asset
            ON t_high.asset = asset.asset
        LEFT JOIN asset_milestone
            ON t_high.asset = asset_milestone.asset
            AND t_high.year = asset_milestone.milestone_year
        WHERE
            asset.type in ('storage')
            AND asset.use_binary_storage_method in ('binary', 'relaxed_binary')
            AND asset_milestone.investable
        ",
    )

    DuckDB.query(
        connection,
        "CREATE OR REPLACE TEMP SEQUENCE id START 1;
        CREATE OR REPLACE TABLE cons_capacity_outgoing AS
        SELECT
            nextval('id') AS index,
            t_high.*
        FROM t_highest_out_flows AS t_high
        LEFT JOIN asset
            ON t_high.asset = asset.asset
        WHERE
            asset.type in ('producer', 'storage', 'conversion')",
    )

    DuckDB.query(
        connection,
        "CREATE OR REPLACE TEMP SEQUENCE id START 1;
        CREATE OR REPLACE TABLE cons_capacity_outgoing_non_investable_storage_with_binary AS
        SELECT
            nextval('id') AS index,
            t_high.*
        FROM t_highest_out_flows AS t_high
        LEFT JOIN asset
            ON t_high.asset = asset.asset
        LEFT JOIN asset_milestone
            ON t_high.asset = asset_milestone.asset
            AND t_high.year = asset_milestone.milestone_year
        WHERE
            asset.type in ('storage')
            AND asset.use_binary_storage_method in ('binary', 'relaxed_binary')
            AND NOT asset_milestone.investable
        ",
    )

    DuckDB.query(
        connection,
        "CREATE OR REPLACE TEMP SEQUENCE id START 1;
        CREATE OR REPLACE TABLE cons_capacity_outgoing_investable_storage_with_binary AS
        SELECT
            nextval('id') AS index,
            t_high.*
        FROM t_highest_out_flows AS t_high
        LEFT JOIN asset
            ON t_high.asset = asset.asset
        LEFT JOIN asset_milestone
            ON t_high.asset = asset_milestone.asset
            AND t_high.year = asset_milestone.milestone_year
        WHERE
            asset.type in ('storage')
            AND asset.use_binary_storage_method in ('binary', 'relaxed_binary')
            AND asset_milestone.investable
        ",
    )

    DuckDB.query(
        connection,
        "CREATE OR REPLACE TABLE cons_limit_units_on AS
        SELECT * FROM var_units_on
        ",
    )

    DuckDB.query(
        connection,
        "CREATE OR REPLACE TEMP SEQUENCE id START 1;
        CREATE OR REPLACE TABLE cons_ramping_with_unit_commitment AS
        SELECT
            nextval('id') AS index,
            t_high.*
        FROM t_highest_assets_and_out_flows AS t_high
        LEFT JOIN asset
            ON t_high.asset = asset.asset
        WHERE
            asset.type in ('producer', 'conversion')
            AND asset.unit_commitment
        ",
    )

    DuckDB.query(
        connection,
        "CREATE OR REPLACE TEMP SEQUENCE id START 1;
        CREATE OR REPLACE TABLE cons_max_output_flow_with_basic_unit_commitment AS
        SELECT
            nextval('id') AS index,
            t_high.*
        FROM t_highest_assets_and_out_flows AS t_high
        LEFT JOIN asset
            ON t_high.asset = asset.asset
        WHERE
            asset.type in ('producer', 'conversion')
            AND asset.unit_commitment
            AND asset.unit_commitment_method = 'basic'
        ",
    )

    DuckDB.query(
        connection,
        "CREATE OR REPLACE TEMP SEQUENCE id START 1;
        CREATE OR REPLACE TABLE cons_max_ramp_with_unit_commitment AS
        SELECT
           nextval('id') AS index,
           t_high.*
        FROM t_highest_assets_and_out_flows AS t_high
        LEFT JOIN asset
            ON t_high.asset = asset.asset
        WHERE
            asset.type in ('producer', 'conversion')
            AND asset.ramping
            AND asset.unit_commitment
            AND asset.unit_commitment_method = 'basic'
        ",
    )

    DuckDB.query(
        connection,
        "CREATE OR REPLACE TEMP SEQUENCE id START 1;
        CREATE OR REPLACE TABLE cons_ramping_without_unit_commitment AS
        SELECT
            nextval('id') AS index,
            t_high.*
        FROM t_highest_out_flows AS t_high
        LEFT JOIN asset
            ON t_high.asset = asset.asset
        WHERE
            asset.type in ('producer', 'storage', 'conversion')
            AND NOT asset.unit_commitment
        ",
    )

    DuckDB.query(
        connection,
        "CREATE OR REPLACE TEMP SEQUENCE id START 1;
        CREATE OR REPLACE TABLE cons_max_ramp_without_unit_commitment AS
        SELECT
           nextval('id') AS index,
           t_high.*
        FROM t_highest_out_flows AS t_high
        LEFT JOIN asset
            ON t_high.asset = asset.asset
        WHERE
            asset.type in ('producer', 'storage', 'conversion')
            AND asset.ramping
            AND NOT asset.unit_commitment
            AND asset.unit_commitment_method != 'basic'
        ",
    )

    DuckDB.query(
        connection,
        "CREATE OR REPLACE TABLE cons_balance_storage_rep_period AS
        SELECT * FROM var_storage_level_rep_period
        ",
    )

    DuckDB.query(
        connection,
        "CREATE OR REPLACE TABLE cons_balance_storage_over_clustered_year AS
        SELECT * FROM var_storage_level_over_clustered_year
        ",
    )

    DuckDB.query(
        connection,
        "CREATE OR REPLACE TEMP SEQUENCE id START 1;
        CREATE OR REPLACE TABLE cons_min_energy_over_clustered_year AS
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
    )

    # a -> any(!ismissing, values(a.max_energy_timeframe_partition)),

    DuckDB.query(
        connection,
        "CREATE OR REPLACE TEMP SEQUENCE id START 1;
        CREATE OR REPLACE TABLE cons_max_energy_over_clustered_year AS
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
    )

    DuckDB.query(
        connection,
        "CREATE OR REPLACE TEMP SEQUENCE id START 1;
        CREATE OR REPLACE TABLE cons_transport_flow_limit AS
        SELECT
           nextval('id') AS index,
           var_flow.from,
           var_flow.to,
           var_flow.year,
           var_flow.rep_period,
           var_flow.time_block_start,
           var_flow.time_block_end,
           var_flow.index AS var_flow_index
        FROM var_flow
        LEFT JOIN flow
            ON flow.from_asset = var_flow.from
            AND flow.to_asset = var_flow.to
        WHERE
            flow.is_transport
        ",
    )

    DuckDB.query(
        connection,
        "CREATE OR REPLACE TEMP SEQUENCE id START 1;
        CREATE OR REPLACE TABLE cons_group_max_investment_limit AS
        SELECT
            nextval('id') AS index,
            ga.name,
            ga.milestone_year,
            ga.max_investment_limit,
        FROM group_asset AS ga
        WHERE
            ga.invest_method AND
            ga.max_investment_limit IS NOT NULL
        ",
    )

    DuckDB.query(
        connection,
        "CREATE OR REPLACE TEMP SEQUENCE id START 1;
        CREATE OR REPLACE TABLE cons_group_min_investment_limit AS
        SELECT
            nextval('id') AS index,
            ga.name,
            ga.milestone_year,
            ga.min_investment_limit,
        FROM group_asset AS ga
        WHERE
            ga.invest_method AND
            ga.min_investment_limit IS NOT NULL
        ",
    )

    return
end
