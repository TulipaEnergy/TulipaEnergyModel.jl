export add_hub_constraints!

"""
    add_hub_constraints!(model, constraints)

Adds the hub asset constraints to the model.
"""
function add_hub_constraints!(model, constraints)
    # - Balance constraint (using the lowest temporal resolution)
    let table_name = :balance_hub, cons = constraints[:balance_hub]
        attach_constraint!(
            model,
            cons,
            table_name,
            [
                @constraint(
                    model,
                    incoming_flow == outgoing_flow,
                    base_name = "$table_name[$(row.asset),$(row.year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]"
                ) for (row, incoming_flow, outgoing_flow) in
                zip(eachrow(cons.indices), cons.expressions[:incoming], cons.expressions[:outgoing])
            ],
        )
    end

    return
end
