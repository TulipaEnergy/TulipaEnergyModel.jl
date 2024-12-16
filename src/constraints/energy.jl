export add_energy_constraints!

"""
function add_energy_constraints!(model, graph, dataframes)

Adds the energy constraints for assets withnin the period blocks of the timeframe (inter-temporal) to the model.
"""

function add_energy_constraints!(model, constraints, graph)
    ## INTER-TEMPORAL CONSTRAINTS (between representative periods)

    let table_name = :max_energy_over_clustered_year, cons = constraints[table_name]
        # - Maximum outgoing energy within each period block
        attach_constraint!(
            model,
            cons,
            table_name,
            [
                @constraint(
                    model,
                    outgoing_flow ≤
                    profile_aggregation(
                        sum,
                        graph[row.asset].timeframe_profiles,
                        row.year,
                        row.year,
                        "max_energy",
                        row.period_block_start:row.period_block_end,
                        1.0,
                    ) * (graph[row.asset].max_energy_timeframe_partition[row.year]),
                    base_name = "$table_name[$(row.asset),$(row.year),$(row.period_block_start):$(row.period_block_end)]"
                ) for
                (row, outgoing_flow) in zip(eachrow(cons.indices), cons.expressions[:outgoing])
            ],
        )
    end

    let table_name = :min_energy_over_clustered_year, cons = constraints[table_name]
        # - Minimum outgoing energy within each period block
        attach_constraint!(
            model,
            cons,
            table_name,
            [
                @constraint(
                    model,
                    outgoing_flow ≥
                    profile_aggregation(
                        sum,
                        graph[row.asset].timeframe_profiles,
                        row.year,
                        row.year,
                        "min_energy",
                        row.period_block_start:row.period_block_end,
                        1.0,
                    ) * (graph[row.asset].min_energy_timeframe_partition[row.year]),
                    base_name = "$table_name[$(row.asset),$(row.year),$(row.period_block_start):$(row.period_block_end)]"
                ) for
                (row, outgoing_flow) in zip(eachrow(cons.indices), cons.expressions[:outgoing])
            ],
        )
    end
end
