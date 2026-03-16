export add_shut_down_upper_bound_constraints!

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
