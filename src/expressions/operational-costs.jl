"""
    add_operational_cost_expressions!(connection, model, variables, expressions, profiles)

Create and attach per-scenario operational cost expressions for flows,
vintage flows, and units-on variables.

These expressions are later reused by the objective builder and by the CVaR
tail-excess expression/constraint path, so scenario-indexed costs are computed
once and shared across downstream steps.
"""
function add_operational_cost_expressions!(connection, model, variables, expressions, profiles)
    _add_flows_operational_cost_per_scenario_expressions!(
        connection,
        model,
        variables,
        expressions,
        profiles,
    )
    _add_vintage_flows_operational_cost_per_scenario_expressions!(
        connection,
        model,
        variables,
        expressions,
    )
    _add_units_on_operational_cost_per_scenario_expressions!(
        connection,
        model,
        variables,
        expressions,
    )

    return nothing
end

"""
    _add_flows_operational_cost_per_scenario_expressions!(
        connection,
        model,
        variables,
        expressions,
        profiles,
    )

Create and attach one flow operational-cost expression per scenario.

Costs are aggregated per scenario using SQL `ARRAY_AGG`. Because profile-based
cost components require Julia-side lookups, a `costs` vector is pre-allocated
from the known aggregate length and filled before building the expression.
The result is stored as
`expressions[:flows_operational_cost_per_scenario].expressions[:cost]`.
"""
function _add_flows_operational_cost_per_scenario_expressions!(
    connection,
    model,
    variables,
    expressions,
    profiles,
)
    expr_name = :flows_operational_cost_per_scenario
    expr = _create_scenario_cost_expression!(connection, expressions, expr_name)

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

    var_flow = variables[:flow].container

    indices = _query_flows_operational_cost_per_scenario_indices(
        connection,
        expr_name,
        has_commodity_price_profile,
    )

    attach_expression!(
        expr,
        :cost,
        JuMP.AffExpr[
            if length(row.var_flow_ids) > 0
                n_flows = length(row.var_flow_ids)
                costs = Vector{Float64}(undef, n_flows)
                for i in 1:n_flows
                    costs[i] =
                        if !has_commodity_price_profile || ismissing(row.arr_profile_name[i])
                            row.arr_total_cost_if_no_profile[i]::Float64
                        else
                            commodity_price_agg = _profile_aggregate(
                                profiles.rep_period,
                                (
                                    row.arr_profile_name[i]::String,
                                    row.arr_milestone_year[i]::Int32,
                                    row.arr_rep_period[i]::Int32,
                                ),
                                row.arr_time_block_start[i]:row.arr_time_block_end[i],
                                Statistics.mean,
                                1.0,
                            )
                            row.arr_cost_coefficient[i]::Float64 *
                            (
                                row.arr_commodity_price[i]::Float64 * commodity_price_agg /
                                row.arr_producer_efficiency[i]::Float64 +
                                row.arr_operational_cost[i]::Float64
                            ) *
                            (row.arr_time_block_end[i] - row.arr_time_block_start[i] + 1)
                        end
                end
                @expression(
                    model,
                    sum(costs[i] * var_flow[row.var_flow_ids[i]::Int64] for i in 1:n_flows),
                )
            else
                @expression(model, 0.0)
            end for row in indices
        ],
    )

    return nothing
end

"""
    _add_vintage_flows_operational_cost_per_scenario_expressions!(
        connection,
        model,
        variables,
        expressions,
    )

Create and attach one vintage-flow operational-cost expression per scenario.

Costs are aggregated per scenario using SQL `ARRAY_AGG`, so no Julia-side
grouping is needed. The result is stored as
`expressions[:vintage_flows_operational_cost_per_scenario].expressions[:cost]`.
"""
function _add_vintage_flows_operational_cost_per_scenario_expressions!(
    connection,
    model,
    variables,
    expressions,
)
    expr_name = :vintage_flows_operational_cost_per_scenario
    expr = _create_scenario_cost_expression!(connection, expressions, expr_name)
    vintage_flow = variables[:vintage_flow].container
    indices = _query_vintage_flows_operational_cost_per_scenario_indices(connection, expr_name)

    attach_expression!(
        expr,
        :cost,
        JuMP.AffExpr[
            if length(row.var_vintage_flow_ids) > 0
                @expression(
                    model,
                    sum(
                        cost * vintage_flow[var_id::Int64] for
                        (cost, var_id) in zip(row.arr_cost, row.var_vintage_flow_ids)
                    ),
                )
            else
                @expression(model, 0.0)
            end for row in indices
        ],
    )

    return nothing
