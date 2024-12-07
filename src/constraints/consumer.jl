export add_consumer_constraints!

"""
add_consumer_constraints!(model,
                          graph,
                          dataframes,
                          Ac,
                          incoming_flow_highest_in_out_resolution,
                          outgoing_flow_highest_in_out_resolution,
                          )

Adds the consumer asset constraints to the model.
"""

function add_consumer_constraints!(model, constraints, graph, sets)
    Ac = sets[:Ac]
    incoming_flow_highest_in_out_resolution = constraints[:highest_in_out].expressions[:incoming]
    outgoing_flow_highest_in_out_resolution = constraints[:highest_in_out].expressions[:outgoing]

    # - Balance constraint (using the lowest temporal resolution)
    df = filter(:asset => ∈(Ac), constraints[:highest_in_out].indices; view = true)
    model[:consumer_balance] = [
        @constraint(
            model,
            incoming_flow_highest_in_out_resolution[row.index] -
            outgoing_flow_highest_in_out_resolution[row.index] -
            profile_aggregation(
                Statistics.mean,
                graph[row.asset].rep_periods_profiles,
                row.year,
                row.year,
                ("demand", row.rep_period),
                row.time_block_start:row.time_block_end,
                1.0,
            ) * graph[row.asset].peak_demand[row.year] in
            graph[row.asset].consumer_balance_sense,
            base_name = "consumer_balance[$(row.asset),$(row.year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]"
        ) for row in eachrow(df)
    ]
end
