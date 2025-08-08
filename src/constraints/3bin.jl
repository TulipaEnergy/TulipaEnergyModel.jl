export add_start_up_and_shut_down_constraints!

function add_start_up_and_shut_down_constraints!(
    connection,
    model,
    variables,
    expressions,
    constraints,
)
    add_start_up_upper_bound_constraints!(connection, model, variables, expressions, constraints)
    add_shut_down_upper_bound_constraints!(connection, model, variables, expressions, constraints)
    add_su_sd_eq_units_on_diff_constraints!(connection, model, variables, expressions, constraints)
    return
end

"""
    add_start_up_upper_bound_constraints!(model, constraints)

    Adds the start up upper bound constraints to the model.
"""
function add_start_up_upper_bound_constraints!(
    connection,
    model,
    variables,
    expressions,
    constraints,
)
    let table_name = :start_up_upper_bound,
        cons = constraints[:start_up_upper_bound],
        start_up_vars = variables[:start_up].container,
        units_on_vars = variables[:units_on].container

        indices = _append_variable_ids(connection, table_name, ["units_on", "start_up"])

        attach_constraint!(
            model,
            cons,
            table_name,
            [
                @constraint(
                    model,
                    start_up_vars[row.start_up_id] <= units_on_vars[row.units_on_id],
                    base_name = "$table_name[$(row.asset),$(row.year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]"
                ) for row in indices
            ],
        )
    end
end

"""
    add_shut_down_upper_bound_constraints!(model, constraints)

Adds the shut down constraints to the model.
"""
function add_shut_down_upper_bound_constraints!(
    connection,
    model,
    variables,
    expressions,
    constraints,
)
    let table_name = :shut_down_upper_bound_simple_investment, cons = constraints[table_name]
        expr_avail_simple_method =
            expressions[:available_asset_units_simple_method].expressions[:assets]

        indices = _append_available_units_shut_down_simple_method(connection, table_name)

        units_on_vars = variables[:units_on].container
        shut_down_vars = variables[:shut_down].container

        attach_constraint!(
            model,
            cons,
            table_name,
            [
                @constraint(
                    model,
                    shut_down_vars[row.shut_down_id] <=
                    expr_avail_simple_method[row.avail_id] - units_on_vars[row.units_on_id],
                    base_name = "$table_name[$(row.asset),$(row.year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]"
                ) for row in indices
            ],
        )
    end

    let table_name = :shut_down_upper_bound_compact_investment, cons = constraints[table_name]
        expr_avail_compact_method =
            expressions[:available_asset_units_compact_method].expressions[:assets]

        indices = _append_available_units_shut_down_compact_method(connection, table_name)

        units_on_vars = variables[:units_on].container
        shut_down_vars = variables[:shut_down].container

        attach_constraint!(
            model,
            cons,
            table_name,
            [
                @constraint(
                    model,
                    shut_down_vars[row.shut_down_id] <=
                    sum(expr_avail_compact_method[avail_id] for avail_id in row.avail_indices) -
                    units_on_vars[row.units_on_id],
                    base_name = "$table_name[$(row.asset),$(row.year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]"
                ) for row in indices
            ],
        )
    end

    return nothing
end

function _append_available_units_shut_down_simple_method(connection, table_name)
    return DuckDB.query(
        connection,
        "SELECT
            cons.*,
            expr_avail.id AS avail_id,
            var_units_on.id as units_on_id,
            var_shut_down.id as shut_down_id
        FROM cons_$table_name AS cons
        LEFT JOIN expr_available_asset_units_simple_method AS expr_avail
            ON cons.asset = expr_avail.asset
            AND cons.year = expr_avail.milestone_year
        LEFT JOIN asset
            ON cons.asset = asset.asset
        LEFT JOIN var_units_on
            ON var_units_on.asset = cons.asset
            AND var_units_on.year = cons.year
            AND var_units_on.rep_period = cons.rep_period
            AND var_units_on.time_block_start = cons.time_block_start
        LEFT JOIN var_shut_down
            ON var_shut_down.asset = cons.asset
            AND var_shut_down.year = cons.year
            AND var_shut_down.rep_period = cons.rep_period
            AND var_shut_down.time_block_start = cons.time_block_start
        WHERE asset.investment_method in ('simple', 'none')
        ORDER BY cons.id
        ",
    )
end

function _append_available_units_shut_down_compact_method(connection, table_name)
    return DuckDB.query(
        connection,
        "SELECT
            cons.id,
            ANY_VALUE(cons.asset) AS asset,
            ANY_VALUE(cons.year) AS year,
            ANY_VALUE(cons.rep_period) AS rep_period,
            ANY_VALUE(cons.time_block_start) AS time_block_start,
            ANY_VALUE(cons.time_block_end) AS time_block_end,
            ARRAY_AGG(expr_avail.id) AS avail_indices,
            ANY_VALUE(var_units_on.id) AS units_on_id,
            ANY_VALUE(var_shut_down.id) AS shut_down_id
        FROM cons_$table_name AS cons
        LEFT JOIN expr_available_asset_units_compact_method AS expr_avail
            ON cons.asset = expr_avail.asset
            AND cons.year = expr_avail.milestone_year
        LEFT JOIN asset
            ON cons.asset = asset.asset
        LEFT JOIN var_units_on
            ON var_units_on.asset = cons.asset
            AND var_units_on.year = cons.year
            AND var_units_on.rep_period = cons.rep_period
            AND var_units_on.time_block_start = cons.time_block_start
        LEFT JOIN var_shut_down
            ON var_shut_down.asset = cons.asset
            AND var_shut_down.year = cons.year
            AND var_shut_down.rep_period = cons.rep_period
            AND var_shut_down.time_block_start = cons.time_block_start
        WHERE asset.investment_method = 'compact'
        GROUP BY cons.id
        ORDER BY cons.id
        ",
    )
end

"""
    add_su_sd_eq_units_on_diff_constraints!(model, constraints)

Adds the start up - shut down = units_on difference to the model.
"""
function add_su_sd_eq_units_on_diff_constraints!(
    connection,
    model,
    variables,
    expressions,
    constraints,
)
    let table_name = :su_sd_eq_units_on_diff, cons = constraints[:su_sd_eq_units_on_diff]
        units_on = variables[:units_on].container
        start_up = variables[:start_up].container
        shut_down = variables[:shut_down].container

        indices =
            _append_variable_ids(connection, table_name, ["units_on", "start_up", "shut_down"])

        attach_constraint!(
            model,
            cons,
            table_name,
            [
                begin
                    if row.time_block_start == 1
                        @constraint(model, 0 == 0)
                    else
                        @constraint(
                            model,
                            units_on[row.units_on_id] - units_on[row.units_on_id-1] ==
                            start_up[row.start_up_id] - shut_down[row.shut_down_id],
                            base_name = "$table_name[$(row.asset),$(row.year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]"
                        )
                    end
                end for row in indices
            ],
        )
    end
end
