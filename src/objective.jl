function add_objective!(model, variables, graph, representative_periods, sets, model_parameters)
    assets_investment = variables[:assets_investment].lookup
    # accumulated_units_simple_method = model[:accumulated_units_simple_method]
    # accumulated_units_compact_method = model[:accumulated_units_compact_method]
    assets_investment_energy = variables[:assets_investment_energy].lookup
    # accumulated_energy_units_simple_method = model[:accumulated_energy_units_simple_method]
    flows_investment = variables[:flows_investment].lookup
    accumulated_flows_export_units = model[:accumulated_flows_export_units]
    accumulated_flows_import_units = model[:accumulated_flows_import_units]

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
        0.0
        # sum(
        #     weight_for_operation_discounts[y] *
        #     graph[a].fixed_cost[y] *
        #     graph[a].capacity *
        #     accumulated_units_simple_method[a, y] for y in sets.Y for
        #     a in sets.decommissionable_assets_using_simple_method
        # ) + sum(
        #     weight_for_operation_discounts[y] * graph[a].fixed_cost[v] * graph[a].capacity * accm for (accm, (a, y, v)) in
        #     zip(accumulated_units_compact_method, sets.accumulated_set_using_compact_method)
        # )
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
            weight_for_operation_discounts[y] *
            graph[a].fixed_cost_storage_energy[y] *
            graph[a].capacity_storage_energy *
            accumulated_energy_units_simple_method[y, a] for y in sets.Y for
            a in sets.Ase[y] ∩ sets.decommissionable_assets_using_simple_method
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

    flows_fixed_cost = @expression(
        model,
        sum(
            weight_for_operation_discounts[y] * graph[u, v].fixed_cost[y] / 2 *
            graph[u, v].capacity *
            (accumulated_flows_export_units[y, (u, v)] + accumulated_flows_import_units[y, (u, v)]) for y in sets.Y for (u, v) in sets.Fi[y]
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
