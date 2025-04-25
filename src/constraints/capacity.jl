export add_capacity_constraints!

"""
    add_capacity_constraints!(connection, model, expressions, constraints, profiles)

Adds the capacity constraints for all asset types to the model
"""
function add_capacity_constraints!(connection, model, expressions, constraints, profiles)
    ## unpack from expressions
    expr_avail_compact_method =
        expressions[:available_asset_units_compact_method].expressions[:assets]
    expr_avail_simple_method =
        expressions[:available_asset_units_simple_method].expressions[:assets]

    ## Expressions used by capacity constraints
    # - Create capacity limit for outgoing flows
    # - Compact investment method
    let table_name = :capacity_outgoing_compact_method, cons = constraints[table_name]
        indices = _append_capacity_data_to_indices_compact_method(connection, table_name)
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
                                availability_agg * expr_avail_compact_method[avail_id]
                            end for (avail_profile_name, avail_id) in
                            zip(row.avail_profile_name, row.avail_indices)
                        )
                    )
                end for row in indices
            ],
        )
    end

    # - Simple investment method
    let table_name = :capacity_outgoing_simple_method, cons = constraints[table_name]
        indices = _append_capacity_data_to_indices_simple_method(connection, table_name)

        attach_expression!(
            cons,
            :profile_times_capacity,
            [
                @expression(
                    model,
                    row.capacity *
                    _profile_aggregate(
                        profiles.rep_period,
                        (row.profile_name, row.year, row.rep_period),
                        row.time_block_start:row.time_block_end,
                        Statistics.mean,
                        1.0,
                    ) *
                    expr_avail_simple_method[row.avail_id]
                ) for row in indices
            ],
        )
    end

    # - Create capacity limit for outgoing flows with binary is_charging for storage assets
    let table_name = :capacity_outgoing_simple_method_non_investable_storage_with_binary,
        cons = constraints[table_name]

        indices = _append_capacity_data_to_indices_simple_method(connection, table_name)

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

    let table_name = :capacity_outgoing_simple_method_investable_storage_with_binary,
        cons = constraints[table_name]

        indices = _append_capacity_data_to_indices_simple_method(connection, table_name)

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
                            expr_avail_simple_method[row.avail_id]
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
    let table_name = :capacity_incoming_simple_method, cons = constraints[table_name]
        indices = _append_capacity_data_to_indices_simple_method(connection, table_name)
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
                        availability_agg * row.capacity * expr_avail_simple_method[row.avail_id]
                    )
                end for row in indices
            ],
        )
    end

    # - Create capacity limit for incoming flows with binary is_charging for storage assets
    let table_name = :capacity_incoming_simple_method_non_investable_storage_with_binary,
        cons = constraints[table_name]

        indices = _append_capacity_data_to_indices_simple_method(connection, table_name)

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

    let table_name = :capacity_incoming_simple_method_investable_storage_with_binary,
        cons = constraints[table_name]

        indices = _append_capacity_data_to_indices_simple_method(connection, table_name)

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
                            expr_avail_simple_method[row.avail_id]
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

    for suffix in
        ("_compact_method", "_simple_method", "_simple_method_non_investable_storage_with_binary")
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
        cons_name =
            Symbol("max_output_flows_limit_simple_method_investable_storage_with_binary_and$suffix")
        table_name = :capacity_outgoing_simple_method_investable_storage_with_binary

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

    for suffix in ("_simple_method", "_simple_method_non_investable_storage_with_binary")
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
        cons_name =
            Symbol("max_input_flows_limit_simple_method_investable_storage_with_binary_and_$suffix")
        table_name = :capacity_incoming_simple_method_investable_storage_with_binary

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

    cons_name = Symbol("min_output_flows_limit_for_transport_flows_without_unit_commitment")
    table_name = :min_outgoing_flow_for_transport_flows_without_unit_commitment

    # - Minmum output flows limit if any of the flows is transport flow
    # - This allows negative flows but not all negative flows, so flows can pass through this asset
    # - Holds for producers, conversion and storage assets
    attach_constraint!(
        model,
        constraints[table_name],
        cons_name,
        [
            @constraint(
                model,
                outgoing_flow ≥ 0,
                base_name = "$cons_name[$(row.asset),$(row.year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]"
            ) for (row, outgoing_flow) in
            zip(constraints[table_name].indices, constraints[table_name].expressions[:outgoing])
        ],
    )

    # - Minmum input flows limit if any of the flows is transport flow
    # - This allows negative flows but not all negative flows, so flows can pass through this asset
    # - Holds for onversion and storage assets
    cons_name = Symbol("min_input_flows_limit_for_transport_flows")
    table_name = :min_incoming_flow_for_transport_flows

    attach_constraint!(
        model,
        constraints[table_name],
        cons_name,
        [
            @constraint(
                model,
                incoming_flow ≥ 0,
                base_name = "$cons_name[$(row.asset),$(row.year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]"
            ) for (row, incoming_flow) in
            zip(constraints[table_name].indices, constraints[table_name].expressions[:incoming])
        ],
    )

    return
end

# The below two functions are very similar
# - The compact method selects the compact investment method
# - and aggregates the available capacity indices
function _append_capacity_data_to_indices_compact_method(connection, table_name)
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
        LEFT JOIN expr_available_asset_units_compact_method AS expr_avail
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
        WHERE asset.investment_method = 'compact'
        GROUP BY cons.id
        ORDER BY cons.id
        ",
    )
end

# - The simple method selects the simple or the none investment method
# - and do not aggregate the available capacity indices, because there will be only 1.
# - It is a choice the the none method takes the simple formulation (can also take the compact formulation)
function _append_capacity_data_to_indices_simple_method(connection, table_name)
    return DuckDB.query(
        connection,
        "SELECT
            cons.id AS id,
            cons.asset AS asset,
            cons.year AS year,
            cons.rep_period AS rep_period,
            cons.time_block_start AS time_block_start,
            cons.time_block_end AS time_block_end,
            expr_avail.id AS avail_id,
            expr_avail.initial_units AS avail_initial_units,
            avail_profile.profile_name AS avail_profile_name,
            asset.capacity AS capacity,
            asset.investment_method AS investment_method,
            asset_commission.investment_limit AS investment_limit,
            assets_profiles.profile_name AS profile_name,
        FROM cons_$table_name AS cons
        LEFT JOIN asset
            ON cons.asset = asset.asset
        LEFT JOIN asset_commission
            ON cons.asset = asset_commission.asset
            AND cons.year = asset_commission.commission_year
        LEFT JOIN expr_available_asset_units_simple_method AS expr_avail
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
        WHERE asset.investment_method in ('simple', 'none')
        ORDER BY cons.id
        ",
    )
end
