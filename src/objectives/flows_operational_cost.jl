function _add_flows_operational_cost!(
    connection,
    model,
    variables,
    profiles,
    objective_expr,
    lambda,
)
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
        (1 - lambda) * flows_operational_cost,
    )

    return
end
