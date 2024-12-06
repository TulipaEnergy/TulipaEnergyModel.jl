export add_hub_constraints!

"""
add_hub_constraints!(model,
                     dataframes,
                     Ah,
                     incoming_flow_highest_in_out_resolution,
                     outgoing_flow_highest_in_out_resolution,
                     )

Adds the hub asset constraints to the model.
"""

function add_hub_constraints!(model, constraints)
    cons = constraints[:balance_hub]
    incoming_flow_highest_in_out_resolution = cons.expressions[:incoming]
    outgoing_flow_highest_in_out_resolution = cons.expressions[:outgoing]

    # - Balance constraint (using the lowest temporal resolution)
    model[:hub_balance] = [
        @constraint(
            model,
            incoming_flow_highest_in_out_resolution[row.index] ==
            outgoing_flow_highest_in_out_resolution[row.index],
            base_name = "hub_balance[$(row.asset),$(row.year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]"
        ) for row in eachrow(cons.indices)
    ]
end
