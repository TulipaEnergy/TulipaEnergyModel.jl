function _add_vintage_flows_operational_cost!(connection, model, variables, objective_expr)
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
