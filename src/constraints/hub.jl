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

function add_hub_constraints!(model, constraints, sets)
    Ah = sets[:Ah]
    incoming_flow_highest_in_out_resolution = constraints[:highest_in_out].expressions[:incoming]
    outgoing_flow_highest_in_out_resolution = constraints[:highest_in_out].expressions[:outgoing]
    # - Balance constraint (using the lowest temporal resolution)
    df = filter(:asset => ∈(Ah), constraints[:highest_in_out].indices; view = true)
    model[:hub_balance] = [
        @constraint(
            model,
            incoming_flow_highest_in_out_resolution[row.index] ==
            outgoing_flow_highest_in_out_resolution[row.index],
            base_name = "hub_balance[$(row.asset),$(row.year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]"
        ) for row in eachrow(df)
    ]
end
