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
    return nothing
end

function _append_available_units_simple_method(connection, table_name)
    return DuckDB.query(
        connection,
        "SELECT
            cons.*,
            expr_avail.id AS avail_id,
        FROM cons_$table_name AS cons
        LEFT JOIN expr_available_asset_units_simple_method AS expr_avail
            ON cons.asset = expr_avail.asset
            AND cons.year = expr_avail.milestone_year
        LEFT JOIN asset
            ON cons.asset = asset.asset
        WHERE asset.investment_method in ('simple', 'none')
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
