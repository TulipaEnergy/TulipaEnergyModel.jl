export add_capacity_constraints!

"""
    add_capacity_constraints!(connection, model, expressions, constraints, profiles)

Adds the capacity constraints for all asset types to the model
"""
function add_capacity_constraints!(connection, model, expressions, constraints, profiles)
    ## unpack from expressions
    expr_avail = expressions[:available_asset_units].expressions[:assets]

    ## Expressions used by capacity constraints
    # - Create capacity limit for outgoing flows
    let table_name = :capacity_outgoing, cons = constraints[table_name]
        indices = _append_capacity_data_to_indices(connection, table_name)

        attach_expression!(
            cons,
            :profile_times_capacity,
            [
                begin
                    @expression(
                        model,
                        row.capacity * sum(
                            begin
                                availability_agg = _profile_aggregate(
                                    profiles.rep_period,
                                    (avail_profile_name, row.year, row.rep_period),
                                    row.time_block_start:row.time_block_end,
                                    Statistics.mean,
                                    1.0,
                                )
                                availability_agg * expr_avail[avail_id]
                            end for (avail_profile_name, avail_id) in
                            zip(row.avail_profile_name, row.avail_indices)
                        )
                    )
                end for row in indices
            ],
        )
    end

    expr_avail_simple_investment =
        expressions[:available_asset_units_simple_investment].expressions[:assets]

    let table_name = :capacity_outgoing_simple_investment, cons = constraints[table_name]
        indices = _append_capacity_data_to_indices_simple_investment(connection, table_name)

        attach_expression!(
            cons,
            :profile_times_capacity,
            [
                @expression(
                    model,
                    row.capacity *
                    _profile_aggregate(
                        profiles.rep_period,
                        (row.avail_profile_name, row.year, row.rep_period),
                        row.time_block_start:row.time_block_end,
                        Statistics.mean,
                        1.0,
                    ) *
                    expr_avail_simple_investment[row.avail_indices]
                ) for row in indices
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
                        row.avail_initial_units *
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
                            row.avail_initial_units * (1 - is_charging) +
                            sum(expr_avail[avail_id] for avail_id in row.avail_indices)
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
                        (row.capacity * row.avail_initial_units + row.investment_limit) *
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
                        sum(expr_avail[avail_id] for avail_id in row.avail_indices)
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
                        availability_agg * row.capacity * row.avail_initial_units * is_charging
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
                            row.avail_initial_units * is_charging +
                            sum(expr_avail[avail_id] for avail_id in row.avail_indices)
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
                        (row.capacity * row.avail_initial_units + row.investment_limit) *
                        is_charging
                    )
                end for (row, is_charging) in zip(indices, cons.expressions[:is_charging])
            ],
        )
    end

    ## Capacity limit constraints (using the highest resolution) for the basic
    # version and the version using binary to avoid charging and discharging at
    # the same time

    for suffix in ("", "_non_investable_storage_with_binary", "_simple_investment")
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
                    constraints[table_name].indices,
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
                    constraints[table_name].indices,
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
                    constraints[table_name].indices,
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
                    constraints[table_name].indices,
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
            ANY_VALUE(cons.id) AS id,
            ANY_VALUE(cons.asset) AS asset,
            ANY_VALUE(cons.year) AS year,
            ANY_VALUE(cons.rep_period) AS rep_period,
            ANY_VALUE(cons.time_block_start) AS time_block_start,
            ANY_VALUE(cons.time_block_end) AS time_block_end,
            ARRAY_AGG(expr_avail.id) AS avail_indices,
            ARRAY_AGG(expr_avail.commission_year) AS avail_commission_year,
            SUM(expr_avail.initial_units) AS avail_initial_units,
            ARRAY_AGG(avail_profile.profile_name) AS avail_profile_name,
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
        LEFT JOIN expr_available_asset_units AS expr_avail
            ON cons.asset = expr_avail.asset
            AND cons.year = expr_avail.milestone_year
        LEFT OUTER JOIN assets_profiles
            ON cons.asset = assets_profiles.asset
            AND cons.year = assets_profiles.commission_year
            AND assets_profiles.profile_type = 'availability'
        LEFT OUTER JOIN assets_profiles AS avail_profile
            ON cons.asset = avail_profile.asset
            AND expr_avail.commission_year = avail_profile.commission_year
            AND avail_profile.profile_type = 'availability'
        GROUP BY cons.id
        ORDER BY cons.id
        ",
    )
end

function _append_capacity_data_to_indices_simple_investment(connection, table_name)
    return DuckDB.query(
        connection,
        "SELECT
            cons.id AS id,
            cons.asset AS asset,
            cons.year AS year,
            cons.rep_period AS rep_period,
            cons.time_block_start AS time_block_start,
            cons.time_block_end AS time_block_end,
            expr_avail.id AS avail_indices,
            expr_avail.initial_units AS avail_initial_units,
            avail_profile.profile_name AS avail_profile_name,
            asset.capacity AS capacity,
            asset_milestone_simple_investment.investment_limit AS investment_limit,
        FROM cons_$table_name AS cons
        LEFT JOIN asset
            ON cons.asset = asset.asset
        LEFT JOIN asset_milestone_simple_investment
            ON cons.asset = asset_milestone_simple_investment.asset
            AND cons.year = asset_milestone_simple_investment.milestone_year
        LEFT JOIN expr_available_asset_units_simple_investment AS expr_avail
            ON cons.asset = expr_avail.asset
        -- Is it possible to not have milestone_year in this table? It is redundant because year is available in profiles_rep_periods, see the try below
            AND cons.year = expr_avail.milestone_year
        LEFT JOIN assets_profiles_simple_investment AS avail_profile
            ON cons.asset = avail_profile.asset
            AND cons.year = avail_profile.milestone_year
            AND avail_profile.profile_type = 'availability'
        -- Below does not work yet, if it does, milestone_year can be removed from avail_profile
        /*
        LEFT JOIN profiles_rep_periods AS profiles
            ON avail_profile.profile_name = profiles.profile_name
            AND cons.year = profiles.year
        */
        ORDER BY cons.id
        ",
    )
end