end

"""
    _add_units_on_operational_cost_per_scenario_expressions!(
        connection,
        model,
        variables,
        expressions,
    )

Create and attach one units-on operational-cost expression per scenario.

Costs are aggregated per scenario using SQL `ARRAY_AGG`, so no Julia-side
grouping is needed. The result is stored as
`expressions[:units_on_operational_cost_per_scenario].expressions[:cost]`.
"""
function _add_units_on_operational_cost_per_scenario_expressions!(
    connection,
    model,
    variables,
    expressions,
)
    expr_name = :units_on_operational_cost_per_scenario
    expr = _create_scenario_cost_expression!(connection, expressions, expr_name)
    units_on = variables[:units_on].container
    indices = _query_units_on_operational_cost_per_scenario_indices(connection, expr_name)

    attach_expression!(
        expr,
        :cost,
        JuMP.AffExpr[
            if length(row.var_units_on_ids) > 0
                @expression(
                    model,
                    sum(
                        cost * units_on[var_id::Int64] for
                        (cost, var_id) in zip(row.arr_cost, row.var_units_on_ids)
                    ),
                )
            else
                @expression(model, 0.0)
            end for row in indices
        ],
    )

    return nothing
end

"""
    _create_scenario_cost_expression!(connection, expressions, expr_name)

Create a temporary expression table with one row per scenario (`id`,
`scenario`, `probability`) ordered by scenario, register it in `expressions`,
and return the created `TulipaExpression`.
"""
function _create_scenario_cost_expression!(connection, expressions, expr_name)
    DuckDB.query(
        connection,
        """
        CREATE OR REPLACE TEMP SEQUENCE id START 1;
        CREATE OR REPLACE TABLE expr_$expr_name AS
        WITH ordered_scenarios AS (
            SELECT
                scenario,
                probability
            FROM stochastic_scenario
            ORDER BY scenario
        )
        SELECT
            nextval('id') AS id,
            ordered_scenarios.scenario,
            ordered_scenarios.probability
        FROM ordered_scenarios
        """,
    )
    expressions[expr_name] = TulipaExpression(connection, "expr_$expr_name")

    return expressions[expr_name]
end

