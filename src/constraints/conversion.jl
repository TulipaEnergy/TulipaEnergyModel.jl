export add_conversion_constraints!

"""
    add_conversion_constraints!(connection, model, constraints)

Adds the conversion asset constraints to the model.
"""
function add_conversion_constraints!(connection, model, constraints)
    # - Balance constraint (using the lowest temporal resolution)
    let table_name = :balance_conversion, cons = constraints[table_name]
        indices = _append_conversion_data_to_indices(connection, table_name)
        attach_constraint!(
            model,
            cons,
            table_name,
            [
                @constraint(
                    model,
                    row.conversion_efficiency * incoming_flow == outgoing_flow,
                    base_name = "conversion_balance[$(row.asset),$(row.year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]"
                ) for (row, incoming_flow, outgoing_flow) in
                zip(indices, cons.expressions[:incoming], cons.expressions[:outgoing])
            ],
        )
    end

    return
end

function _append_conversion_data_to_indices(connection, table_name)
    return DuckDB.query(
        connection,
        "SELECT
            cons.*,
            asset_commission.conversion_efficiency,
        FROM cons_$table_name AS cons
        LEFT JOIN asset_commission
            ON cons.asset = asset_commission.asset
            AND cons.year = asset_commission.commission_year
        ORDER BY cons.id
        ",
    )
end
