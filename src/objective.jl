function add_objective!(connection, model, variables, expressions, model_parameters)
    assets_investment = variables[:assets_investment]
    assets_investment_energy = variables[:assets_investment_energy]
    flows_investment = variables[:flows_investment]

    expr_available_asset_units_compact_method = expressions[:available_asset_units_compact_method]
    expr_available_asset_units_simple_method = expressions[:available_asset_units_simple_method]
    expr_available_energy_units_simple_method = expressions[:available_energy_units_simple_method]
    expr_available_flow_units_simple_method = expressions[:available_flow_units_simple_method]

    social_rate = model_parameters.discount_rate
    discount_year = model_parameters.discount_year
    end_of_horizon = get_single_element_from_query_and_ensure_its_only_one(
        DuckDB.query(connection, "SELECT MAX(year) AS end_of_horizon FROM rep_periods_data"),
    )

    constants = (; social_rate, discount_year, end_of_horizon)

    _create_objective_auxiliary_table(connection, constants)

    indices = DuckDB.query(
        connection,
        "SELECT
            var.id,
            t_objective_assets.weight_for_asset_investment_discount
                * t_objective_assets.investment_cost
                * t_objective_assets.capacity
                AS cost,
        FROM var_assets_investment AS var
        LEFT JOIN t_objective_assets
            ON var.asset = t_objective_assets.asset
            AND var.milestone_year = t_objective_assets.milestone_year
        ORDER BY
            var.id
        ",
    )

    assets_investment_cost = @expression(
        model,
        sum(
            row.cost * asset_investment for
            (row, asset_investment) in zip(indices, assets_investment.container)
        )
    )

    # Select expressions for compact method
    indices = DuckDB.query(
        connection,
        "SELECT
            expr.id,
            t_objective_assets.weight_for_operation_discounts
                * asset_commission.fixed_cost
                * t_objective_assets.capacity
                AS cost,
        FROM expr_available_asset_units_compact_method AS expr
        LEFT JOIN asset_commission
            ON expr.asset = asset_commission.asset
            AND expr.commission_year = asset_commission.commission_year
        LEFT JOIN t_objective_assets
            ON expr.asset = t_objective_assets.asset
            AND expr.milestone_year = t_objective_assets.milestone_year
        ORDER BY
            expr.id
        ",
    )

    assets_fixed_cost_compact_method = @expression(
        model,
        sum(
            row.cost * expr_avail for (row, expr_avail) in
            zip(indices, expr_available_asset_units_compact_method.expressions[:assets])
        )
    )

    # Select expressions for simple method
    indices = DuckDB.query(
        connection,
        "SELECT
            expr.id,
            t_objective_assets.weight_for_operation_discounts
                * asset_commission.fixed_cost
                * t_objective_assets.capacity
                AS cost,
        FROM expr_available_asset_units_simple_method AS expr
        LEFT JOIN asset_commission
            ON expr.asset = asset_commission.asset
            AND expr.commission_year = asset_commission.commission_year
        LEFT JOIN t_objective_assets
            ON expr.asset = t_objective_assets.asset
            AND expr.milestone_year = t_objective_assets.milestone_year
        ORDER BY
            expr.id
        ",
    )

    assets_fixed_cost_simple_method = @expression(
        model,
        sum(
            row.cost * expr_avail for (row, expr_avail) in
            zip(indices, expr_available_asset_units_simple_method.expressions[:assets])
        )
    )

    indices = DuckDB.query(
        connection,
        "SELECT
            var.id,
            t_objective_assets.weight_for_asset_investment_discount
                * t_objective_assets.investment_cost_storage_energy
                * t_objective_assets.capacity_storage_energy
                AS cost,
        FROM var_assets_investment_energy AS var
        LEFT JOIN t_objective_assets
            ON var.asset = t_objective_assets.asset
            AND var.milestone_year = t_objective_assets.milestone_year
        ORDER BY
            var.id
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
            expr.id,
            t_objective_assets.weight_for_operation_discounts
                * asset_commission.fixed_cost_storage_energy
                * t_objective_assets.capacity_storage_energy
                AS cost,
        FROM expr_available_energy_units_simple_method AS expr
        LEFT JOIN asset_commission
            ON expr.asset = asset_commission.asset
            AND expr.commission_year = asset_commission.commission_year
        LEFT JOIN t_objective_assets
            ON expr.asset = t_objective_assets.asset
            AND expr.milestone_year = t_objective_assets.milestone_year
        ORDER BY
            expr.id
        ",
    )

    storage_assets_energy_fixed_cost = @expression(
        model,
        sum(
            row.cost * expr_avail for (row, expr_avail) in
            zip(indices, expr_available_energy_units_simple_method.expressions[:energy])
        )
    )

    indices = DuckDB.query(
        connection,
        "SELECT
            var.id,
            t_objective_flows.weight_for_flow_investment_discount
                * t_objective_flows.investment_cost
                * t_objective_flows.capacity
                AS cost,
        FROM var_flows_investment AS var
        LEFT JOIN t_objective_flows
            ON var.from_asset = t_objective_flows.from_asset
            AND var.to_asset = t_objective_flows.to_asset
            AND var.milestone_year = t_objective_flows.milestone_year
        ORDER BY
            var.id
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
            expr.id,
            t_objective_flows.weight_for_operation_discounts
                * flow_commission.fixed_cost / 2
                * t_objective_flows.capacity
                AS cost,
        FROM expr_available_flow_units_simple_method AS expr
        LEFT JOIN flow_commission
            ON expr.from_asset = flow_commission.from_asset
            AND expr.to_asset = flow_commission.to_asset
            AND expr.commission_year = flow_commission.commission_year
        LEFT JOIN t_objective_flows
            ON expr.from_asset = t_objective_flows.from_asset
            AND expr.to_asset = t_objective_flows.to_asset
            AND expr.milestone_year = t_objective_flows.milestone_year
        ORDER BY
            expr.id
        ",
    )

    flows_fixed_cost = @expression(
        model,
        sum(
            row.cost * (avail_export_unit + avail_import_unit) for
            (row, avail_export_unit, avail_import_unit) in zip(
                indices,
                expr_available_flow_units_simple_method.expressions[:export],
                expr_available_flow_units_simple_method.expressions[:import],
            )
        )
    )

    indices = DuckDB.query(
        connection,
        "SELECT
            var.id,
            t_objective_flows.weight_for_operation_discounts
                * rpinfo.weight_sum
                * rpinfo.resolution
                * (var.time_block_end - var.time_block_start + 1)
                * t_objective_flows.variable_cost
                AS cost,
        FROM var_flow AS var
        LEFT JOIN t_objective_flows
            ON var.from_asset = t_objective_flows.from_asset
            AND var.to_asset = t_objective_flows.to_asset
            AND var.year = t_objective_flows.milestone_year
        LEFT JOIN (
            SELECT
                rpmap.year,
                rpmap.rep_period,
                SUM(weight) AS weight_sum,
                ANY_VALUE(rpdata.resolution) AS resolution
            FROM rep_periods_mapping AS rpmap
            LEFT JOIN rep_periods_data AS rpdata
                ON rpmap.year=rpdata.year AND rpmap.rep_period=rpdata.rep_period
            GROUP BY rpmap.year, rpmap.rep_period
        ) AS rpinfo
            ON var.year = rpinfo.year
            AND var.rep_period = rpinfo.rep_period
        ORDER BY var.id
        ",
    )

    flows_variable_cost = @expression(
        model,
        sum(row.cost * flow for (row, flow) in zip(indices, variables[:flow].container))
    )

    indices = DuckDB.query(
        connection,
        "SELECT
            var.id,
            t_objective_assets.weight_for_operation_discounts
                * rpinfo.weight_sum
                * rpinfo.resolution
                * (var.time_block_end - var.time_block_start + 1)
                * t_objective_assets.units_on_cost
                AS cost,
        FROM var_units_on AS var
        LEFT JOIN t_objective_assets
            ON var.asset = t_objective_assets.asset
            AND var.year = t_objective_assets.milestone_year
        LEFT JOIN (
            SELECT
                rpmap.year,
                rpmap.rep_period,
                SUM(weight) AS weight_sum,
                ANY_VALUE(rpdata.resolution) AS resolution
            FROM rep_periods_mapping AS rpmap
            LEFT JOIN rep_periods_data AS rpdata
                ON rpmap.year=rpdata.year AND rpmap.rep_period=rpdata.rep_period
            GROUP BY rpmap.year, rpmap.rep_period
        ) AS rpinfo
            ON var.year = rpinfo.year
            AND var.rep_period = rpinfo.rep_period
        WHERE t_objective_assets.units_on_cost IS NOT NULL
        ORDER BY var.id
        ",
    )

    units_on_cost = @expression(
        model,
        sum(
            row.cost * units_on for (row, units_on) in zip(indices, variables[:units_on].container)
        )
    )

    ## Objective function
    @objective(
        model,
        Min,
        assets_investment_cost +
        assets_fixed_cost_compact_method +
        assets_fixed_cost_simple_method +
        storage_assets_energy_investment_cost +
        storage_assets_energy_fixed_cost +
        flows_investment_cost +
        flows_fixed_cost +
        flows_variable_cost +
        units_on_cost
    )