"""
    _query_flows_operational_cost_per_scenario_indices(connection, expr_name, has_commodity_price_profile)

Return one row per scenario with `ARRAY_AGG`-aggregated flow variable ids and
cost components, joined with the `expr_name` scenario table.

Aggregating in SQL avoids collecting individual rows and Julia-side grouping.
Because profile-based costs require Julia-side computation, all cost metadata
(time blocks, profile names, etc.) is included in the aggregated arrays so the
caller can pre-allocate and fill a `costs` vector without extra queries.
"""
function _query_flows_operational_cost_per_scenario_indices(
    connection,
    expr_name,
    has_commodity_price_profile,
)
    profile_name_select =
        has_commodity_price_profile ? "commodity_price_profiles.profile_name," : ""
    arr_profile_name_agg = if has_commodity_price_profile
        "ARRAY_AGG(profile_name ORDER BY id) AS arr_profile_name,"
    else
        "NULL AS arr_profile_name,"
    end
    flows_profiles_query_left_join = if has_commodity_price_profile
        """
        LEFT JOIN flows_profiles AS commodity_price_profiles
            ON commodity_price_profiles.from_asset = var.from_asset
            AND commodity_price_profiles.to_asset = var.to_asset
            AND commodity_price_profiles.milestone_year = var.milestone_year
            AND commodity_price_profiles.profile_type = 'commodity_price'
        """
    else
        ""
    end
    return DuckDB.query(
        connection,
        """
        WITH rp_weight AS (
            SELECT
                milestone_year,
                rep_period,
                scenario,
                SUM(weight) AS total_weight_per_scenario
            FROM rep_periods_mapping
            GROUP BY milestone_year, rep_period, scenario
        ),
        rp_res AS (
            SELECT
                milestone_year,
                rep_period,
                ANY_VALUE(resolution) AS resolution
            FROM rep_periods_data
            GROUP BY milestone_year, rep_period
        ),
        flow_rows AS (
            SELECT
                rp_weight.scenario,
                var.id,
                obj.weight_for_operation_discounts
                    * rp_weight.total_weight_per_scenario
                    * rp_res.resolution
                    AS cost_coefficient,
                cost_coefficient * obj.total_variable_cost
                    * (var.time_block_end - var.time_block_start + 1)
                    AS total_cost_if_no_profile,
                var.time_block_start,
                var.time_block_end,
                var.milestone_year,
                var.rep_period,
                obj.commodity_price,
                obj.producer_efficiency,
                obj.operational_cost,
                $profile_name_select
            FROM var_flow AS var
            LEFT JOIN t_objective_flows AS obj
                ON var.from_asset = obj.from_asset
                AND var.to_asset = obj.to_asset
                AND var.milestone_year = obj.milestone_year
            LEFT JOIN rp_weight
                ON var.milestone_year = rp_weight.milestone_year
                AND var.rep_period = rp_weight.rep_period
            LEFT JOIN rp_res
                ON var.milestone_year = rp_res.milestone_year
                AND var.rep_period = rp_res.rep_period
            LEFT JOIN asset
                ON asset.asset = var.from_asset
            $flows_profiles_query_left_join
            WHERE asset.investment_method != 'semi-compact'
        ),
        flows_per_scenario AS (
            SELECT
                scenario,
                ARRAY_AGG(id ORDER BY id)                        AS var_flow_ids,
                ARRAY_AGG(total_cost_if_no_profile ORDER BY id) AS arr_total_cost_if_no_profile,
                ARRAY_AGG(time_block_start ORDER BY id)         AS arr_time_block_start,
                ARRAY_AGG(time_block_end ORDER BY id)           AS arr_time_block_end,
                ARRAY_AGG(milestone_year ORDER BY id)           AS arr_milestone_year,
                ARRAY_AGG(rep_period ORDER BY id)               AS arr_rep_period,
                ARRAY_AGG(commodity_price ORDER BY id)          AS arr_commodity_price,
                ARRAY_AGG(producer_efficiency ORDER BY id)      AS arr_producer_efficiency,
                ARRAY_AGG(operational_cost ORDER BY id)         AS arr_operational_cost,
                ARRAY_AGG(cost_coefficient ORDER BY id)         AS arr_cost_coefficient,
                $arr_profile_name_agg
            FROM flow_rows
            GROUP BY scenario
        )
        SELECT
            expr.id,
            expr.scenario,
            expr.probability,
            COALESCE(fps.var_flow_ids, [])                        AS var_flow_ids,
            COALESCE(fps.arr_total_cost_if_no_profile, [])        AS arr_total_cost_if_no_profile,
            COALESCE(fps.arr_time_block_start, [])                AS arr_time_block_start,
            COALESCE(fps.arr_time_block_end, [])                  AS arr_time_block_end,
            COALESCE(fps.arr_milestone_year, [])                  AS arr_milestone_year,
            COALESCE(fps.arr_rep_period, [])                      AS arr_rep_period,
            COALESCE(fps.arr_commodity_price, [])                 AS arr_commodity_price,
            COALESCE(fps.arr_producer_efficiency, [])             AS arr_producer_efficiency,
            COALESCE(fps.arr_operational_cost, [])                AS arr_operational_cost,
            COALESCE(fps.arr_cost_coefficient, [])                AS arr_cost_coefficient,
            fps.arr_profile_name,
        FROM expr_$expr_name AS expr
        LEFT JOIN flows_per_scenario AS fps ON expr.scenario = fps.scenario
        ORDER BY expr.id
        """,
    )
end

