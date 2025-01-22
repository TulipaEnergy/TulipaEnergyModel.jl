export add_capacity_constraints!

"""
add_capacity_constraints!(model, graph,...)

Adds the capacity constraints for all asset types to the model
"""

function add_capacity_constraints!(connection, model, variables, constraints, profiles, graph, sets)
    ## unpack from sets
    Acv = sets[:Acv]
    Ap = sets[:Ap]
    As = sets[:As]
    V_all = sets[:V_all]
    accumulated_set_using_compact_method = sets[:accumulated_set_using_compact_method]
    accumulated_set_using_compact_method_lookup = sets[:accumulated_set_using_compact_method_lookup]
    accumulated_units_lookup = sets[:accumulated_units_lookup]
    decommissionable_assets_using_compact_method =
        sets[:decommissionable_assets_using_compact_method]

    ## unpack from model
    accumulated_initial_units = model[:accumulated_initial_units]
    accumulated_investment_units_using_simple_method =
        model[:accumulated_investment_units_using_simple_method]
    accumulated_units = model[:accumulated_units]

    ## unpack from variables
    assets_decommission_compact_method = variables[:assets_decommission_compact_method]
    assets_investment = variables[:assets_investment]
    flows_indices = variables[:flow].indices
    flow = variables[:flow].container

    # TODO: Rename these tables (don't merge without fixing this)
    # The table t_ADUUCM replaces accumulated_decommission_units_using_compact_method
    # The key is (asset, milestone_year, commission_year)
    # This is a self-join of var_assets_decommission_compact_method.
    # This provides:
    # - acc_index: list of asset decommission compact variables to be accumulated.
    DuckDB.query(
        connection,
        "CREATE OR REPLACE TEMP TABLE t_ADUUCM AS
        SELECT
            var.index,
            ANY_VALUE(var.asset) AS asset,
            ANY_VALUE(var.milestone_year) AS milestone_year,
            ANY_VALUE(var.commission_year) AS commission_year,
            ARRAY_AGG(other.index) AS acc_index
        FROM var_assets_decommission_compact_method AS var
        LEFT JOIN var_assets_decommission_compact_method AS other
            ON var.asset = other.asset
            AND var.commission_year = other.commission_year
            AND var.commission_year <= other.milestone_year
            AND other.milestone_year <= var.milestone_year
        GROUP BY var.index
        ",
    )

    # The table t_compact replaces accumulated_set_using_compact_method
    # The key is also (asset, milestone_year, commission_year)
    # There are more rows here than in var_adcm because this includes the m_year = c_year.
    # This table is used to create a lookup dictionary with the relevant expressions.
    # This is a filter of the asset_both table.
    # This provides:
    #   - initial_units
    #   - asset_investment_index: index of the investment variable (var_assets_investment)
    #   - ADUUCM_acc_index: list of asset decommission compact variables to be accumulated
    DuckDB.query(
        connection,
        "CREATE OR REPLACE TEMP SEQUENCE id START 1;
        CREATE OR REPLACE TEMP TABLE t_compact AS
        SELECT
            nextval('id') as index,
            asset_both.asset,
            asset_both.milestone_year,
            asset_both.commission_year,
            var_assets_investment.index AS asset_investment_index,
            asset_both.initial_units,
            asset_both.decommissionable,
            COALESCE(asset_milestone.investable, false) AS investable,
            COALESCE(t_ADUUCM.acc_index, []) AS ADUUCM_acc_index
        FROM asset_both
        LEFT JOIN asset
            ON asset.asset = asset_both.asset

        -- NOTICE THAT asset_milestone and var_assets_investment are joined on
        -- commission_year = milestone_year

        LEFT JOIN asset_milestone
            ON asset_milestone.asset = asset_both.asset
            AND asset_milestone.milestone_year = asset_both.commission_year
        LEFT JOIN var_assets_investment
            ON asset_both.asset = var_assets_investment.asset
            AND asset_both.commission_year = var_assets_investment.milestone_year
        LEFT JOIN t_ADUUCM
            ON asset_both.asset = t_ADUUCM.asset
            AND asset_both.milestone_year = t_ADUUCM.milestone_year
            AND asset_both.commission_year = t_ADUUCM.commission_year
        WHERE
            asset.investment_method = 'compact'
            AND (asset_milestone.investable
                OR asset_both.decommissionable)
        ",
    )

    # Let's define a new accumulated_units_compact_method expression
    accumulated_units_compact_method = Dict(
        (row.asset, row.milestone_year, row.commission_year) => begin
            initial_units = row.initial_units::Float64

            var_adcm = assets_decommission_compact_method.container
            var_ai = assets_investment.container

            aduucm_acc_index = row.ADUUCM_acc_index::Vector{Union{Missing,Int}}

            if length(aduucm_acc_index) > 0
                aduucm = sum(var_adcm[i] for i in row.ADUUCM_acc_index::Vector{Union{Missing,Int}})
                if row.investable::Bool
                    @expression(model, initial_units + var_ai[row.asset_investment_index] - aduucm)
                else
                    @expression(model, initial_units - aduucm)
                end
            else
                @assert row.investable::Bool
                @expression(model, initial_units + var_ai[row.asset_investment_index])
            end
        end for row in DuckDB.query(connection, "FROM t_compact")
    )

    ## Expressions used by capacity constraints
    # - Create capacity limit for outgoing flows
    let table_name = :capacity_outgoing, cons = constraints[table_name]
        indices = _append_capacity_data_to_indices(connection, table_name)
        attach_expression!(
            cons,
            :profile_times_capacity,
            [
                if row.investment_method == "compact"
                    @expression(
                        model,
                        row.capacity * sum(
                            profile_aggregation(
                                Statistics.mean,
                                graph[row.asset].rep_periods_profiles,
                                row.year,
                                v,
                                ("availability", row.rep_period),
                                row.time_block_start:row.time_block_end,
                                1.0,
                            ) * accumulated_units_compact_method[(row.asset, row.year, v)] for
                            v in V_all if
                            (row.asset, row.year, v) in accumulated_set_using_compact_method
                        )
                    )
                else
                    availability_agg = _profile_aggregate(
                        profiles.rep_period,
                        (row.profile_name, row.year, row.rep_period),
                        row.time_block_start:row.time_block_end,
                        Statistics.mean,
                        1.0,
                    )
                    @expression(
                        model,
                        availability_agg *
                        row.capacity *
                        accumulated_units[accumulated_units_lookup[(row.asset, row.year)]]
                    )
                end for row in indices
            ],
        )
    end

    # - Create capacity limit for outgoing flows with binary is_charging for storage assets
    let table_name = :capacity_outgoing_non_investable_storage_with_binary,
        cons = constraints[table_name]

        indices = _append_capacity_data_to_indices(connection, table_name)

        attach_expression!(
            cons,
            :profile_times_capacity,
            [
                begin
                    availability_agg = _profile_aggregate(
                        profiles.rep_period,
                        (row.profile_name, row.year, row.rep_period),
                        row.time_block_start:row.time_block_end,
                        Statistics.mean,
                        1.0,
                    )
                    @expression(
                        model,
                        availability_agg *
                        row.capacity *
                        accumulated_initial_units[row.asset, row.year] *
                        (1 - is_charging)
                    )
                end for (row, is_charging) in zip(indices, cons.expressions[:is_charging])
            ],
        )
    end

    let table_name = :capacity_outgoing_investable_storage_with_binary,
        cons = constraints[table_name]

        indices = _append_capacity_data_to_indices(connection, table_name)

        attach_expression!(
            cons,
            :profile_times_capacity_with_investment_variable,
            [
                begin
                    availability_agg = _profile_aggregate(
                        profiles.rep_period,
                        (row.profile_name, row.year, row.rep_period),
                        row.time_block_start:row.time_block_end,
                        Statistics.mean,
                        1.0,
                    )
                    @expression(
                        model,
                        availability_agg *
                        row.capacity *
                        (
                            accumulated_initial_units[row.asset, row.year] * (1 - is_charging) +
                            accumulated_investment_units_using_simple_method[row.asset, row.year]
                        )
                    )
                end for (row, is_charging) in zip(indices, cons.expressions[:is_charging])
            ],
        )

        attach_expression!(
            cons,
            :profile_times_capacity_with_investment_limit,
            [
                begin
                    availability_agg = _profile_aggregate(
                        profiles.rep_period,
                        (row.profile_name, row.year, row.rep_period),
                        row.time_block_start:row.time_block_end,
                        Statistics.mean,
                        1.0,
                    )
                    @expression(
                        model,
                        availability_agg *
                        (
                            row.capacity * accumulated_initial_units[row.asset, row.year] +
                            row.investment_limit
                        ) *
                        (1 - is_charging)
                    )
                end for (row, is_charging) in zip(indices, cons.expressions[:is_charging])
            ],
        )
    end

    # - Create capacity limit for incoming flows
    let table_name = :capacity_incoming, cons = constraints[table_name]
        indices = _append_capacity_data_to_indices(connection, table_name)
        attach_expression!(
            cons,
            :profile_times_capacity,
            [
                begin
                    availability_agg = _profile_aggregate(
                        profiles.rep_period,
                        (row.profile_name, row.year, row.rep_period),
                        row.time_block_start:row.time_block_end,
                        Statistics.mean,
                        1.0,
                    )
                    @expression(
                        model,
                        availability_agg *
                        row.capacity *
                        accumulated_units[accumulated_units_lookup[(row.asset, row.year)]]
                    )
                end for row in indices
            ],
        )
    end

    # - Create capacity limit for incoming flows with binary is_charging for storage assets
    let table_name = :capacity_incoming_non_investable_storage_with_binary,
        cons = constraints[table_name]

        indices = _append_capacity_data_to_indices(connection, table_name)

        attach_expression!(
            cons,
            :profile_times_capacity,
            [
                begin
                    availability_agg = _profile_aggregate(
                        profiles.rep_period,
                        (row.profile_name, row.year, row.rep_period),
                        row.time_block_start:row.time_block_end,
                        Statistics.mean,
                        1.0,
                    )
                    @expression(
                        model,
                        availability_agg *
                        row.capacity *
                        accumulated_initial_units[row.asset, row.year] *
                        is_charging
                    )
                end for (row, is_charging) in zip(indices, cons.expressions[:is_charging])
            ],
        )
    end

    let table_name = :capacity_incoming_investable_storage_with_binary,
        cons = constraints[table_name]

        indices = _append_capacity_data_to_indices(connection, table_name)

        attach_expression!(
            cons,
            :profile_times_capacity_with_investment_variable,
            [
                begin
                    availability_agg = _profile_aggregate(
                        profiles.rep_period,
                        (row.profile_name, row.year, row.rep_period),
                        row.time_block_start:row.time_block_end,
                        Statistics.mean,
                        1.0,
                    )
                    @expression(
                        model,
                        availability_agg *
                        row.capacity *
                        (
                            accumulated_initial_units[row.asset, row.year] * is_charging +
                            accumulated_investment_units_using_simple_method[row.asset, row.year]
                        )
                    )
                end for (row, is_charging) in zip(indices, cons.expressions[:is_charging])
            ],
        )

        attach_expression!(
            cons,
            :profile_times_capacity_with_investment_limit,
            [
                begin
                    availability_agg = _profile_aggregate(
                        profiles.rep_period,
                        (row.profile_name, row.year, row.rep_period),
                        row.time_block_start:row.time_block_end,
                        Statistics.mean,
                        1.0,
                    )
                    @expression(
                        model,
                        availability_agg *
                        (
                            row.capacity * accumulated_initial_units[row.asset, row.year] +
                            row.investment_limit
                        ) *
                        is_charging
                    )
                end for (row, is_charging) in zip(indices, cons.expressions[:is_charging])
            ],
        )
    end

    ## Capacity limit constraints (using the highest resolution) for the basic
    # version and the version using binary to avoid charging and discharging at
    # the same time

    for suffix in ("", "_non_investable_storage_with_binary")
        cons_name = Symbol("max_output_flows_limit$suffix")
        table_name = Symbol("capacity_outgoing$suffix")

        # - Maximum output flows limit
        attach_constraint!(
            model,
            constraints[table_name],
            cons_name,
            [
                @constraint(
                    model,
                    outgoing_flow ≤ profile_times_capacity,
                    base_name = "$cons_name[$(row.asset),$(row.year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]"
                ) for (row, outgoing_flow, profile_times_capacity) in zip(
                    eachrow(constraints[table_name].indices),
                    constraints[table_name].expressions[:outgoing],
                    constraints[table_name].expressions[:profile_times_capacity],
                )
            ],
        )
    end

    for suffix in ("_with_investment_variable", "_with_investment_limit")
        cons_name = Symbol("max_output_flows_limit_investable_storage_with_binary_and$suffix")
        table_name = :capacity_outgoing_investable_storage_with_binary

        # - Maximum output flows limit
        attach_constraint!(
            model,
            constraints[table_name],
            cons_name,
            [
                @constraint(
                    model,
                    outgoing_flow ≤ profile_times_capacity,
                    base_name = "$cons_name[$(row.asset),$(row.year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]"
                ) for (row, outgoing_flow, profile_times_capacity) in zip(
                    eachrow(constraints[table_name].indices),
                    constraints[table_name].expressions[:outgoing],
                    constraints[table_name].expressions[Symbol("profile_times_capacity$suffix")],
                )
            ],
        )
    end

    for suffix in ("", "_non_investable_storage_with_binary")
        cons_name = Symbol("max_input_flows_limit$suffix")
        table_name = Symbol("capacity_incoming$suffix")

        # - Maximum input flows limit
        attach_constraint!(
            model,
            constraints[table_name],
            cons_name,
            [
                @constraint(
                    model,
                    incoming_flow ≤ profile_times_capacity,
                    base_name = "$cons_name[$(row.asset),$(row.year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]"
                ) for (row, incoming_flow, profile_times_capacity) in zip(
                    eachrow(constraints[table_name].indices),
                    constraints[table_name].expressions[:incoming],
                    constraints[table_name].expressions[:profile_times_capacity],
                )
            ],
        )
    end

    for suffix in ("_with_investment_variable", "_with_investment_limit")
        cons_name = Symbol("max_input_flows_limit_investable_storage_with_binary_and_$suffix")
        table_name = :capacity_incoming_investable_storage_with_binary

        # - Maximum input flows limit
        attach_constraint!(
            model,
            constraints[table_name],
            cons_name,
            [
                @constraint(
                    model,
                    incoming_flow ≤ profile_times_capacity,
                    base_name = "$cons_name[$(row.asset),$(row.year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]"
                ) for (row, incoming_flow, profile_times_capacity) in zip(
                    eachrow(constraints[table_name].indices),
                    constraints[table_name].expressions[:incoming],
                    constraints[table_name].expressions[Symbol("profile_times_capacity$suffix")],
                )
            ],
        )
    end
