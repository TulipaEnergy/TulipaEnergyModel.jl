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

function add_hub_constraints!(
    model,
    dataframes,
    Ah,
    incoming_flow_highest_in_out_resolution,
    outgoing_flow_highest_in_out_resolution,
)

    # - Balance constraint (using the lowest temporal resolution)
    df = filter(:asset => ∈(Ah), dataframes[:highest_in_out]; view = true)
    model[:hub_balance] = [
        @constraint(
            model,
            incoming_flow_highest_in_out_resolution[row.index] ==
            outgoing_flow_highest_in_out_resolution[row.index],
            base_name = "hub_balance[$(row.asset),$(row.rp),$(row.timesteps_block)]"
        ) for row in eachrow(df)
    ]
end
