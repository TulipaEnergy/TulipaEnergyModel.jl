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
    assets_investment_energy = variables[:assets_investment_energy]
    flows_investment = variables[:flows_investment]

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

    constants = (; social_rate, discount_year, end_of_horizon)

    _create_objective_auxiliary_table(connection, constants)

    indices = DuckDB.query(
        connection,
        "SELECT
            var.index,
            t_objective_assets.weight_for_asset_investment_discount
                * t_objective_assets.investment_cost
                * t_objective_assets.capacity AS cost,
        FROM var_assets_investment AS var
        LEFT JOIN t_objective_assets
            ON var.asset = t_objective_assets.asset
            AND var.milestone_year = t_objective_assets.milestone_year
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

    indices = DuckDB.query(
        connection,
        "SELECT
            expr.index,
            t_objective_assets.weight_for_operation_discounts
                * t_objective_assets.fixed_cost
                * t_objective_assets.capacity AS cost,
        FROM expr_accumulated_asset_units AS expr
        LEFT JOIN t_objective_assets
            ON expr.asset = t_objective_assets.asset
            AND expr.milestone_year = t_objective_assets.milestone_year
        ORDER BY
            expr.index
        ",
    )

    assets_fixed_cost = @expression(
        model,
        sum(
            row.cost * acc_unit for
            (row, acc_unit) in zip(indices, expr_accumulated_asset_units.expressions[:assets])
        )
    )

    indices = DuckDB.query(
        connection,
        "SELECT
            var.index,
            t_objective_assets.weight_for_asset_investment_discount
                * t_objective_assets.investment_cost_storage_energy
                * t_objective_assets.capacity_storage_energy AS cost,
        FROM var_assets_investment_energy AS var
        LEFT JOIN t_objective_assets
            ON var.asset = t_objective_assets.asset
            AND var.milestone_year = t_objective_assets.milestone_year
        ORDER BY
            var.index
        ",
    )

    storage_assets_energy_investment_cost = @expression(
        model,
        sum(
            row.cost * assets_investment_energy for
            (row, assets_investment_energy) in zip(indices, assets_investment_energy.container)
        )
    )

    indices = DuckDB.query(
        connection,
        "SELECT
            expr.index,
            t_objective_assets.weight_for_operation_discounts
                * t_objective_assets.fixed_cost_storage_energy
                * t_objective_assets.capacity_storage_energy AS cost,
        FROM expr_accumulated_energy_units AS expr
        LEFT JOIN t_objective_assets
            ON expr.asset = t_objective_assets.asset
            AND expr.milestone_year = t_objective_assets.milestone_year
        ORDER BY
            expr.index
        ",
    )

    storage_assets_energy_fixed_cost = @expression(
        model,
        sum(
            row.cost * acc_unit for
            (row, acc_unit) in zip(indices, expr_accumulated_energy_units.expressions[:energy])
        )
    )

    indices = DuckDB.query(
        connection,
        "SELECT
            var.index,
            t_objective_flows.weight_for_flow_investment_discount
                * t_objective_flows.investment_cost
                * t_objective_flows.capacity AS cost,
        FROM var_flows_investment AS var
        LEFT JOIN t_objective_flows
            ON var.from_asset = t_objective_flows.from_asset
            AND var.to_asset = t_objective_flows.to_asset
            AND var.milestone_year = t_objective_flows.milestone_year
        ORDER BY
            var.index
        ",
    )

    flows_investment_cost = @expression(
        model,
        sum(
            row.cost * flow_investment for
            (row, flow_investment) in zip(indices, flows_investment.container)
        )
    )

    indices = DuckDB.query(
        connection,
        "SELECT
            expr.index,
            t_objective_flows.weight_for_operation_discounts
                * t_objective_flows.fixed_cost / 2
                * t_objective_flows.capacity AS cost,
        FROM expr_accumulated_flow_units AS expr
        LEFT JOIN t_objective_flows
            ON expr.from_asset = t_objective_flows.from_asset
            AND expr.to_asset = t_objective_flows.to_asset
            AND expr.milestone_year = t_objective_flows.milestone_year
        ORDER BY
            expr.index
        ",
    )

    flows_fixed_cost = @expression(
        model,
        sum(
            row.cost * (acc_export_unit + acc_import_unit) for
            (row, acc_export_unit, acc_import_unit) in zip(
                indices,
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

function _create_objective_auxiliary_table(connection, constants)
    DuckDB.execute(
        connection,
        "CREATE OR REPLACE TEMP TABLE t_objective_assets AS
        SELECT
            -- keys
            asset_milestone.asset,
            asset_milestone.milestone_year,
            -- copied over
            asset_commission.investment_cost,
            asset_commission.fixed_cost,
            asset.capacity,
            asset_commission.investment_cost_storage_energy,
            asset_commission.fixed_cost_storage_energy,
            asset.capacity_storage_energy,
            -- computed
            asset.discount_rate / (
                (1 + asset.discount_rate) *
                (1 - 1 / ((1 + asset.discount_rate) ** asset.economic_lifetime))
            ) * asset_commission.investment_cost AS annualized_cost,
            IF(
                asset_milestone.milestone_year + asset.economic_lifetime > $(constants.end_of_horizon) + 1,
                -annualized_cost * (
                    (1 / (1 + asset.discount_rate))^(
                        asset_milestone.milestone_year + asset.economic_lifetime - $(constants.end_of_horizon) - 1
                    ) - 1
                ) / asset.discount_rate,
                0.0
            ) AS salvage_value,
            1 / (1 + $(constants.social_rate))^(asset_milestone.milestone_year - $(constants.discount_year)) AS operation_discount,
            operation_discount * (1 - salvage_value / asset_commission.investment_cost) AS weight_for_asset_investment_discount,
            COALESCE(
                lead(asset_milestone.milestone_year) OVER (PARTITION BY asset_milestone.asset ORDER BY asset_milestone.milestone_year) - asset_milestone.milestone_year,
                1,
            ) AS years_until_next_milestone_year,
            operation_discount * years_until_next_milestone_year AS weight_for_operation_discounts,
        FROM asset_milestone
        LEFT JOIN asset_commission
            ON asset_milestone.asset = asset_commission.asset
            AND asset_milestone.milestone_year = asset_commission.commission_year
        LEFT JOIN asset
            ON asset.asset = asset_commission.asset
        ",
    )

    DuckDB.execute(
        connection,
        "CREATE OR REPLACE TEMP TABLE t_objective_flows AS
        SELECT
            -- keys
            flow_milestone.from_asset,
            flow_milestone.to_asset,
            flow_milestone.milestone_year,
            -- copied over
            flow_commission.investment_cost,
            flow_commission.fixed_cost,
            flow.capacity,
            -- computed
            flow.discount_rate / (
                (1 + flow.discount_rate) *
                (1 - 1 / ((1 + flow.discount_rate) ** flow.economic_lifetime))
            ) * flow_commission.investment_cost AS annualized_cost,
            IF(
                flow_milestone.milestone_year + flow.economic_lifetime > $(constants.end_of_horizon) + 1,
                -annualized_cost * (
                    (1 / (1 + flow.discount_rate))^(
                        flow_milestone.milestone_year + flow.economic_lifetime - $(constants.end_of_horizon) - 1
                    ) - 1
                ) / flow.discount_rate,
                0.0
            ) AS salvage_value,
            1 / (1 + $(constants.social_rate))^(flow_milestone.milestone_year - $(constants.discount_year)) AS operation_discount,
            operation_discount * (1 - salvage_value / flow_commission.investment_cost) AS weight_for_flow_investment_discount,
            COALESCE(
                lead(flow_milestone.milestone_year) OVER (PARTITION BY flow_milestone.from_asset, flow_milestone.to_asset ORDER BY flow_milestone.milestone_year) - flow_milestone.milestone_year,
                1,
            ) AS years_until_next_milestone_year,
            operation_discount * years_until_next_milestone_year AS weight_for_operation_discounts,
        FROM flow_milestone
        LEFT JOIN flow_commission
            ON flow_milestone.from_asset = flow_commission.from_asset
            AND flow_milestone.to_asset = flow_commission.to_asset
            AND flow_milestone.milestone_year = flow_commission.commission_year
        LEFT JOIN flow
            ON flow.from_asset = flow_commission.from_asset
            AND flow.to_asset = flow_commission.to_asset
        ",
    )

    return
end
