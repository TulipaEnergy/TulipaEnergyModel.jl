function add_objective!(
    model,
    variables,
    expressions,
    graph,
    representative_periods,
    sets,
    model_parameters,
)
    assets_investment = variables[:assets_investment].lookup
    assets_investment_energy = variables[:assets_investment_energy].lookup
    flows_investment = variables[:flows_investment].lookup

    expr_accumulated_units = expressions[:accumulated_units]
    expr_accumulated_flow_units = expressions[:accumulated_flow_units]

    # Create a dict of weights for assets investment discounts
    weight_for_assets_investment_discounts =
        calculate_weight_for_investment_discounts(graph, sets.Y, sets.Ai, sets.A, model_parameters)

    # Create a dict of weights for flows investment discounts
    weight_for_flows_investment_discounts =
        calculate_weight_for_investment_discounts(graph, sets.Y, sets.Fi, sets.Ft, model_parameters)

    # Create a dict of intervals for milestone years
    intervals_for_milestone_years = create_intervals_for_years(sets.Y)

    # Create a dict of operation discounts only for milestone years
    operation_discounts_for_milestone_years = Dict(
        y => 1 / (1 + model_parameters.discount_rate)^(y - model_parameters.discount_year) for
        y in sets.Y
    )

    # Create a dict of operation discounts for milestone years including in-between years
    weight_for_operation_discounts = Dict(
        y => operation_discounts_for_milestone_years[y] * intervals_for_milestone_years[y] for
        y in sets.Y
    )

    assets_investment_cost = @expression(
        model,
        sum(
            weight_for_assets_investment_discounts[(y, a)] *
            graph[a].investment_cost[y] *
            graph[a].capacity *
            assets_investment[y, a] for y in sets.Y for a in sets.Ai[y]
        )
    )

    assets_fixed_cost = @expression(
        model,
        sum(
            weight_for_operation_discounts[row.milestone_year] *
            graph[row.asset].fixed_cost[row.milestone_year] *
            graph[row.asset].capacity *
            acc_unit for (row, acc_unit) in zip(
                eachrow(expr_accumulated_units.indices),
                expr_accumulated_units.expressions[:assets],
            )
        )
    )

    storage_assets_energy_investment_cost = @expression(
        model,
        sum(
            weight_for_assets_investment_discounts[(y, a)] *
            graph[a].investment_cost_storage_energy[y] *
            graph[a].capacity_storage_energy *
            assets_investment_energy[y, a] for y in sets.Y for a in sets.Ase[y] ∩ sets.Ai[y]
        )
    )

    storage_assets_energy_fixed_cost = @expression(
        model,
        sum(
            weight_for_operation_discounts[row.milestone_year] *
            graph[row.asset].fixed_cost_storage_energy[row.milestone_year] *
            graph[row.asset].capacity_storage_energy *
            acc_unit for (row, acc_unit) in zip(
                eachrow(expr_accumulated_units.indices),
                expr_accumulated_units.expressions[:assets_energy],
            )
        )
    )

    flows_investment_cost = @expression(
        model,
        sum(
            weight_for_flows_investment_discounts[(y, (u, v))] *
            graph[u, v].investment_cost[y] *
            graph[u, v].capacity *
            flows_investment[y, (u, v)] for y in sets.Y for (u, v) in sets.Fi[y]
        )
    )

    # TODO: Fix this
    # fixed_cost below is not defined for some graph[u, v].fixed[y]
    # This indicates something is not totally right in this definition
    # Probably because the loop is over the accumulated flow units now, and the
    # sets have technically changed
    flows_fixed_cost = @expression(
        model,
        sum(
            weight_for_operation_discounts[row.milestone_year] *
            get(graph[row.from_asset, row.to_asset].fixed_cost, row.milestone_year, 0.0) / 2 *
            graph[row.from_asset, row.to_asset].capacity *
            (acc_export_unit + acc_import_unit) for
            (row, acc_export_unit, acc_import_unit) in zip(
                eachrow(expr_accumulated_flow_units.indices),
                expr_accumulated_flow_units.expressions[:export],
                expr_accumulated_flow_units.expressions[:import],
            )
        )
    )

    flows_variable_cost = @expression(
        model,
        sum(
            weight_for_operation_discounts[row.year] *
            representative_periods[row.year][row.rep_period].weight *
            duration(
                row.time_block_start:row.time_block_end,
                row.rep_period,
                representative_periods[row.year],
            ) *
            graph[row.from, row.to].variable_cost[row.year] *
            flow for
            (flow, row) in zip(variables[:flow].container, eachrow(variables[:flow].indices))
        )
    )

    units_on_cost = @expression(
        model,
        sum(
            weight_for_operation_discounts[row.year] *
            representative_periods[row.year][row.rep_period].weight *
            duration(
                row.time_block_start:row.time_block_end,
                row.rep_period,
                representative_periods[row.year],
            ) *
            graph[row.asset].units_on_cost[row.year] *
            units_on for (units_on, row) in
            zip(variables[:units_on].container, eachrow(variables[:units_on].indices)) if
            !ismissing(graph[row.asset].units_on_cost[row.year])
        )
    )

    ## Objective function
    @objective(
        model,
        Min,
        assets_investment_cost +
        assets_fixed_cost +
        storage_assets_energy_investment_cost +
        storage_assets_energy_fixed_cost +
        flows_investment_cost +
        flows_fixed_cost +
        flows_variable_cost +
        units_on_cost
    )
end
