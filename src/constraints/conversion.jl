export add_conversion_constraints!

"""
add_conversion_constraints!(model,
                            dataframes,
                            Acv,
                            incoming_flow_lowest_resolution,
                            outgoing_flow_lowest_resolution,
                            )

Adds the conversion asset constraints to the model.
"""
function add_conversion_constraints!(model, constraints)
    # - Balance constraint (using the lowest temporal resolution)
    let table_name = :balance_conversion, cons = constraints[table_name]
        attach_constraint!(
            model,
            cons,
            table_name,
            [
                @constraint(
                    model,
                    incoming_flow == outgoing_flow,
                    base_name = "conversion_balance[$(row.asset),$(row.year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]"
                ) for (row, incoming_flow, outgoing_flow) in
                zip(eachrow(cons.indices), cons.expressions[:incoming], cons.expressions[:outgoing])
            ],
        )
    end

    return
end
