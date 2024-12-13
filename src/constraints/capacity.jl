export add_capacity_constraints!

"""
add_capacity_constraints!(model, graph,...)

Adds the capacity constraints for all asset types to the model
"""

function add_capacity_constraints!(model, variables, constraints, graph, sets)
    ## unpack from sets
    Acv = sets[:Acv]
    Ai = sets[:Ai]
    Ap = sets[:Ap]
    As = sets[:As]
    Asb = sets[:Asb]
    V_all = sets[:V_all]
    Y = sets[:Y]
    accumulated_set_using_compact_method = sets[:accumulated_set_using_compact_method]
    accumulated_set_using_compact_method_lookup = sets[:accumulated_set_using_compact_method_lookup]
    accumulated_units_lookup = sets[:accumulated_units_lookup]
    decommissionable_assets_using_compact_method =
        sets[:decommissionable_assets_using_compact_method]
    decommissionable_assets_using_simple_method = sets[:decommissionable_assets_using_simple_method]

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
    attach_expression!(
        constraints[:capacity_outgoing],
        :profile_times_capacity,
        [
            if row.asset ∈ decommissionable_assets_using_compact_method
                @expression(
                    model,
                    graph[row.asset].capacity * sum(
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
                @expression(
                    model,
                    profile_aggregation(
                        Statistics.mean,
                        graph[row.asset].rep_periods_profiles,
                        row.year,
                        row.year,
                        ("availability", row.rep_period),
                        row.time_block_start:row.time_block_end,
                        1.0,
                    ) *
                    graph[row.asset].capacity *
                    accumulated_units[accumulated_units_lookup[(row.asset, row.year)]]
                )
            end for row in eachrow(constraints[:capacity_outgoing].indices)
        ],
    )

    # - Create accumulated investment limit for the use of binary storage method with investments
    accumulated_investment_limit = @expression(
        model,
        accumulated_investment_limit[y in Y, a in Ai[y]∩Asb],
        graph[a].investment_limit[y]
    )

    # - Create capacity limit for outgoing flows with binary is_charging for storage assets
    attach_expression!(
        constraints[:capacity_outgoing_storage_with_binary],
        :profile_times_capacity,
        [
            @expression(
                model,
                profile_aggregation(
                    Statistics.mean,
                    graph[row.asset].rep_periods_profiles,
                    row.year,
                    row.year,
                    ("availability", row.rep_period),
                    row.time_block_start:row.time_block_end,
                    1.0,
                ) *
                (graph[row.asset].capacity * accumulated_initial_units[row.asset, row.year]) *
                (1 - is_charging)
            ) for (row, is_charging) in zip(
                eachrow(constraints[:capacity_outgoing_storage_with_binary].indices),
                constraints[:capacity_outgoing_storage_with_binary].expressions[:is_charging],
            )
        ],
    )

    attach_expression!(
        constraints[:capacity_outgoing_investable_storage_with_binary],
        :profile_times_capacity,
        [
            @expression(
                model,
                profile_aggregation(
                    Statistics.mean,
                    graph[row.asset].rep_periods_profiles,
                    row.year,
                    row.year,
                    ("availability", row.rep_period),
                    row.time_block_start:row.time_block_end,
                    1.0,
                ) * (
                    graph[row.asset].capacity * (
                        accumulated_initial_units[row.asset, row.year] * (1 - is_charging) +
                        accumulated_investment_units_using_simple_method[row.asset, row.year]
                    )
                )
            ) for (row, is_charging) in zip(
                eachrow(constraints[:capacity_outgoing_investable_storage_with_binary].indices),
                constraints[:capacity_outgoing_investable_storage_with_binary].expressions[:is_charging],
            )
        ],
    )

    attach_expression!(
        constraints[:capacity_outgoing_investable_storage_limit_with_binary],
        :profile_times_capacity,
        [
            @expression(
                model,
                profile_aggregation(
                    Statistics.mean,
                    graph[row.asset].rep_periods_profiles,
                    row.year,
                    row.year,
                    ("availability", row.rep_period),
                    row.time_block_start:row.time_block_end,
                    1.0,
                ) *
                (
                    graph[row.asset].capacity * accumulated_initial_units[row.asset, row.year] +
                    accumulated_investment_limit[row.year, row.asset]
                ) *
                (1 - is_charging)
            ) for (row, is_charging) in zip(
                eachrow(
                    constraints[:capacity_outgoing_investable_storage_limit_with_binary].indices,
                ),
                constraints[:capacity_outgoing_investable_storage_limit_with_binary].expressions[:is_charging],
            )
        ],
    )

    # - Create capacity limit for incoming flows
    attach_expression!(
        constraints[:capacity_incoming],
        :profile_times_capacity,
        [
            @expression(
                model,
                profile_aggregation(
                    Statistics.mean,
                    graph[row.asset].rep_periods_profiles,
                    row.year,
                    row.year,
                    ("availability", row.rep_period),
                    row.time_block_start:row.time_block_end,
                    1.0,
                ) *
                graph[row.asset].capacity *
                accumulated_units[accumulated_units_lookup[(row.asset, row.year)]]
            ) for row in eachrow(constraints[:capacity_incoming].indices)
        ],
    )

    # - Create capacity limit for incoming flows with binary is_charging for storage assets
    attach_expression!(
        constraints[:capacity_incoming_storage_with_binary],
        :profile_times_capacity,
        [
            @expression(
                model,
                profile_aggregation(
                    Statistics.mean,
                    graph[row.asset].rep_periods_profiles,
                    row.year,
                    row.year,
                    ("availability", row.rep_period),
                    row.time_block_start:row.time_block_end,
                    1.0,
                ) *
                (graph[row.asset].capacity * accumulated_initial_units[row.asset, row.year]) *
                is_charging
            ) for (row, is_charging) in zip(
                eachrow(constraints[:capacity_incoming_storage_with_binary].indices),
                constraints[:capacity_incoming_storage_with_binary].expressions[:is_charging],
            )
        ],
    )

    attach_expression!(
        constraints[:capacity_incoming_investable_storage_with_binary],
        :profile_times_capacity,
        [
            @expression(
                model,
                profile_aggregation(
                    Statistics.mean,
                    graph[row.asset].rep_periods_profiles,
                    row.year,
                    row.year,
                    ("availability", row.rep_period),
                    row.time_block_start:row.time_block_end,
                    1.0,
                ) * (
                    graph[row.asset].capacity * (
                        accumulated_initial_units[row.asset, row.year] * is_charging +
                        accumulated_investment_units_using_simple_method[row.asset, row.year]
                    )
                )
            ) for (row, is_charging) in zip(
                eachrow(constraints[:capacity_incoming_investable_storage_with_binary].indices),
                constraints[:capacity_incoming_investable_storage_with_binary].expressions[:is_charging],
            )
        ],
    )

    attach_expression!(
        constraints[:capacity_incoming_investable_storage_limit_with_binary],
        :profile_times_capacity,
        [
            @expression(
                model,
                profile_aggregation(
                    Statistics.mean,
                    graph[row.asset].rep_periods_profiles,
                    row.year,
                    row.year,
                    ("availability", row.rep_period),
                    row.time_block_start:row.time_block_end,
                    1.0,
                ) *
                (
                    graph[row.asset].capacity * accumulated_initial_units[row.asset, row.year] +
                    accumulated_investment_limit[row.year, row.asset]
                ) *
                is_charging
            ) for (row, is_charging) in zip(
                eachrow(
                    constraints[:capacity_incoming_investable_storage_limit_with_binary].indices,
                ),
                constraints[:capacity_incoming_investable_storage_limit_with_binary].expressions[:is_charging],
            )
        ],
    )

    ## Capacity limit constraints (using the highest resolution) for the basic
    # version and the version using binary to avoid charging and discharging at
    # the same time

    for suffix in (
        "",
        "_storage_with_binary",
        "_investable_storage_with_binary",
        "_investable_storage_limit_with_binary",
    )
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

    for suffix in (
        "",
        "_storage_with_binary",
        "_investable_storage_with_binary",
        "_investable_storage_limit_with_binary",
    )
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

    # - Lower limit for flows associated with assets
    assets_with_non_negative_flows_indices = DataFrames.subset(
        flows_indices,
        [:from, :to] => DataFrames.ByRow(
            (from, to) -> from in Ap || from in Acv || from in As || to in Acv || to in As,
        ),
    )
    for row in eachrow(assets_with_non_negative_flows_indices)
        JuMP.set_lower_bound(flow[row.index], 0.0)
    end
end
