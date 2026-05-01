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

Rows are queried once, grouped by scenario with `_scenario_ranges`, and then
accumulated into a `Vector{JuMP.AffExpr}` stored as
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
    expr_indices = DuckDB.query(connection, "FROM expr_$expr_name ORDER BY id") |> collect

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

    indices =
        _query_flows_operational_cost_per_scenario_indices(
            connection,
            has_commodity_price_profile,
        ) |> collect

    var_flow = variables[:flow].container
    n = length(indices)
    costs = Vector{Float64}(undef, n)
    for i in 1:n
        row = indices[i]
        if !has_commodity_price_profile || ismissing(row.profile_name)
            costs[i] = row.total_cost_if_no_profile::Float64
        else
            commodity_price_agg = _profile_aggregate(
                profiles.rep_period,
                (row.profile_name::String, row.milestone_year::Int32, row.rep_period::Int32),
                row.time_block_start:row.time_block_end,
                Statistics.mean,
                1.0,
            )
            costs[i] =
                row.cost_coefficient::Float64 *
                (
                    row.commodity_price::Float64 * commodity_price_agg /
                    row.producer_efficiency::Float64 + row.operational_cost::Float64
                ) *
                (row.time_block_end - row.time_block_start + 1)
        end
    end

    range_per_scenario = _scenario_ranges(indices)
    attach_expression!(
        expr,
        :cost,
        JuMP.AffExpr[
            if haskey(range_per_scenario, row.scenario)
                @expression(
                    model,
                    sum(
                        costs[i] * var_flow[indices[i].id::Int64] for
                        i in range_per_scenario[row.scenario]
                    ),
                )
            else
                @expression(model, 0.0)
            end for row in expr_indices
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

The resulting expression vector is indexed by scenario id order from
`stochastic_scenario` and reused by the objective and CVaR expression builders.
"""
function _add_vintage_flows_operational_cost_per_scenario_expressions!(
    connection,
    model,
    variables,
    expressions,
)
    expr_name = :vintage_flows_operational_cost_per_scenario
    expr = _create_scenario_cost_expression!(connection, expressions, expr_name)
    expr_indices = DuckDB.query(connection, "FROM expr_$expr_name ORDER BY id") |> collect

    indices = _query_vintage_flows_operational_cost_per_scenario_indices(connection) |> collect
    vintage_flow = variables[:vintage_flow].container
    range_per_scenario = _scenario_ranges(indices)

    attach_expression!(
        expr,
        :cost,
        JuMP.AffExpr[
            if length(row.var_vintage_flow_ids) > 0
                @expression(
                    model,
                    sum(
                        cost * vintage_flow[var_id::Int64]
                        for (cost, var_id) in zip(row.arr_cost, row.var_vintage_flow_ids)
                    ),
                )
            else
                @expression(model, 0.0)
            end for row in expr_indices
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

The function aggregates costs over all matching `var_units_on` rows for each
scenario and stores the result as `expressions[:units_on_operational_cost_per_scenario].expressions[:cost]`.
"""
function _add_units_on_operational_cost_per_scenario_expressions!(
    connection,
    model,
    variables,
    expressions,
)
    expr_name = :units_on_operational_cost_per_scenario
    expr = _create_scenario_cost_expression!(connection, expressions, expr_name)
    expr_indices = DuckDB.query(connection, "FROM expr_$expr_name ORDER BY id") |> collect

    indices = _query_units_on_operational_cost_per_scenario_indices(connection) |> collect
    units_on = variables[:units_on].container
    range_per_scenario = _scenario_ranges(indices)

    attach_expression!(
        expr,
        :cost,
        JuMP.AffExpr[
            if haskey(range_per_scenario, row.scenario)
                @expression(
                    model,
                    sum(
                        indices[i].cost * units_on[indices[i].id::Int64] for
                        i in range_per_scenario[row.scenario]
                    ),
                )
            else
                @expression(model, 0.0)
            end for row in expr_indices
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
    _scenario_ranges(indices)

Return a `Dict` mapping each scenario id to the contiguous `UnitRange` of row
positions it occupies in `indices`.

`indices` must be sorted by scenario (as guaranteed by the `ORDER BY scenario`
clause in every query that feeds this function). The function exploits that sort
to detect group boundaries in a single O(n) pass, avoiding the need for one
DuckDB query per scenario or an O(n × S) repeated scan.

The resulting dict is used by the per-scenario expression builders to slice
`indices` into per-scenario sub-arrays, which are then accumulated into
`JuMP.AffExpr` vectors — one expression per scenario — required by the CVaR
tail-excess constraint.
"""
function _scenario_ranges(indices)
    n = length(indices)
    if n == 0
        return Dict{Int32,UnitRange{Int}}()
    end

    scenario_ids = [row.scenario for row in indices]
    group_starts = [1; [i for i in 2:n if scenario_ids[i] != scenario_ids[i-1]]]
    group_ends = [group_starts[2:end] .- 1; n]
    scenarios = @view scenario_ids[group_starts]

    return Dict(scenarios[k] => group_starts[k]:group_ends[k] for k in eachindex(scenarios))
end

"""
    _query_flows_operational_cost_per_scenario_indices(connection, has_commodity_price_profile)

Return flow rows with scenario, variable id, and cost components needed to build
per-scenario flow operational-cost expressions.

The result is ordered by `(scenario, id)` to enable linear-time grouping.
"""
function _query_flows_operational_cost_per_scenario_indices(connection, has_commodity_price_profile)
    commodity_price_profile_name = ""
    flows_profiles_query_left_join = ""
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
    return DuckDB.query(
        connection,
        "WITH rp_weight AS (
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
        )
        SELECT
            rp_weight.scenario,
            var.id,
            obj.weight_for_operation_discounts
                * rp_weight.total_weight_per_scenario
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
        ORDER BY rp_weight.scenario, var.id",
    )
end

"""
    _query_vintage_flows_operational_cost_per_scenario_indices(connection)

Return vintage-flow rows with scenario, variable id, and cost coefficient used
to assemble per-scenario vintage-flow operational-cost expressions.

The result is ordered by `(scenario, id)`.
"""
function _query_vintage_flows_operational_cost_per_scenario_indices(connection)
    return DuckDB.query(
        connection,
        "WITH rp_weight AS (
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
        )
        SELECT
            rp_weight.scenario,
            var.id,
            vint_obj.weight_for_operation_discounts
                * rp_weight.total_weight_per_scenario
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
            ON var.milestone_year = rp_weight.milestone_year
            AND var.rep_period = rp_weight.rep_period
        LEFT JOIN rp_res
            ON var.milestone_year = rp_res.milestone_year
            AND var.rep_period = rp_res.rep_period
        ORDER BY rp_weight.scenario, var.id",
    )
end

"""
    _query_units_on_operational_cost_per_scenario_indices(connection)

Return units-on rows with scenario, variable id, and cost coefficient used to
assemble per-scenario units-on operational-cost expressions.

The result is ordered by `(scenario, id)`.
"""
function _query_units_on_operational_cost_per_scenario_indices(connection)
    return DuckDB.query(
        connection,
        "WITH rp_weight AS (
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
        )
        SELECT
            rp_weight.scenario,
            var.id,
            obj.weight_for_operation_discounts
                * rp_weight.total_weight_per_scenario
                * rp_res.resolution
                * (var.time_block_end - var.time_block_start + 1)
                * obj.units_on_cost
                AS cost
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
        ORDER BY rp_weight.scenario, var.id",
    )
end
