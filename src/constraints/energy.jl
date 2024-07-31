export add_energy_constraints!

"""
function add_energy_constraints!(model, graph, dataframes)

Adds the energy constraints for assets withnin the period blocks of the timeframe (inter-temporal) to the model.
"""

function add_energy_constraints!(model, graph, dataframes)

    ## INTER-TEMPORAL CONSTRAINTS (between representative periods)

    # - Maximum outgoing energy within each period block
    model[:max_energy_inter_rp] = [
        @constraint(
            model,
            dataframes[:max_energy_inter_rp].outgoing_flow[row.index] ≤
            profile_aggregation(
                sum,
                graph[row.asset].timeframe_profiles,
                "max_energy",
                row.periods_block,
                1.0,
            ) * (graph[row.asset].max_energy_timeframe_partition),
            base_name = "max_energy_inter_rp_limit[$(row.asset),$(row.periods_block)]"
        ) for row in eachrow(dataframes[:max_energy_inter_rp])
    ]

    # - Minimum outgoing energy within each period block
    model[:min_energy_inter_rp] = [
        @constraint(
            model,
            dataframes[:min_energy_inter_rp].outgoing_flow[row.index] ≥
            profile_aggregation(
                sum,
                graph[row.asset].timeframe_profiles,
                "min_energy",
                row.periods_block,
                1.0,
            ) * (graph[row.asset].min_energy_timeframe_partition),
            base_name = "min_energy_inter_rp_limit[$(row.asset),$(row.periods_block)]"
        ) for row in eachrow(dataframes[:min_energy_inter_rp])
    ]
end
