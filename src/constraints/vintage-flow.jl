export add_vintage_flow_sum_constraints!

"""
    add_vintage_flow_sum_constraints!(connection, model, variables, constraints)

Adds the vintage flow sum constraints to the model.
"""
function add_vintage_flow_sum_constraints!(connection, model, variables, constraints)
    let table_name = :vintage_flow_sum_semi_compact_method,
        cons = constraints[:vintage_flow_sum_semi_compact_method]

        indices = _append_vintage_flow_data_to_indices(connection, table_name)

        var_flow = variables[:flow].container
        var_vintage_flow = variables[:vintage_flow].container

        attach_constraint!(
            model,
            cons,
            table_name,
            [
                @constraint(
                    model,
                    var_flow[row.var_flow_id] ==
                    sum(var_vintage_flow[idx] for idx in row.var_vintage_flow_indices),
                    base_name = "$table_name[$(row.from_asset),$(row.to_asset),$(row.year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]"
                ) for row in indices
            ],
        )
    end
end

function _append_vintage_flow_data_to_indices(connection, table_name)
    return DuckDB.query(
        connection,
        "
        WITH grouped_var_flow AS (
            SELECT from_asset, to_asset, year, rep_period, time_block_start, ANY_VALUE(id) AS id
            FROM var_flow
            GROUP BY from_asset, to_asset, year, rep_period, time_block_start
        ),
        grouped_var_vintage_flow AS (
            SELECT from_asset, to_asset, milestone_year, rep_period, time_block_start, ARRAY_AGG(id) AS ids
            FROM var_vintage_flow
            GROUP BY from_asset, to_asset, milestone_year, rep_period, time_block_start
        )
        SELECT
            cons.id,
            cons.from_asset,
            cons.to_asset,
            cons.year,
            cons.rep_period,
            cons.time_block_start,
            cons.time_block_end,
            var_flow.id AS var_flow_id,
            var_vintage_flow.ids AS var_vintage_flow_indices,
        FROM cons_$table_name AS cons
        LEFT JOIN grouped_var_flow as var_flow
            ON cons.from_asset = var_flow.from_asset
            AND cons.to_asset = var_flow.to_asset
            AND cons.year = var_flow.year
            AND cons.rep_period = var_flow.rep_period
            AND cons.time_block_start = var_flow.time_block_start
        LEFT JOIN grouped_var_vintage_flow as var_vintage_flow
            ON var_vintage_flow.from_asset = cons.from_asset
            AND var_vintage_flow.to_asset = cons.to_asset
            AND var_vintage_flow.milestone_year = cons.year
            AND var_vintage_flow.rep_period = cons.rep_period
            AND var_vintage_flow.time_block_start = cons.time_block_start
        ORDER BY cons.id
        ",
    )
end