end

function _create_objective_auxiliary_table(connection, constants)
    # Create a table with the discount_factor_from_current_milestone_year_to_next_milestone_year (short for total_discount_factor) for operation
    #
    # total_discount_factor[asset, milestone_year] = ∑_[year = milestone_year:next_milestone_year - 1] discount_factor[a, year]
    #   where discount_factor[asset, year] = 1 / (1 + social_rate)^(year - discount_year)
    #
    # Note total_discount_factor[asset, milestone_year] accounts for [milestone_year, next_milestone_year - 1], i.e., excluding next_milestone_year
    # Same for flows
    DuckDB.execute(
        connection,
        " CREATE OR REPLACE TEMP TABLE t_discount_assets_in_between_milestone_years AS
        WITH milestones AS (
            SELECT
                asset,
                milestone_year AS current_year,
                COALESCE(
                    LEAD(milestone_year) OVER (PARTITION BY asset ORDER BY milestone_year),
                    milestone_year + 1
                ) AS next_year
            FROM asset_milestone
        ),
        years_in_between AS (
            SELECT
                m.asset,
                m.current_year,
                in_between_years.year
            FROM milestones as m,
                LATERAL generate_series(m.current_year, m.next_year - 1) AS in_between_years(year)
        ),
        discounts AS (
            SELECT
                asset,
                current_year as milestone_year,
                SUM(1 / (1 + $(constants.social_rate))^(year - $(constants.discount_year))) AS discount_factor_from_current_milestone_year_to_next_milestone_year
            FROM years_in_between
            GROUP BY asset, milestone_year
        )
        SELECT
            *
        FROM discounts;
       ",
    )

    DuckDB.execute(
        connection,
        " CREATE OR REPLACE TEMP TABLE t_discount_flows_in_between_milestone_years AS
        WITH milestones AS (
            SELECT
                from_asset,
                to_asset,
                milestone_year AS current_year,
                COALESCE(
                    LEAD(milestone_year) OVER (PARTITION BY from_asset, to_asset ORDER BY milestone_year),
                    milestone_year + 1
                ) AS next_year
            FROM flow_milestone
        ),
        years_in_between AS (
            SELECT
                m.from_asset,
                m.to_asset,
                m.current_year,
                in_between_years.year
            FROM milestones as m,
                LATERAL generate_series(m.current_year, m.next_year - 1) AS in_between_years(year)
        ),
        discounts AS (
            SELECT
                from_asset,
                to_asset,
                current_year as milestone_year,
                SUM(1 / (1 + $(constants.social_rate))^(year - $(constants.discount_year))) AS discount_factor_from_current_milestone_year_to_next_milestone_year
            FROM years_in_between
            GROUP BY from_asset, to_asset, milestone_year
        )
        SELECT
            *
        FROM discounts;
       ",
    )

    DuckDB.execute(
        connection,
        "CREATE OR REPLACE TEMP TABLE t_objective_assets AS
        SELECT
            -- keys
            asset_milestone.asset,
            asset_milestone.milestone_year,
            -- copied over
            asset_commission.investment_cost,
            asset.capacity,
            asset_commission.investment_cost_storage_energy,
            asset.capacity_storage_energy,
            asset_milestone.units_on_cost,
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
            1 / (1 + $(constants.social_rate))^(asset_milestone.milestone_year - $(constants.discount_year)) AS investment_year_discount,
            investment_year_discount * (1 - salvage_value / asset_commission.investment_cost) AS weight_for_asset_investment_discount,
            in_between_years.discount_factor_from_current_milestone_year_to_next_milestone_year AS weight_for_operation_discounts,
        FROM asset_milestone
        LEFT JOIN asset_commission
            ON asset_milestone.asset = asset_commission.asset
            AND asset_milestone.milestone_year = asset_commission.commission_year
        LEFT JOIN t_discount_assets_in_between_milestone_years as in_between_years
            ON asset_milestone.asset = in_between_years.asset
            AND asset_milestone.milestone_year = in_between_years.milestone_year
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
            flow.capacity,
            flow_milestone.variable_cost,
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
            1 / (1 + $(constants.social_rate))^(flow_milestone.milestone_year - $(constants.discount_year)) AS investment_year_discount,
            investment_year_discount * (1 - salvage_value / flow_commission.investment_cost) AS weight_for_flow_investment_discount,
            in_between_years.discount_factor_from_current_milestone_year_to_next_milestone_year AS weight_for_operation_discounts,
        FROM flow_milestone
        LEFT JOIN flow_commission
            ON flow_milestone.from_asset = flow_commission.from_asset
            AND flow_milestone.to_asset = flow_commission.to_asset
            AND flow_milestone.milestone_year = flow_commission.commission_year
        LEFT JOIN t_discount_flows_in_between_milestone_years as in_between_years
            ON flow_milestone.from_asset = in_between_years.from_asset
            AND flow_milestone.to_asset = in_between_years.to_asset
            AND flow_milestone.milestone_year = in_between_years.milestone_year
        LEFT JOIN flow
            ON flow.from_asset = flow_commission.from_asset
            AND flow.to_asset = flow_commission.to_asset
        ",
    )

    return
end
