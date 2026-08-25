"""
    _add_to_objective!(connection, objective_expr, name, expr)

Add `expr` to the running objective sum  and insert a placeholder row
in the `obj_breakdown` table (value filled in by `save_solution!` after the solve).
"""
function _add_to_objective!(connection, objective_expr, name::String, expr)
    DuckDB.execute(connection, "INSERT INTO obj_breakdown (name, value) VALUES (?, NULL)", [name])
    JuMP.add_to_expression!(objective_expr, expr)
    return
end

"""
    _query_costs(connection, query) -> Vector{Float64}

Run `query`, which must expose a `cost` column, and return that column as a
`Vector{Float64}`.
"""
function _query_costs(connection, query::String)
    return Float64[row.cost for row in DuckDB.query(connection, query)]
end

"""
    _cost_weighted_sum(costs, terms) -> JuMP.AffExpr

Return the affine expression `sum(cost * term)` over paired `costs` and `terms`,
where `terms` is any iterable of JuMP variables or affine expressions. Returns a
zero `AffExpr` when the inputs are empty.
"""
function _cost_weighted_sum(costs::Vector{Float64}, terms)
    result = JuMP.AffExpr(0.0)
    for (cost, term) in zip(costs, terms)
        JuMP.add_to_expression!(result, cost, term)
    end
    return result
end

"""
    add_objective!(connection, model, variables, expressions, model_parameters)

Build all objective components, register them in `obj_breakdown`, and set the
model objective to minimization of their sum.
"""
function add_objective!(connection, model, variables, expressions, model_parameters)
    lambda = model_parameters.lambda
    alpha = model_parameters.alpha

    ## Create obj_breakdown table (values populated by save_solution! after solve)
    DuckDB.execute(
        connection,
        """CREATE OR REPLACE TABLE obj_breakdown (
            name  VARCHAR,
            value FLOAT8
        )""",
    )
    objective_expr = JuMP.AffExpr(0.0)

    # Add components that do not depend on scenario
    _add_assets_investment_cost!(connection, model, variables, objective_expr)
    _add_assets_fixed_cost_compact_vintage_method!(connection, model, expressions, objective_expr)
    _add_assets_fixed_cost_aggregated_vintage_method!(
        connection,
        model,
        expressions,
        objective_expr,
    )
    _add_storage_assets_energy_investment_cost!(connection, model, variables, objective_expr)
    _add_storage_assets_energy_fixed_cost!(connection, model, expressions, objective_expr)
    _add_flows_investment_cost!(connection, model, variables, objective_expr)
    _add_flows_fixed_cost!(connection, model, expressions, objective_expr)

    # Add components that depend on scenario
    _add_flows_operational_cost!(connection, model, expressions, objective_expr, lambda)
    _add_vintage_flows_operational_cost!(connection, model, expressions, objective_expr, lambda)
    _add_units_on_operational_cost!(connection, model, expressions, objective_expr, lambda)
    _add_conditional_value_at_risk_term!(
        connection,
        model,
        variables,
        objective_expr,
        lambda,
        alpha,
    )

    @objective(model, Min, objective_expr)
end

"""
    _investment_discount_sql(; cost, discount_rate, economic_lifetime, milestone_year,
                             annualized, salvage, weight, end_of_horizon)

Return the `SELECT` columns computing the annualized cost, salvage value, and
investment discount weight for `cost`, using the `discount_rate`, `economic_lifetime`,
and `milestone_year` SQL expressions, aliased as `annualized`, `salvage`, and
`weight`. Shared by the asset (power and storage-energy) and flow investment terms.
Requires `investment_year_discount` to be defined earlier in the same `SELECT`.
"""
function _investment_discount_sql(;
    cost,
    discount_rate,
    economic_lifetime,
    milestone_year,
    annualized,
    salvage,
    weight,
    end_of_horizon,
)
    return """CASE
                -- the closed-form annuity does not accept a zero discount rate in the denominator
                WHEN $discount_rate = 0
                    THEN $cost / $economic_lifetime
                ELSE $discount_rate / (
                    1 - 1 / ((1 + $discount_rate) ** $economic_lifetime)
                    ) * $cost
            END AS $annualized,
            CASE
                WHEN $milestone_year + $economic_lifetime <= $end_of_horizon + 1
                    THEN 0.0
                -- the closed-form salvage does not accept a zero discount rate in the denominator
                WHEN $discount_rate = 0
                    THEN $annualized *
                        ($milestone_year + $economic_lifetime - $end_of_horizon - 1)
                ELSE -$annualized * (
                        (1 / (1 + $discount_rate)) ^ (
                            $milestone_year + $economic_lifetime - $end_of_horizon - 1
                        ) - 1
                    ) / $discount_rate
            END AS $salvage,
            CASE
                -- the weight does not accept a zero cost in the denominator
                WHEN $cost = 0
                    THEN 0.0 -- zero investment cost, so the weight does not matter
                ELSE investment_year_discount * (1 + $discount_rate - $salvage / $cost)
            END AS $weight"""
end

