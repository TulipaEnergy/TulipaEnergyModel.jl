function _add_flows_costs!(connection, model, variables, expressions, profiles, objective_expr)
    flows_investment = variables[:flows_investment]
    expr_available_flow_units_simple_method = expressions[:available_flow_units_simple_method]

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
    _add_to_objective!(
        connection,
        model,
        objective_expr,
        "flows_investment_cost",
        flows_investment_cost,
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
    _add_to_objective!(connection, model, objective_expr, "flows_fixed_cost", flows_fixed_cost)

    commodity_price_profile_name = ""
    flows_profiles_query_left_join = ""
    # has_commodity_price_profile is used to determine if there is at least one flow with commodity_price profile.
    # The profiles are differentiated later
    has_commodity_price_profile =
        get_single_element_from_query_and_ensure_its_only_one(
            DuckDB.query(
                connection,
                """
                SELECT COUNT(*)
                FROM flows_profiles
                WHERE profile_type = 'commodity_price'
                """,
            ),
        ) > 0
    if has_commodity_price_profile
        commodity_price_profile_name = "commodity_price_profiles.profile_name,"
        flows_profiles_query_left_join = """
        LEFT JOIN flows_profiles AS commodity_price_profiles
            ON commodity_price_profiles.from_asset = var.from_asset
            AND commodity_price_profiles.to_asset = var.to_asset
            AND commodity_price_profiles.milestone_year = var.milestone_year
            AND commodity_price_profiles.profile_type = 'commodity_price'
        """
    end
    indices = DuckDB.query(
        connection,
        "WITH rp_weight_prob AS (
            SELECT
                milestone_year,
                rep_period,
                SUM(rpm.weight * scn.probability) AS total_weight_prob
            FROM rep_periods_mapping AS rpm
            LEFT JOIN stochastic_scenario AS scn
                ON rpm.scenario = scn.scenario
            GROUP BY milestone_year, rep_period
        ),
        rp_res AS (
            SELECT
                milestone_year,
                rep_period,
                ANY_VALUE(resolution) AS resolution
            FROM rep_periods_data
            GROUP BY milestone_year, rep_period
        )
        SELECT
            var.id,
            obj.weight_for_operation_discounts
                * rp_weight_prob.total_weight_prob
                * rp_res.resolution
                AS cost_coefficient,
            cost_coefficient * obj.total_variable_cost
                * (var.time_block_end - var.time_block_start + 1) AS total_cost_if_no_profile,
            var.time_block_start,
            var.time_block_end,
            var.milestone_year,
            var.rep_period,
            obj.commodity_price,
            obj.producer_efficiency,
            obj.operational_cost,
            $commodity_price_profile_name
        FROM var_flow AS var
        LEFT JOIN t_objective_flows as obj
            ON var.from_asset = obj.from_asset
            AND var.to_asset = obj.to_asset
            AND var.milestone_year = obj.milestone_year
        LEFT JOIN rp_weight_prob
            ON var.milestone_year = rp_weight_prob.milestone_year
            AND var.rep_period = rp_weight_prob.rep_period
        LEFT JOIN rp_res
            ON var.milestone_year = rp_res.milestone_year
            AND var.rep_period = rp_res.rep_period
        LEFT JOIN asset
            ON asset.asset = var.from_asset
        $flows_profiles_query_left_join
        WHERE asset.investment_method != 'semi-compact'
        ",
    )

    # For the flows_operational_cost, we cannot use the zip method as done in all other terms,
    # because there are more flow variables than the number of rows in indices,
    # i.e., we only consider the costs of the flows that are not in semi-compact method
    var_flow = variables[:flow].container

    # The flows with commodity_price profile are differentiated here. If there
    # are no commodity_price profiles, then the column `profile_name` doesn't
    # exist.
    flows_operational_cost = JuMP.AffExpr(0.0)
    for row in indices
        coefficient = 0.0
        if !has_commodity_price_profile || ismissing(row.profile_name) # No commodity_price profile
            coefficient = row.total_cost_if_no_profile::Float64
        else
            commodity_price_agg = _profile_aggregate(
                profiles.rep_period,
                (row.profile_name::String, row.milestone_year::Int32, row.rep_period::Int32),
                row.time_block_start:row.time_block_end,
                Statistics.mean,
                1.0,
            )
            coefficient =
                row.cost_coefficient::Float64 *
                (
                    row.commodity_price::Float64 * commodity_price_agg /
                    row.producer_efficiency::Float64 + row.operational_cost::Float64
                ) *
                (row.time_block_end - row.time_block_start + 1)
        end
        JuMP.add_to_expression!(flows_operational_cost, coefficient, var_flow[row.id::Int64])
    end
    _add_to_objective!(
        connection,
        model,
        objective_expr,
        "flows_operational_cost",
        flows_operational_cost,
    )

    indices = DuckDB.query(
        connection,
        "WITH rp_weight_prob AS (
            SELECT
                milestone_year,
                rep_period,
                SUM(rpm.weight * scn.probability) AS total_weight_prob
            FROM rep_periods_mapping AS rpm
            LEFT JOIN stochastic_scenario AS scn
                ON rpm.scenario = scn.scenario
            GROUP BY milestone_year, rep_period
        ),
        rp_res AS (
            SELECT
                milestone_year,
                rep_period,
                ANY_VALUE(resolution) AS resolution
            FROM rep_periods_data
            GROUP BY milestone_year, rep_period
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
                * rp_weight_prob.total_weight_prob
                * rp_res.resolution
                * (var.time_block_end - var.time_block_start + 1)
                * vint_obj.total_variable_cost AS cost
        FROM var_vintage_flow AS var
        LEFT JOIN vint_obj
            ON var.from_asset = vint_obj.from_asset
            AND var.to_asset = vint_obj.to_asset
            AND var.milestone_year = vint_obj.milestone_year
            AND var.commission_year = vint_obj.commission_year
        LEFT JOIN rp_weight_prob
            ON var.milestone_year = rp_weight_prob.milestone_year
            AND var.rep_period = rp_weight_prob.rep_period
        LEFT JOIN rp_res
            ON var.milestone_year = rp_res.milestone_year
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
    _add_to_objective!(
        connection,
        model,
        objective_expr,
        "vintage_flows_operational_cost",
        vintage_flows_operational_cost,
    )

    return
end
