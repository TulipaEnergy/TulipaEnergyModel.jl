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
                begin
                    conversion_efficiency = row.conversion_efficiency::Float64
                    @constraint(
                        model,
                        conversion_efficiency * incoming_flow == outgoing_flow,
                        base_name = "conversion_balance[$(row.asset),$(row.milestone_year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]"
                    )
                end for (row, incoming_flow, outgoing_flow) in
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
            cons.id,
            cons.asset,
            cons.milestone_year,
            cons.rep_period,
            cons.time_block_start,
            cons.time_block_end,
            asset_commission.conversion_efficiency,
        FROM cons_$table_name AS cons
        LEFT JOIN asset_commission
            ON cons.asset = asset_commission.asset
            AND cons.milestone_year = asset_commission.commission_year
        ORDER BY cons.id
        ",
    )
end
