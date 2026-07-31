"""
    _add_demand_response_penalty!(connection, model, variables, objective_expr, lambda)

Add the demand response transaction cost term to the objective. Only the upward
demand deviation `d⁺` is penalized, weighted per representative period by the
operational discount factor, the expected representative-period weight, the
representative-period resolution, and the block duration:

`(1 − λ) · ∑_b w_{y,p} · c^DR · Δ_b · d⁺_b`
"""
function _add_demand_response_penalty!(connection, model, variables, objective_expr, lambda)
    d_increase = variables[:dr_demand_increase].container

    penalty = JuMP.AffExpr(0.0)
    for row in DuckDB.query(
        connection,
        "WITH rp_weight AS (
            SELECT
                rpm.milestone_year,
                rpm.rep_period,
                SUM(ss.probability * rpm.weight) AS eff_weight
            FROM rep_periods_mapping AS rpm
            LEFT JOIN stochastic_scenario AS ss
                ON rpm.scenario = ss.scenario
            GROUP BY rpm.milestone_year, rpm.rep_period
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
            dr.id,
            obj.weight_for_operation_discounts
                * rp_weight.eff_weight
                * rp_res.resolution
                * asset_milestone.dr_transaction_cost
                * (dr.time_block_end - dr.time_block_start + 1)
                AS coefficient,
        FROM var_dr_demand_increase AS dr
        LEFT JOIN asset_milestone
            ON dr.asset = asset_milestone.asset
            AND dr.milestone_year = asset_milestone.milestone_year
        LEFT JOIN t_objective_assets AS obj
            ON dr.asset = obj.asset
            AND dr.milestone_year = obj.milestone_year
        LEFT JOIN rp_weight
            ON dr.milestone_year = rp_weight.milestone_year
            AND dr.rep_period = rp_weight.rep_period
        LEFT JOIN rp_res
            ON dr.milestone_year = rp_res.milestone_year
            AND dr.rep_period = rp_res.rep_period
        ORDER BY dr.id
        ",
    )
        JuMP.add_to_expression!(penalty, row.coefficient::Float64, d_increase[row.id::Int64])
    end

    @expression(model, demand_response_transaction_cost, (1 - lambda) * penalty)
    _add_to_objective!(
        connection,
        objective_expr,
        "demand_response_transaction_cost",
        demand_response_transaction_cost,
    )

    return nothing
end
