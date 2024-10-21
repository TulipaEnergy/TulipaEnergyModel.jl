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

function add_conversion_constraints!(
    model,
    dataframes,
    sets,
    incoming_flow_lowest_resolution,
    outgoing_flow_lowest_resolution,
)
    Acv = sets[:Acv]
    # - Balance constraint (using the lowest temporal resolution)
    df = filter(:asset => ∈(Acv), dataframes[:lowest]; view = true)
    model[:conversion_balance] = [
        @constraint(
            model,
            incoming_flow_lowest_resolution[row.index] ==
            outgoing_flow_lowest_resolution[row.index],
            base_name = "conversion_balance[$(row.asset),$(row.year),$(row.rep_period),$(row.timesteps_block)]"
        ) for row in eachrow(df)
    ]
end
