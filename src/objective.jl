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
            obj.weight_for_asset_investment_discount
                * obj.investment_cost
                * obj.capacity
                AS cost,
        FROM var_assets_investment AS var
        LEFT JOIN t_objective_assets as obj
            ON var.asset = obj.asset
            AND var.milestone_year = obj.milestone_year
        ORDER BY var.id
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
            obj.weight_for_operation_discounts
                * asset_commission.fixed_cost
                * obj.capacity
                AS cost,
        FROM expr_available_asset_units_compact_method AS expr
        LEFT JOIN asset_commission
            ON expr.asset = asset_commission.asset
            AND expr.commission_year = asset_commission.commission_year
        LEFT JOIN t_objective_assets as obj
            ON expr.asset = obj.asset
            AND expr.milestone_year = obj.milestone_year
        ORDER BY expr.id
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
            obj.weight_for_operation_discounts
                * asset_commission.fixed_cost
                * obj.capacity
                AS cost,
        FROM expr_available_asset_units_simple_method AS expr
        LEFT JOIN asset_commission
            ON expr.asset = asset_commission.asset
            AND expr.commission_year = asset_commission.commission_year
        LEFT JOIN t_objective_assets as obj
            ON expr.asset = obj.asset
            AND expr.milestone_year = obj.milestone_year
        ORDER BY expr.id
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
            obj.weight_for_asset_investment_discount
                * obj.investment_cost_storage_energy
                * obj.capacity_storage_energy
                AS cost,
        FROM var_assets_investment_energy AS var
        LEFT JOIN t_objective_assets as obj
            ON var.asset = obj.asset
            AND var.milestone_year = obj.milestone_year
        ORDER BY var.id
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
            obj.weight_for_operation_discounts
                * asset_commission.fixed_cost_storage_energy
                * obj.capacity_storage_energy
                AS cost,
        FROM expr_available_energy_units_simple_method AS expr
        LEFT JOIN asset_commission
            ON expr.asset = asset_commission.asset
            AND expr.commission_year = asset_commission.commission_year
        LEFT JOIN t_objective_assets as obj
            ON expr.asset = obj.asset
            AND expr.milestone_year = obj.milestone_year
        ORDER BY expr.id
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
            obj.weight_for_flow_investment_discount
                * obj.investment_cost
                * obj.capacity
                AS cost,
        FROM var_flows_investment AS var
        LEFT JOIN t_objective_flows as obj
            ON var.from_asset = obj.from_asset
            AND var.to_asset = obj.to_asset
            AND var.milestone_year = obj.milestone_year
        ORDER BY var.id
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
            obj.weight_for_operation_discounts
                * flow_commission.fixed_cost / 2
                * obj.capacity
                AS cost,
        FROM expr_available_flow_units_simple_method AS expr
        LEFT JOIN flow_commission
            ON expr.from_asset = flow_commission.from_asset
            AND expr.to_asset = flow_commission.to_asset
            AND expr.commission_year = flow_commission.commission_year
        LEFT JOIN t_objective_flows as obj
            ON expr.from_asset = obj.from_asset
            AND expr.to_asset = obj.to_asset
            AND expr.milestone_year = obj.milestone_year
        ORDER BY expr.id
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
        "WITH rp_weight AS (
            SELECT
                year,
                rep_period,
                SUM(weight) AS weight_sum
            FROM rep_periods_mapping
            GROUP BY year, rep_period
        ),
        rp_res AS (
            SELECT
                year,
                rep_period,
                ANY_VALUE(resolution) AS resolution
            FROM rep_periods_data
            GROUP BY year, rep_period
        )
        SELECT
            var.id,
            obj.weight_for_operation_discounts
                * rp_weight.weight_sum
                * rp_res.resolution
                * (var.time_block_end - var.time_block_start + 1)
                * obj.total_variable_cost
                AS cost,
        FROM var_flow AS var
        LEFT JOIN t_objective_flows as obj
            ON var.from_asset = obj.from_asset
            AND var.to_asset = obj.to_asset
            AND var.year = obj.milestone_year
        LEFT JOIN rp_weight
            ON var.year = rp_weight.year
            AND var.rep_period = rp_weight.rep_period
        LEFT JOIN rp_res
            ON var.year = rp_res.year
            AND var.rep_period = rp_res.rep_period
        LEFT JOIN asset
            ON asset.asset = var.from_asset
        WHERE asset.investment_method != 'semi-compact'
        ",
    )

    # For the flows_operational_cost, we cannot use the zip method as done in all other terms,
    # because there are more flow variables than the number of rows in indices,
    # i.e., we only consider the costs of the flows that are not in semi-compact method
    var_flow = variables[:flow].container

    flows_operational_cost = @expression(model, sum(row.cost * var_flow[row.id] for row in indices))

    indices = DuckDB.query(
        connection,
        "WITH rp_weight AS (
            SELECT
                year,
                rep_period,
                SUM(weight) AS weight_sum
            FROM rep_periods_mapping
            GROUP BY year, rep_period
        ),
        rp_res AS (
            SELECT
                year,
                rep_period,
                ANY_VALUE(resolution) AS resolution
            FROM rep_periods_data
            GROUP BY year, rep_period
        ),
        vint_obj AS (
            SELECT
                from_asset,
                to_asset,
                milestone_year,
                commission_year,
                ANY_VALUE(weight_for_operation_discounts) AS weight_for_operation_discounts,
                ANY_VALUE(total_variable_cost) AS total_variable_cost
            FROM t_objective_vintage_flows
            GROUP BY from_asset, to_asset, milestone_year, commission_year
        )
        SELECT
            var.id,
            vint_obj.weight_for_operation_discounts
                * rp_weight.weight_sum
                * rp_res.resolution
                * (var.time_block_end - var.time_block_start + 1)
                * vint_obj.total_variable_cost AS cost
        FROM var_vintage_flow AS var
        LEFT JOIN vint_obj
            ON var.from_asset = vint_obj.from_asset
            AND var.to_asset = vint_obj.to_asset
            AND var.milestone_year = vint_obj.milestone_year
            AND var.commission_year = vint_obj.commission_year
        LEFT JOIN rp_weight
            ON var.milestone_year = rp_weight.year
            AND var.rep_period = rp_weight.rep_period
        LEFT JOIN rp_res
            ON var.milestone_year = rp_res.year
            AND var.rep_period = rp_res.rep_period
        ORDER BY var.id
        ",
    )

    vintage_flows_operational_cost = @expression(
        model,
        sum(
            row.cost * vintage_flow for
            (row, vintage_flow) in zip(indices, variables[:vintage_flow].container)
        )
    )

    indices = DuckDB.query(
        connection,
        "WITH rp_weight AS (
            SELECT
                year,
                rep_period,
                SUM(weight) AS weight_sum
            FROM rep_periods_mapping
            GROUP BY year, rep_period
        ),
        rp_res AS (
            SELECT
                year,
                rep_period,
                ANY_VALUE(resolution) AS resolution
            FROM rep_periods_data
            GROUP BY year, rep_period
        )
        SELECT
            var.id,
            obj.weight_for_operation_discounts
                * rp_weight.weight_sum
                * rp_res.resolution
                * (var.time_block_end - var.time_block_start + 1)
                * obj.units_on_cost
                AS cost,
        FROM var_units_on AS var
        LEFT JOIN t_objective_assets as obj
            ON var.asset = obj.asset
            AND var.year = obj.milestone_year
        LEFT JOIN rp_weight
            ON var.year = rp_weight.year
            AND var.rep_period = rp_weight.rep_period
        LEFT JOIN rp_res
            ON var.year = rp_res.year
            AND var.rep_period = rp_res.rep_period
        WHERE obj.units_on_cost IS NOT NULL
        ORDER BY var.id
        ",
    )

    units_on_cost = @expression(
        model,
        sum(
            row.cost * units_on for (row, units_on) in zip(indices, variables[:units_on].container)
        )
    )

    indices = DuckDB.query(
        connection,
        "SELECT
            var.id,
            t_objective_assets.weight_for_operation_discounts *
            t_objective_assets.start_up_cost AS cost,
        FROM var_start_up AS var
        LEFT JOIN t_objective_assets
            ON var.asset = t_objective_assets.asset
            AND var.year = t_objective_assets.milestone_year
        WHERE t_objective_assets.start_up_cost IS NOT NULL
        ORDER BY var.asset,
            var.year,
            var.rep_period,
            var.time_block_start,
            var.time_block_end
        ",
    )

    var_start_up = variables[:start_up].container

    start_up_cost = @expression(model, sum(row.cost * var_start_up[row.id] for row in indices))

    indices = DuckDB.query(
        connection,
        "SELECT
            var.id,
            t_objective_assets.weight_for_operation_discounts *
            t_objective_assets.shut_down_cost AS cost,
        FROM var_shut_down AS var
        LEFT JOIN t_objective_assets
            ON var.asset = t_objective_assets.asset
            AND var.year = t_objective_assets.milestone_year
        WHERE t_objective_assets.shut_down_cost IS NOT NULL
        ORDER BY var.asset,
            var.year,
            var.rep_period,
            var.time_block_start,
            var.time_block_end
        ",
    )

    var_shut_down = variables[:shut_down].container

    shut_down_cost = @expression(model, sum(row.cost * var_shut_down[row.id] for row in indices))

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
        flows_operational_cost +
        vintage_flows_operational_cost +
        units_on_cost +
        start_up_cost +
        shut_down_cost
    )