end

function _append_capacity_data_to_indices(connection, table_name)
    return DuckDB.query(
        connection,
        "SELECT
            ANY_VALUE(cons.index) AS index,
            ANY_VALUE(cons.asset) AS asset,
            ANY_VALUE(cons.year) AS year,
            ANY_VALUE(cons.rep_period) AS rep_period,
            ANY_VALUE(cons.time_block_start) AS time_block_start,
            ANY_VALUE(cons.time_block_end) AS time_block_end,
            ARRAY_AGG(t_compact.index) AS compact_index,
            ARRAY_AGG(t_compact.commission_year) AS compact_commission_year,
            ANY_VALUE(asset.capacity) AS capacity,
            ANY_VALUE(asset.investment_method) AS investment_method,
            ANY_VALUE(asset_commission.investment_limit) AS investment_limit,
            ANY_VALUE(assets_profiles.profile_name) AS profile_name,
        FROM cons_$table_name AS cons
        LEFT JOIN asset
            ON cons.asset = asset.asset
        LEFT JOIN asset_commission
            ON cons.asset = asset_commission.asset
            AND cons.year = asset_commission.commission_year
        LEFT OUTER JOIN assets_profiles
            ON cons.asset = assets_profiles.asset
            AND cons.year = assets_profiles.commission_year
            AND assets_profiles.profile_type = 'availability'
        LEFT JOIN t_compact
            ON cons.asset = t_compact.asset
            AND cons.year = t_compact.milestone_year
        GROUP BY cons.index
        ORDER BY cons.index
        ",
    )
end
