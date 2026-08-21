"""
    add_minimum_down_time_constraints!(connection, model, variables, expressions, constraints)

Adds the minimum down time constraints to the model.
"""
function add_minimum_down_time_constraints!(connection, model, variables, expressions, constraints)
    #Minimum down time with simple investment strategy
    let table_name = :minimum_down_time_aggregated_vintage_method,
        units_on = variables[:units_on].container,
        shut_down = variables[:shut_down].container,
        expr_avail_aggregated_vintage_method =
            expressions[:available_asset_units_aggregated_vintage_method].expressions[:assets],
        cons = constraints[table_name]

        indices = _get_indices_for_minimum_down_time_constraints_aggregated_vintage_method(
            connection,
            table_name,
        )

        attach_constraint!(
            model,
            cons,
            table_name,
            [
                @constraint(
                    model,
                    sum(shut_down[i] for i in row.first_shut_down_id:row.last_shut_down_id) <=
                    expr_avail_aggregated_vintage_method[row.avail_id] - units_on[row.units_on_id],
                    base_name = "$table_name[$(row.asset),$(row.milestone_year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]"
                ) for row in indices
            ],
        )
    end

    #Minimum down time with compact investment strategy
    let table_name = :minimum_down_time_compact_vintage_method,
        units_on = variables[:units_on].container,
        shut_down = variables[:shut_down].container,
        expr_avail_compact_method =
            expressions[:available_asset_units_compact_vintage_method].expressions[:assets],
        cons = constraints[table_name]

        indices = _get_indices_for_minimum_down_time_constraints_compact_vintage_method(
            connection,
            table_name,
        )

        attach_constraint!(
            model,
            cons,
            table_name,
            [
                @constraint(
                    model,
                    sum(shut_down[i] for i in row.first_shut_down_id:row.last_shut_down_id) <=
                    sum(expr_avail_compact_method[avail_id] for avail_id in row.avail_indices) -
                    units_on[row.units_on_id],
                    base_name = "$table_name[$(row.asset),$(row.milestone_year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]"
                ) for row in indices
            ],
        )
    end

    return nothing
end

function _get_indices_for_minimum_down_time_constraints_aggregated_vintage_method(
    connection,
    table_name,
)
    return DuckDB.query(
        connection,
        "WITH cons_with_lower_bound AS (
            SELECT
                cons.*,
                cons.time_block_start - CAST(CEIL(asset.minimum_down_time::DOUBLE / rep_periods_data.resolution::DOUBLE) AS INTEGER) + 1 AS lower_bound
            FROM cons_$table_name as cons
            LEFT JOIN asset ON
                asset.asset = cons.asset
            LEFT JOIN rep_periods_data
                ON rep_periods_data.milestone_year = cons.milestone_year
                AND rep_periods_data.rep_period = cons.rep_period
            WHERE asset.vintage_method = 'aggregated'
        )
        SELECT
            clb.id,
            clb.asset,
            clb.milestone_year,
            clb.rep_period,
            clb.time_block_start,
            ANY_VALUE(clb.time_block_end) AS time_block_end,
            ANY_VALUE(var_units_on.id) as units_on_id,
            ARG_MIN(var_shut_down.id, var_shut_down.time_block_start) FILTER (WHERE var_shut_down.time_block_start >= clb.lower_bound) AS first_shut_down_id,
            ANY_VALUE(var_shut_down.id) FILTER (WHERE var_shut_down.time_block_start = clb.time_block_start) AS last_shut_down_id,
            ANY_VALUE(expr_avail.id) AS avail_id
        FROM cons_with_lower_bound as clb
        INNER JOIN var_shut_down ON
            var_shut_down.asset = clb.asset AND
            var_shut_down.milestone_year = clb.milestone_year AND
            var_shut_down.rep_period = clb.rep_period
        INNER JOIN var_units_on ON
            var_units_on.asset = clb.asset AND
            var_units_on.milestone_year = clb.milestone_year AND
            var_units_on.rep_period = clb.rep_period AND
            var_units_on.time_block_start = clb.time_block_start
        LEFT JOIN expr_available_asset_units_aggregated_vintage_method AS expr_avail
            ON clb.asset = expr_avail.asset
            AND clb.milestone_year = expr_avail.milestone_year
        GROUP BY
            clb.id,
            clb.asset,
            clb.milestone_year,
            clb.rep_period,
            clb.time_block_start
        ORDER BY clb.id",
    )
end

function _get_indices_for_minimum_down_time_constraints_compact_vintage_method(
    connection,
    table_name,
)
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
            WHERE asset.vintage_method = 'compact_profiles'
        ),
        cons_with_shut_down_ids AS (
            SELECT
                clb.id,
                clb.asset,
                clb.milestone_year,
                clb.rep_period,
                clb.time_block_start,
                ANY_VALUE(clb.time_block_end) AS time_block_end,
                ANY_VALUE(var_units_on.id) as units_on_id,
                ARG_MIN(var_shut_down.id, var_shut_down.time_block_start) FILTER (WHERE var_shut_down.time_block_start >= clb.lower_bound) AS first_shut_down_id,
                ANY_VALUE(var_shut_down.id) FILTER (WHERE var_shut_down.time_block_start = clb.time_block_start) AS last_shut_down_id
            FROM cons_with_lower_bound as clb
            INNER JOIN var_shut_down ON
                var_shut_down.asset = clb.asset AND
                var_shut_down.milestone_year = clb.milestone_year AND
                var_shut_down.rep_period = clb.rep_period
            INNER JOIN var_units_on ON
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
        )
        SELECT
            csd.id,
            ANY_VALUE(csd.asset) AS asset,
            ANY_VALUE(csd.milestone_year) AS milestone_year,
            ANY_VALUE(csd.rep_period) AS rep_period,
            ANY_VALUE(csd.time_block_start) as time_block_start,
            ANY_VALUE(csd.time_block_end) as time_block_end,
            ANY_VALUE(csd.units_on_id) as units_on_id,
            ANY_VALUE(csd.first_shut_down_id) as first_shut_down_id,
            ANY_VALUE(csd.last_shut_down_id) as last_shut_down_id,
            ARRAY_AGG(expr_avail.id ORDER BY expr_avail.id) AS avail_indices
        FROM cons_with_shut_down_ids AS csd
        LEFT JOIN expr_available_asset_units_compact_vintage_method AS expr_avail
            ON csd.asset = expr_avail.asset
            AND csd.milestone_year = expr_avail.milestone_year
        GROUP BY csd.id
        ORDER BY csd.id
        ",
    )
end