"""
    _discount_in_between_milestone_years_sql(keys, source_table, social_rate, discount_year)

Return the `WITH ... SELECT` query that computes, for the entity identified by
`keys` (e.g. `["asset"]` or `["from_asset", "to_asset"]`) read from `source_table`,
the total discount factor between each milestone year and the next:

    total_discount_factor[key, milestone_year]
        = ∑_[year = milestone_year : next_milestone_year - 1] discount_factor[key, year]
    where discount_factor[key, year] = 1 / (1 + social_rate)^(year - discount_year)

The sum covers `[milestone_year, next_milestone_year - 1]`, i.e. it excludes the
next milestone year.
"""
function _discount_in_between_milestone_years_sql(keys, source_table, social_rate, discount_year)
    key_columns = join(keys, ", ")
    key_columns_from_milestones = join(["m.$k" for k in keys], ", ")
    return """WITH milestones AS (
            SELECT
                $key_columns,
                milestone_year AS current_year,
                COALESCE(
                    LEAD(milestone_year) OVER (PARTITION BY $key_columns ORDER BY milestone_year),
                    milestone_year + 1
                ) AS next_year
            FROM $source_table
        ),
        years_in_between AS (
            SELECT
                $key_columns_from_milestones,
                m.current_year,
                in_between_years.year
            FROM milestones as m,
                LATERAL generate_series(m.current_year, m.next_year - 1) AS in_between_years(year)
        ),
        discounts AS (
            SELECT
                $key_columns,
                current_year as milestone_year,
                SUM(1 / (1 + $social_rate)^(year - $discount_year)) AS discount_factor_from_current_milestone_year_to_next_milestone_year
            FROM years_in_between
            GROUP BY $key_columns, milestone_year
        )
        SELECT
            *
        FROM discounts"""
end

"""
    prepare_objective_tables!(connection, model_parameters)

Create temporary SQL tables used by objective-term builders.

This precomputes discount-related auxiliary data and objective coefficient
tables so subsequent objective functions can read prepared inputs directly.
"""
function prepare_objective_tables!(connection, model_parameters)
    DuckDB.execute(
        connection,
        "CREATE OR REPLACE TEMP TABLE t_discount_assets_in_between_milestone_years AS $(_discount_in_between_milestone_years_sql(
            ["asset"],
            "asset_milestone",
            model_parameters.social_rate,
            model_parameters.discount_year,
        ))",
    )

    DuckDB.execute(
        connection,
        "CREATE OR REPLACE TEMP TABLE t_discount_flows_in_between_milestone_years AS $(_discount_in_between_milestone_years_sql(
            ["from_asset", "to_asset"],
            "flow_milestone",
            model_parameters.social_rate,
            model_parameters.discount_year,
        ))",
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
            1 / (1 + $(model_parameters.social_rate))^(asset_milestone.milestone_year - $(model_parameters.discount_year)) AS investment_year_discount,
            $(_investment_discount_sql(
                cost = "asset_commission.investment_cost",
                discount_rate = "asset.discount_rate",
                economic_lifetime = "asset.economic_lifetime",
                milestone_year = "asset_milestone.milestone_year",
                annualized = "annualized_cost",
                salvage = "salvage_value",
                weight = "weight_for_asset_investment_discount",
                end_of_horizon = model_parameters.end_of_horizon,
            )),
            $(_investment_discount_sql(
                cost = "asset_commission.investment_cost_storage_energy",
                discount_rate = "asset.discount_rate",
                economic_lifetime = "asset.economic_lifetime",
                milestone_year = "asset_milestone.milestone_year",
                annualized = "annualized_cost_storage_energy",
                salvage = "salvage_value_storage_energy",
                weight = "weight_for_asset_investment_energy_discount",
                end_of_horizon = model_parameters.end_of_horizon,
            )),
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
            flow_milestone.commodity_price,
            flow_commission.producer_efficiency,
            flow_milestone.operational_cost,
            -- computed
            (flow_milestone.commodity_price / flow_commission.producer_efficiency) AS fuel_cost,
            (fuel_cost + flow_milestone.operational_cost) AS total_variable_cost,
            1 / (1 + $(model_parameters.social_rate))^(flow_milestone.milestone_year - $(model_parameters.discount_year)) AS investment_year_discount,
            $(_investment_discount_sql(
                cost = "flow_commission.investment_cost",
                discount_rate = "flow.discount_rate",
                economic_lifetime = "flow.economic_lifetime",
                milestone_year = "flow_milestone.milestone_year",
                annualized = "annualized_cost",
                salvage = "salvage_value",
                weight = "weight_for_flow_investment_discount",
                end_of_horizon = model_parameters.end_of_horizon,
            )),
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
            flow_milestone.commodity_price,
            flow_commission.producer_efficiency,
            flow_milestone.operational_cost,
            -- computed
            (flow_milestone.commodity_price / flow_commission.producer_efficiency) AS fuel_cost,
            (fuel_cost + flow_milestone.operational_cost) AS total_variable_cost,
            1 / (1 + $(model_parameters.social_rate))^(flow_milestone.milestone_year - $(model_parameters.discount_year)) AS investment_year_discount,
            $(_investment_discount_sql(
                cost = "flow_commission.investment_cost",
                discount_rate = "flow.discount_rate",
                economic_lifetime = "flow.economic_lifetime",
                milestone_year = "flow_milestone.milestone_year",
                annualized = "annualized_cost",
                salvage = "salvage_value",
                weight = "weight_for_flow_investment_discount",
                end_of_horizon = model_parameters.end_of_horizon,
            )),
            in_between_years.discount_factor_from_current_milestone_year_to_next_milestone_year AS weight_for_operation_discounts,
        FROM var_vintage_flow AS var
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
        WHERE asset.vintage_method = 'compact_efficiencies'
        ",
    )

    return nothing
end
