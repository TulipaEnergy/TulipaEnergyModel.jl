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
    accumulated_units_compact_method = model[:accumulated_units_compact_method]

    ## unpack from variables
    flows_indices = variables[:flow].indices
    flow = variables[:flow].container

    ## Expressions used by capacity constraints
    # - Create capacity limit for outgoing flows
    let table_name = :capacity_outgoing, cons = constraints[table_name]
        indices = _append_data_to_indices(connection, table_name)
        attach_expression!(
            cons,
            :profile_times_capacity,
            [
                if row.asset ∈ decommissionable_assets_using_compact_method
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
                            ) *
                            accumulated_units_compact_method[accumulated_set_using_compact_method_lookup[(
                                row.asset,
                                row.year,
                                v,
                            )]] for v in V_all if
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

        indices = _append_data_to_indices(connection, table_name)

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

        indices = _append_data_to_indices(connection, table_name)

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
        indices = _append_data_to_indices(connection, table_name)
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

        indices = _append_data_to_indices(connection, table_name)

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

        indices = _append_data_to_indices(connection, table_name)

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

function _append_data_to_indices(connection, table_name)
    return DuckDB.query(
        connection,
        "SELECT
            cons.*,
            asset.capacity,
            asset_commission.investment_limit,
            assets_profiles.profile_name
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
        ORDER BY cons.index
        ",
    )
end