"""
    _query_vintage_flows_operational_cost_per_scenario_indices(connection, expr_name)

Return one row per scenario with `ARRAY_AGG`-aggregated vintage-flow variable
ids and costs, joined with the `expr_name` scenario table.

This avoids collecting individual rows and Julia-side grouping: the SQL
`GROUP BY scenario` + `ARRAY_AGG` produces arrays ready for direct use in
`attach_expression!`.
"""
function _query_vintage_flows_operational_cost_per_scenario_indices(connection, expr_name)
    return DuckDB.query(
        connection,
        """
        WITH rp_weight AS (
            SELECT
                milestone_year,
                rep_period,
                scenario,
                SUM(weight) AS total_weight_per_scenario
            FROM rep_periods_mapping
            GROUP BY milestone_year, rep_period, scenario
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
        ),
        vintage_flows_per_scenario AS (
            SELECT
                rp_weight.scenario,
                ARRAY_AGG(var.id ORDER BY var.id) AS var_vintage_flow_ids,
                ARRAY_AGG(
                    vint_obj.weight_for_operation_discounts
                    * rp_weight.total_weight_per_scenario
                    * rp_res.resolution
                    * (var.time_block_end - var.time_block_start + 1)
                    * vint_obj.total_variable_cost
                    ORDER BY var.id
                ) AS arr_cost
            FROM var_vintage_flow AS var
            LEFT JOIN vint_obj
                ON var.from_asset = vint_obj.from_asset
                AND var.to_asset = vint_obj.to_asset
                AND var.milestone_year = vint_obj.milestone_year
                AND var.commission_year = vint_obj.commission_year
            LEFT JOIN rp_weight
                ON var.milestone_year = rp_weight.milestone_year
                AND var.rep_period = rp_weight.rep_period
            LEFT JOIN rp_res
                ON var.milestone_year = rp_res.milestone_year
                AND var.rep_period = rp_res.rep_period
            GROUP BY rp_weight.scenario
        )
        SELECT
            expr.id,
            expr.scenario,
            expr.probability,
            COALESCE(vfps.var_vintage_flow_ids, []) AS var_vintage_flow_ids,
            COALESCE(vfps.arr_cost, []) AS arr_cost
        FROM expr_$expr_name AS expr
        LEFT JOIN vintage_flows_per_scenario AS vfps ON expr.scenario = vfps.scenario
        ORDER BY expr.id
        """,
    )
end

"""
    _query_units_on_operational_cost_per_scenario_indices(connection, expr_name)

Return one row per scenario with `ARRAY_AGG`-aggregated units-on variable ids
and costs, joined with the `expr_name` scenario table.

This avoids collecting individual rows and Julia-side grouping: the SQL
`GROUP BY scenario` + `ARRAY_AGG` produces arrays ready for direct use in
`attach_expression!`.
"""
function _query_units_on_operational_cost_per_scenario_indices(connection, expr_name)
    return DuckDB.query(
        connection,
        """
        WITH rp_weight AS (
            SELECT
                milestone_year,
                rep_period,
                scenario,
                SUM(weight) AS total_weight_per_scenario
            FROM rep_periods_mapping
            GROUP BY milestone_year, rep_period, scenario
        ),
        rp_res AS (
            SELECT
                milestone_year,
                rep_period,
                ANY_VALUE(resolution) AS resolution
            FROM rep_periods_data
            GROUP BY milestone_year, rep_period
        ),
        units_on_per_scenario AS (
            SELECT
                rp_weight.scenario,
                ARRAY_AGG(var.id ORDER BY var.id) AS var_units_on_ids,
                ARRAY_AGG(
                    obj.weight_for_operation_discounts
                    * rp_weight.total_weight_per_scenario
                    * rp_res.resolution
                    * (var.time_block_end - var.time_block_start + 1)
                    * obj.units_on_cost
                    ORDER BY var.id
                ) AS arr_cost
            FROM var_units_on AS var
            LEFT JOIN t_objective_assets AS obj
                ON var.asset = obj.asset
                AND var.milestone_year = obj.milestone_year
            LEFT JOIN rp_weight
                ON var.milestone_year = rp_weight.milestone_year
                AND var.rep_period = rp_weight.rep_period
            LEFT JOIN rp_res
                ON var.milestone_year = rp_res.milestone_year
                AND var.rep_period = rp_res.rep_period
            WHERE obj.units_on_cost IS NOT NULL
            GROUP BY rp_weight.scenario
        )
        SELECT
            expr.id,
            expr.scenario,
            expr.probability,
            COALESCE(uops.var_units_on_ids, []) AS var_units_on_ids,
            COALESCE(uops.arr_cost, []) AS arr_cost
        FROM expr_$expr_name AS expr
        LEFT JOIN units_on_per_scenario AS uops ON expr.scenario = uops.scenario
        ORDER BY expr.id
        """,
    )
end
