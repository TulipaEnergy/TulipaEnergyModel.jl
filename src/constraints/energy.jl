export add_energy_constraints!

"""
function add_energy_constraints!(model, graph, dataframes)

Adds the energy constraints for assets withnin the period blocks of the timeframe (inter-temporal) to the model.
"""

function add_energy_constraints!(model, constraints, graph)

    ## INTER-TEMPORAL CONSTRAINTS (between representative periods)

    # - Maximum outgoing energy within each period block
    model[:max_energy_inter_rp] = [
        @constraint(
            model,
            constraints[:max_energy_inter_rp].expressions[:outgoing][row.index] ≤
            profile_aggregation(
                sum,
                graph[row.asset].timeframe_profiles,
                row.year,
                row.year,
                "max_energy",
                row.period_block_start:row.period_block_end,
                1.0,
            ) * (graph[row.asset].max_energy_timeframe_partition[row.year]),
            base_name = "max_energy_inter_rp_limit[$(row.asset),$(row.year),$(row.period_block_start):$(row.period_block_end)]"
        ) for row in eachrow(constraints[:max_energy_inter_rp].indices)
    ]

    # - Minimum outgoing energy within each period block
    model[:min_energy_inter_rp] = [
        @constraint(
            model,
            constraints[:min_energy_inter_rp].expressions[:outgoing][row.index] ≥
            profile_aggregation(
                sum,
                graph[row.asset].timeframe_profiles,
                row.year,
                row.year,
                "min_energy",
                row.period_block_start:row.period_block_end,
                1.0,
            ) * (graph[row.asset].min_energy_timeframe_partition[row.year]),
            base_name = "min_energy_inter_rp_limit[$(row.asset),$(row.year),$(row.period_block_start):$(row.period_block_end)]"
        ) for row in eachrow(constraints[:min_energy_inter_rp].indices)
    ]
end
