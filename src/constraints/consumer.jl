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

function add_consumer_constraints!(
    model,
    graph,
    dataframes,
    Ac,
    incoming_flow_highest_in_out_resolution,
    outgoing_flow_highest_in_out_resolution,
)

    # - Balance constraint (using the lowest temporal resolution)
    df = filter(:asset => ∈(Ac), dataframes[:highest_in_out]; view = true)
    model[:consumer_balance] = [
        @constraint(
            model,
            incoming_flow_highest_in_out_resolution[row.index] -
            outgoing_flow_highest_in_out_resolution[row.index] -
            profile_aggregation(
                Statistics.mean,
                graph[row.asset].rep_periods_profiles,
                (:demand, row.rep_period),
                row.timesteps_block,
                1.0,
            ) * graph[row.asset].peak_demand in graph[row.asset].consumer_balance_sense,
            base_name = "consumer_balance[$(row.asset),$(row.rep_period),$(row.timesteps_block)]"
        ) for row in eachrow(df)
    ]
end
