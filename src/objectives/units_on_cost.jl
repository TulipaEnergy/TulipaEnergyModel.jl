function _add_units_on_cost!(connection, model, variables, objective_expr, lambda)
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
                * (var.time_block_end - var.time_block_start + 1)
                * obj.units_on_cost
                AS cost
        FROM var_units_on AS var
        LEFT JOIN t_objective_assets as obj
            ON var.asset = obj.asset
            AND var.milestone_year = obj.milestone_year
        LEFT JOIN rp_weight_prob
            ON var.milestone_year = rp_weight_prob.milestone_year
            AND var.rep_period = rp_weight_prob.rep_period
        LEFT JOIN rp_res
            ON var.milestone_year = rp_res.milestone_year
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
    _add_to_objective!(
        connection,
        model,
        objective_expr,
        "units_on_cost",
        (1 - lambda) * units_on_cost,
    )

    return
end
