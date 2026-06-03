"""
    add_min_output_flow_without_unit_commitment_constraints!(
        connection, model, expressions, constraints
    )

Adds the minimum output flow constraints for producer and conversion assets without
unit commitment and a positive `min_operating_point`.

The constraint enforces:
```
sum(capacity_coefficient * outgoing flows) >= min_operating_point [p.u.] * capacity [MW] * available_units [# of units]
```

This activates only when `unit_commitment = 'none'` and `min_operating_point > 0`.
Assets with unit commitment already enforce a minimum output flow through the
`min_output_flow_with_unit_commitment` constraint.

Note that the `capacity_coefficient` ensures that when output flows are scaled down in the capacity constraints,
they are also reflected in the minimum output flow constraint.
This is particularly useful for outputs like CO2 emissions,
which have a coefficient of zero because they do not contribute to the energy output flow and are regarded as byproducts.
"""
function add_min_output_flow_without_unit_commitment_constraints!(
    connection,
    model,
    expressions,
    constraints,
)
    expr_avail_aggregated_vintage_method =
        expressions[:available_asset_units_aggregated_vintage_method].expressions[:assets]
    expr_avail_compact_method =
        expressions[:available_asset_units_compact_vintage_method].expressions[:assets]

    # - Aggregated vintage method
    let table_name = :min_output_flow_without_unit_commitment_aggregated_vintage_method,
        cons = constraints[table_name]

        indices = _append_min_output_flow_data_to_indices_aggregated_vintage_method(
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
                    outgoing_flow ≥
                    row.min_operating_point *
                    row.capacity *
                    expr_avail_aggregated_vintage_method[row.avail_id],
                    base_name = "min_output_flow_without_unit_commitment_aggregated_vintage_method[$(row.asset),$(row.milestone_year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]"
                ) for (row, outgoing_flow) in zip(indices, cons.expressions[:outgoing])
            ],
        )
    end

    # - Compact profiles vintage method
    let table_name = :min_output_flow_without_unit_commitment_compact_vintage_method,
        cons = constraints[table_name]

        indices = _append_min_output_flow_data_to_indices_compact_method(connection, table_name)
        attach_constraint!(
            model,
            cons,
            table_name,
            [
                @constraint(
                    model,
                    outgoing_flow ≥
                    row.min_operating_point *
                    row.capacity *
                    sum(expr_avail_compact_method[avail_id] for avail_id in row.avail_indices),
                    base_name = "min_output_flow_without_unit_commitment_compact_vintage_method[$(row.asset),$(row.milestone_year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]"
                ) for (row, outgoing_flow) in zip(indices, cons.expressions[:outgoing])
            ],
        )
    end

    return
end

function _append_min_output_flow_data_to_indices_aggregated_vintage_method(connection, table_name)
    return DuckDB.query(
        connection,
        "SELECT
            cons.id,
            cons.asset,
            cons.milestone_year,
            cons.rep_period,
            cons.time_block_start,
            cons.time_block_end,
            asset.capacity,
            asset.min_operating_point,
            expr_avail.id AS avail_id,
        FROM cons_$table_name AS cons
        LEFT JOIN asset
            ON cons.asset = asset.asset
        LEFT JOIN expr_available_asset_units_aggregated_vintage_method AS expr_avail
            ON cons.asset = expr_avail.asset
            AND cons.milestone_year = expr_avail.milestone_year
        ORDER BY cons.id
        ",
    )
end

function _append_min_output_flow_data_to_indices_compact_method(connection, table_name)
    return DuckDB.query(
        connection,
        "SELECT
            cons.id,
            ANY_VALUE(cons.asset) AS asset,
            ANY_VALUE(cons.milestone_year) AS milestone_year,
            ANY_VALUE(cons.rep_period) AS rep_period,
            ANY_VALUE(cons.time_block_start) AS time_block_start,
            ANY_VALUE(cons.time_block_end) AS time_block_end,
            ANY_VALUE(asset.capacity) AS capacity,
            ANY_VALUE(asset.min_operating_point) AS min_operating_point,
            ARRAY_AGG(expr_avail.id ORDER BY expr_avail.id) AS avail_indices,
        FROM cons_$table_name AS cons
        LEFT JOIN asset
            ON cons.asset = asset.asset
        LEFT JOIN expr_available_asset_units_compact_vintage_method AS expr_avail
            ON cons.asset = expr_avail.asset
            AND cons.milestone_year = expr_avail.milestone_year
        GROUP BY cons.id
        ORDER BY cons.id
        ",
    )
end
