export add_capacity_constraints!

"""
add_capacity_constraints!(model, graph,...)

Adds the capacity constraints for all asset types to the model
"""
function add_capacity_constraints!(connection, model, expressions, constraints, profiles)
    ## unpack from expressions
    expr_acc = expressions[:accumulated_asset_units].expressions[:assets]

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
                            _profile_aggregate(
                                profiles.rep_period,
                                row.time_block_start:row.time_block_end,
                                (acc_profile_name, row.year, row.rep_period),
                                Statistics.mean,
                                1.0,
                            ) * expr_acc[acc_index] for (acc_profile_name, acc_index) in
                            zip(row.acc_profile_name, row.acc_indices)
                        )
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
                        availability_agg * row.capacity * row.acc_initial_units * (1 - is_charging)
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
                            row.acc_initial_units * (1 - is_charging) +
                            sum(expr_acc[acc_index] for acc_index in row.acc_indices)
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
                        (row.capacity * row.acc_initial_units + row.investment_limit) *
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
                        sum(expr_acc[acc_index] for acc_index in row.acc_indices)
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
                        availability_agg * row.capacity * row.acc_initial_units * is_charging
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
                            row.acc_initial_units * is_charging +
                            sum(expr_acc[acc_index] for acc_index in row.acc_indices)
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
                        (row.capacity * row.acc_initial_units + row.investment_limit) *
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
            ARRAY_AGG(expr_acc.index) AS acc_indices,
            ARRAY_AGG(expr_acc.commission_year) AS acc_commission_year,
            SUM(expr_acc.initial_units) AS acc_initial_units,
            ARRAY_AGG(acc_profile.profile_name) AS acc_profile_name,
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
        LEFT JOIN expr_accumulated_asset_units AS expr_acc
            ON cons.asset = expr_acc.asset
            AND cons.year = expr_acc.milestone_year
        LEFT OUTER JOIN assets_profiles
            ON cons.asset = assets_profiles.asset
            AND cons.year = assets_profiles.commission_year
            AND assets_profiles.profile_type = 'availability'
        LEFT OUTER JOIN assets_profiles AS acc_profile
            ON expr_acc.asset = acc_profile.asset
            AND expr_acc.commission_year = acc_profile.commission_year
            AND assets_profiles.profile_type = 'availability'
        GROUP BY cons.index
        ORDER BY cons.index
        ",
    )
end
