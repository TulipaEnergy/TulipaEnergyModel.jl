function add_objective!(
    connection,
    model,
    variables,
    expressions,
    graph,
    representative_periods,
    sets,
    model_parameters,
)
    assets_investment = variables[:assets_investment]
    assets_investment_energy = variables[:assets_investment_energy].lookup
    flows_investment = variables[:flows_investment].lookup

    expr_accumulated_asset_units = expressions[:accumulated_asset_units]
    expr_accumulated_energy_units = expressions[:accumulated_energy_units]
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

    my_sort(D) = sort(D; by = key -> (key[2], key[1]))

    # @info "weight for assets" my_sort(weight_for_assets_investment_discounts)
    # @info "intervals" sort(intervals_for_milestone_years)
    # @info "op discount" sort(operation_discounts_for_milestone_years)
    # @info "weight for op" sort(weight_for_operation_discounts)

    # @show my_sort(weight_for_flows_investment_discounts)

    # @show assets_investment_cost

    social_rate = model_parameters.discount_rate
    discount_year = model_parameters.discount_year
    end_of_horizon = only([
        row[1] for row in
        DuckDB.query(connection, "SELECT MAX(year) AS end_of_horizon FROM rep_periods_data")
    ])

    indices = DuckDB.query(
        connection,
        "SELECT
            var.index,
            var.asset,
            var.milestone_year,
            asset.discount_rate / (
                (1 + asset.discount_rate) *
                (1 - 1 / ((1 + asset.discount_rate) ** asset.economic_lifetime))
            ) * asset_commission.investment_cost AS annualized_cost,
            IF(
                var.milestone_year + asset.economic_lifetime > $end_of_horizon + 1,
                -annualized_cost * (
                    (1 / (1 + asset.discount_rate))^(
                        var.milestone_year + asset.economic_lifetime - $end_of_horizon - 1
                    ) - 1
                ) / asset.discount_rate,
                0.0
            ) AS salvage_value,
            1 / (1 + $social_rate)^(var.milestone_year - $discount_year) AS operation_discount,
            operation_discount * (1 - salvage_value / asset_commission.investment_cost) AS weight_for_asset_investment_discount,
            COALESCE(
                lead(var.milestone_year) OVER (PARTITION BY var.asset ORDER BY var.milestone_year) - var.milestone_year,
                1,
            ) AS years_until_next_milestone_year,
            weight_for_asset_investment_discount * asset_commission.investment_cost * asset.capacity AS cost,

            -- weight_for_asset_investment_discount * years_until_next_milestone_year AS weight_for_operation_discounts,
        FROM var_assets_investment AS var
        LEFT JOIN asset_commission
            ON var.asset = asset_commission.asset
            AND var.milestone_year = asset_commission.commission_year
        LEFT JOIN asset
            ON asset.asset = asset_commission.asset
        ORDER BY
            var.index
        ",
    )

    assets_investment_cost = @expression(
        model,
        sum(
            row.cost * asset_investment for
            (row, asset_investment) in zip(indices, assets_investment.container)
        )
    )

    assets_fixed_cost = @expression(
        model,
        sum(
            weight_for_operation_discounts[row.milestone_year] *
            graph[row.asset].fixed_cost[row.milestone_year] *
            graph[row.asset].capacity *
            acc_unit for (row, acc_unit) in zip(
                eachrow(expr_accumulated_asset_units.indices),
                expr_accumulated_asset_units.expressions[:assets],
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
                eachrow(expr_accumulated_energy_units.indices),
                expr_accumulated_energy_units.expressions[:energy],
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
