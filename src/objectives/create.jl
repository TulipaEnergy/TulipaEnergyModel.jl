export add_objective!

"""
    _add_to_objective!(connection, model, objective_expr, name, expr)

Add `expr` to the running objective sum, register it on the model under `name`, and
insert a placeholder row in the `obj_breakdown` table (value filled in by
`save_solution!` after the solve).
"""
function _add_to_objective!(connection, model, objective_expr, name::String, expr)
    DuckDB.execute(connection, "INSERT INTO obj_breakdown (name, value) VALUES (?, NULL)", [name])
    model[Symbol(name)] = expr
    JuMP.add_to_expression!(objective_expr, expr)
    return
end

function add_objective!(connection, model, variables, expressions, profiles)
    row = only(collect(DuckDB.query(connection, "SELECT * FROM model_parameters")))

    social_rate = row.discount_rate

    discount_year_input = row.discount_year
    if discount_year_input == 9999 # default value
        discount_year = get_single_element_from_query_and_ensure_its_only_one(
            connection,
            "SELECT MIN(milestone_year) AS end_of_horizon FROM rep_periods_data",
        )::Int32
        DuckDB.execute(connection, "UPDATE model_parameters SET discount_year = $discount_year")
    else
        discount_year = discount_year_input
    end

    lambda = row.risk_aversion_weight_lambda
    alpha = row.risk_aversion_confidence_level_alpha
    end_of_horizon = get_single_element_from_query_and_ensure_its_only_one(
        connection,
        "SELECT MAX(milestone_year) AS end_of_horizon FROM rep_periods_data",
    )::Int32

    constants = (; social_rate, discount_year, end_of_horizon)

    _create_objective_auxiliary_table(connection, constants)

    ## Create obj_breakdown table (values populated by save_solution! after solve)
    DuckDB.execute(
        connection,
        """CREATE OR REPLACE TABLE obj_breakdown (
            name  VARCHAR,
            value FLOAT8
        )""",
    )
    objective_expr = JuMP.AffExpr(0.0)

    _add_assets_investment_cost!(connection, model, variables, objective_expr, lambda)
    _add_assets_fixed_cost_compact_method!(connection, model, expressions, objective_expr, lambda)
    _add_assets_fixed_cost_simple_method!(connection, model, expressions, objective_expr, lambda)
    _add_storage_assets_energy_investment_cost!(
        connection,
        model,
        variables,
        objective_expr,
        lambda,
    )
    _add_storage_assets_energy_fixed_cost!(connection, model, expressions, objective_expr, lambda)
    _add_flows_investment_cost!(connection, model, variables, objective_expr, lambda)
    _add_flows_fixed_cost!(connection, model, expressions, objective_expr, lambda)
    _add_flows_operational_cost!(connection, model, variables, profiles, objective_expr, lambda)
    _add_vintage_flows_operational_cost!(connection, model, variables, objective_expr, lambda)
    _add_units_on_cost!(connection, model, variables, objective_expr, lambda)
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
        "CREATE OR REPLACE TEMP TABLE t_discount_assets_in_between_milestone_years AS
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
        "CREATE OR REPLACE TEMP TABLE t_discount_flows_in_between_milestone_years AS
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
            CASE
                -- the below closed-form equation does not accept 0 in the denominator when asset.discount_rate = 0
                WHEN asset.discount_rate = 0
                    THEN asset_commission.investment_cost / asset.economic_lifetime
                ELSE asset.discount_rate / (
                    (1 + asset.discount_rate) *
                    (1 - 1 / ((1 + asset.discount_rate) ** asset.economic_lifetime))
                    ) * asset_commission.investment_cost
            END AS annualized_cost,
            CASE
                WHEN asset_milestone.milestone_year + asset.economic_lifetime <= $(constants.end_of_horizon) + 1
                    THEN 0.0
                -- the below closed-form equation does not accept asset.discount_rate = 0 in the denominator
                WHEN asset.discount_rate = 0
                    THEN annualized_cost *
                        (asset_milestone.milestone_year + asset.economic_lifetime - $(constants.end_of_horizon) - 1)
                ELSE -annualized_cost * (
                        (1 / (1 + asset.discount_rate)) ^ (
                            asset_milestone.milestone_year + asset.economic_lifetime - $(constants.end_of_horizon) - 1
                        ) - 1
                    ) / asset.discount_rate
            END AS salvage_value,
            1 / (1 + $(constants.social_rate))^(asset_milestone.milestone_year - $(constants.discount_year)) AS investment_year_discount,
            CASE
                -- the below calculation does not accept asset_commission.investment_cost = 0 in the denominator
                WHEN asset_commission.investment_cost = 0
                    THEN 0.0 -- in this case, the investment cost is 0, so the weight does not matter
                ELSE investment_year_discount * (1 - salvage_value / asset_commission.investment_cost)
            END AS weight_for_asset_investment_discount,
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
            CASE
                -- the below closed-form equation does not accept 0 in the denominator when flow.discount_rate = 0
                WHEN flow.discount_rate = 0
                    THEN flow_commission.investment_cost / flow.economic_lifetime
                ELSE flow.discount_rate / (
                    (1 + flow.discount_rate) *
                    (1 - 1 / ((1 + flow.discount_rate) ** flow.economic_lifetime))
                    ) * flow_commission.investment_cost
            END AS annualized_cost,
            CASE
                WHEN flow_milestone.milestone_year + flow.economic_lifetime <= $(constants.end_of_horizon) + 1
                    THEN 0.0
                -- the below closed-form equation does not accept flow.discount_rate = 0 in the denominator
                WHEN flow.discount_rate = 0
                    THEN annualized_cost *
                        (flow_milestone.milestone_year + flow.economic_lifetime - $(constants.end_of_horizon) - 1)
                ELSE -annualized_cost * (
                        (1 / (1 + flow.discount_rate)) ^ (
                            flow_milestone.milestone_year + flow.economic_lifetime - $(constants.end_of_horizon) - 1
                        ) - 1
                    ) / flow.discount_rate
            END AS salvage_value,
            1 / (1 + $(constants.social_rate))^(flow_milestone.milestone_year - $(constants.discount_year)) AS investment_year_discount,
            CASE
                -- the below calculation does not accept flow_commission.investment_cost = 0 in the denominator
                WHEN flow_commission.investment_cost = 0
                    THEN 0.0 -- in this case, the investment cost is 0, so the weight does not matter
                ELSE investment_year_discount * (1 - salvage_value / flow_commission.investment_cost)
            END AS weight_for_flow_investment_discount,
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
            CASE
                -- the below closed-form equation does not accept 0 in the denominator when flow.discount_rate = 0
                WHEN flow.discount_rate = 0
                    THEN flow_commission.investment_cost / flow.economic_lifetime
                ELSE flow.discount_rate / (
                    (1 + flow.discount_rate) *
                    (1 - 1 / ((1 + flow.discount_rate) ** flow.economic_lifetime))
                    ) * flow_commission.investment_cost
            END AS annualized_cost,
            CASE
                WHEN flow_milestone.milestone_year + flow.economic_lifetime <= $(constants.end_of_horizon) + 1
                    THEN 0.0
                -- the below closed-form equation does not accept flow.discount_rate = 0 in the denominator
                WHEN flow.discount_rate = 0
                    THEN annualized_cost *
                        (flow_milestone.milestone_year + flow.economic_lifetime - $(constants.end_of_horizon) - 1)
                ELSE -annualized_cost * (
                        (1 / (1 + flow.discount_rate)) ^ (
                            flow_milestone.milestone_year + flow.economic_lifetime - $(constants.end_of_horizon) - 1
                        ) - 1
                    ) / flow.discount_rate
            END AS salvage_value,
            1 / (1 + $(constants.social_rate))^(flow_milestone.milestone_year - $(constants.discount_year)) AS investment_year_discount,
            CASE
                -- the below calculation does not accept flow_commission.investment_cost = 0 in the denominator
                WHEN flow_commission.investment_cost = 0
                    THEN 0.0 -- in this case, the investment cost is 0, so the weight does not matter
                ELSE investment_year_discount * (1 - salvage_value / flow_commission.investment_cost)
            END AS weight_for_flow_investment_discount,
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
        WHERE asset.investment_method = 'semi-compact'
        ",
    )

    return
end