end

function _create_objective_auxiliary_table(connection, constants)
    # Create a table with the discount_factor_from_current_milestone_year_to_next_milestone_year (short for total_discount_factor) for operation
    #
    # total_discount_factor[asset, milestone_year] = ∑_[year = milestone_year:next_milestone_year - 1] discount_factor[asset, year]
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
            asset.start_up_cost,
            asset.shut_down_cost,
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
            ON asset.asset = asset_milestone.asset
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
            asset_milestone.commodity_price,
            asset_commission.efficiency,
            flow_milestone.operational_cost,
            -- computed
            (asset_milestone.commodity_price / asset_commission.efficiency) AS fuel_cost,
            (fuel_cost + flow_milestone.operational_cost) AS total_variable_cost,
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
        -- We get the asset_milestone from the outgoing asset
        LEFT JOIN asset_milestone
            ON flow_milestone.from_asset = asset_milestone.asset
            AND flow_milestone.milestone_year = asset_milestone.milestone_year
        /*
        The below join works for compact/simple/none method.
        Note normally this condition milestone_year = commission_year does not work for compact method.
        But here, it means if you use compact method, the fuel cost will ignore the efficiencies where
        milestone_year != commission_year
        It makes sense because if you would like to consider efficiencies from different commission years,
        you should use semi-compact method instead.
        */
        LEFT JOIN asset_commission
            ON flow_milestone.from_asset = asset_commission.asset
            AND flow_milestone.milestone_year = asset_commission.commission_year
        ",
    )

    DuckDB.execute(
        connection,
        "CREATE OR REPLACE TEMP TABLE t_objective_vintage_flows AS
        SELECT
            -- keys
            var.from_asset,
            var.to_asset,
            var.milestone_year,
            var.commission_year,
            -- copied over
            asset_milestone.commodity_price,
            asset_commission.efficiency,
            flow_milestone.operational_cost,
            -- computed
            (asset_milestone.commodity_price / asset_commission.efficiency) AS fuel_cost,
            (fuel_cost + flow_milestone.operational_cost) AS total_variable_cost,
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
        FROM var_vintage_flow AS var
        -- We get the asset_milestone from the outgoing asset
        LEFT JOIN asset_milestone
            ON var.from_asset = asset_milestone.asset
            AND var.milestone_year = asset_milestone.milestone_year
        LEFT JOIN asset_commission
            ON var.from_asset = asset_commission.asset
            AND var.commission_year = asset_commission.commission_year
        LEFT JOIN flow_milestone
            ON var.from_asset = flow_milestone.from_asset
            AND var.to_asset = flow_milestone.to_asset
            AND var.milestone_year = flow_milestone.milestone_year
        LEFT JOIN flow
            ON var.from_asset = flow.from_asset
            AND var.to_asset = flow.to_asset
        LEFT JOIN flow_commission
            ON var.from_asset = flow_commission.from_asset
            AND var.to_asset = flow_commission.to_asset
            AND var.commission_year = flow_commission.commission_year
        LEFT JOIN t_discount_flows_in_between_milestone_years as in_between_years
            ON var.from_asset = in_between_years.from_asset
            AND var.to_asset = in_between_years.to_asset
            AND var.milestone_year = in_between_years.milestone_year
        LEFT JOIN asset
            ON asset.asset = flow_milestone.from_asset
        WHERE asset.investment_method = 'semi-compact'
        ",
    )

    return
end
