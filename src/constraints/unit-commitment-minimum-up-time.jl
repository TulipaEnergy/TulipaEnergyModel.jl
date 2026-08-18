"""
    add_minimum_up_time_constraints!(connection, model, variables, expressions, constraints)

Adds the minimum up time constraints to the model.
"""
function add_minimum_up_time_constraints!(connection, model, variables, expressions, constraints)
    let table_name = :minimum_up_time,
        cons = constraints[:minimum_up_time],
        units_on = variables[:units_on].container,
        start_up = variables[:start_up].container,
        indices = _get_indices_for_minimum_up_time_constraints(connection, table_name)

        attach_constraint!(
            model,
            cons,
            table_name,
            [
                @constraint(
                    model,
                    sum(start_up[i] for i in row.first_start_up_id:row.last_start_up_id) <=
                    units_on[row.units_on_id],
                    base_name = "$table_name[$(row.asset),$(row.milestone_year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]"
                ) for row in indices
            ],
        )
    end

    return nothing
end

function _get_indices_for_minimum_up_time_constraints(connection, table_name)
    return DuckDB.query(
        connection,
        "WITH cons_with_lower_bound AS (
            SELECT
                cons.*,
                cons.time_block_start - CAST(CEIL(asset.minimum_up_time::DOUBLE / rep_periods_data.resolution::DOUBLE) AS INTEGER) + 1 AS lower_bound
            FROM cons_$table_name as cons
            LEFT JOIN asset ON
                asset.asset = cons.asset
            LEFT JOIN rep_periods_data
                ON rep_periods_data.milestone_year = cons.milestone_year
                AND rep_periods_data.rep_period = cons.rep_period
        )
        SELECT
            clb.id,
            clb.asset,
            clb.milestone_year,
            clb.rep_period,
            clb.time_block_start,
            ANY_VALUE(clb.time_block_end) AS time_block_end,
            ANY_VALUE(var_units_on.id) as units_on_id,
            ARG_MIN(var_start_up.id, var_start_up.time_block_start) FILTER (WHERE var_start_up.time_block_start >= clb.lower_bound) AS first_start_up_id,
            ANY_VALUE(var_start_up.id) FILTER (WHERE var_start_up.time_block_start = clb.time_block_start) AS last_start_up_id
        FROM cons_with_lower_bound as clb
        LEFT JOIN var_start_up ON
            var_start_up.asset = clb.asset AND
            var_start_up.milestone_year = clb.milestone_year AND
            var_start_up.rep_period = clb.rep_period
        LEFT JOIN var_units_on ON
            var_units_on.asset = clb.asset AND
            var_units_on.milestone_year = clb.milestone_year AND
            var_units_on.rep_period = clb.rep_period AND
            var_units_on.time_block_start = clb.time_block_start
        GROUP BY
            clb.id,
            clb.asset,
            clb.milestone_year,
            clb.rep_period,
            clb.time_block_start
        ORDER BY clb.id",
    )
end
