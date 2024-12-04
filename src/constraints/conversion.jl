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

function add_conversion_constraints!(model, constraints, sets)
    Acv = sets[:Acv]
    # - Balance constraint (using the lowest temporal resolution)
    df = filter(:asset => ∈(Acv), constraints[:lowest].indices; view = true)
    incoming = constraints[:lowest].expressions[:incoming]
    outgoing = constraints[:lowest].expressions[:outgoing]
    model[:conversion_balance] = [
        @constraint(
            model,
            incoming[row.index] == outgoing[row.index],
            base_name = "conversion_balance[$(row.asset),$(row.year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]"
        ) for row in eachrow(df)
    ]
end
