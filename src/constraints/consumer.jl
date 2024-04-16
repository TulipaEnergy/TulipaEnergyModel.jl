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

    # Update the consumer balance constraint sense
    for a in Ac
        if !ismissing(graph[a].consumer_balance_sense) && graph[a].consumer_balance_sense == :>=
            graph[a].consumer_balance_sense = MathOptInterface.GreaterThan(0.0)
        else
            graph[a].consumer_balance_sense = MathOptInterface.EqualTo(0.0)
        end
    end

    # - Balance constraint (using the lowest temporal resolution)
    df = filter(row -> row.asset ∈ Ac, dataframes[:highest_in_out]; view = true)
    model[:consumer_balance] = [
        @constraint(
            model,
            incoming_flow_highest_in_out_resolution[row.index] -
            outgoing_flow_highest_in_out_resolution[row.index] -
            profile_aggregation(
                Statistics.mean,
                graph[row.asset].rep_periods_profiles,
                (:demand, row.rp),
                row.timesteps_block,
                1.0,
            ) * graph[row.asset].peak_demand in graph[row.asset].consumer_balance_sense,
            base_name = "consumer_balance[$(row.asset),$(row.rp),$(row.timesteps_block)]"
        ) for row in eachrow(df)
    ]
end
