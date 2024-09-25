export add_storage_constraints!

"""
add_storage_constraints!(model, graph,...)

Adds the storage asset constraints to the model.
"""

function add_storage_constraints!(
    model,
    graph,
    dataframes,
    Ai,
    accumulated_energy_capacity,
    incoming_flow_lowest_storage_resolution_intra_rp,
    outgoing_flow_lowest_storage_resolution_intra_rp,
    df_storage_intra_rp_balance_grouped,
    df_storage_inter_rp_balance_grouped,
    storage_level_intra_rp,
    storage_level_inter_rp,
    incoming_flow_storage_inter_rp_balance,
    outgoing_flow_storage_inter_rp_balance,
)

    ## INTRA-TEMPORAL CONSTRAINTS (within a representative period)

    # - Balance constraint (using the lowest temporal resolution)
    for ((a, rp, y), sub_df) in pairs(df_storage_intra_rp_balance_grouped)
        # This assumes an ordering of the time blocks, that is guaranteed inside
        # construct_dataframes
        # The storage_inflows have been moved here
        model[Symbol("storage_intra_rp_balance_$(a)_$(y)_$(rp)")] = [
            @constraint(
                model,
                storage_level_intra_rp[row.index] ==
                (
                    if k > 1
                        storage_level_intra_rp[row.index-1] # This assumes contiguous index
                    else
                        (
                            if ismissing(graph[a].initial_storage_level[row.year])
                                storage_level_intra_rp[last(sub_df.index)]
                            else
                                graph[a].initial_storage_level[row.year]
                            end
                        )
                    end
                ) +
                profile_aggregation(
                    sum,
                    graph[a].rep_periods_profiles,
                    row.year,
                    row.year,
                    ("inflows", rp),
                    row.timesteps_block,
                    0.0,
                ) * graph[a].storage_inflows[row.year] +
                incoming_flow_lowest_storage_resolution_intra_rp[row.index] -
                outgoing_flow_lowest_storage_resolution_intra_rp[row.index],
                base_name = "storage_intra_rp_balance[$a,$y,$rp,$(row.timesteps_block)]"
            ) for (k, row) in enumerate(eachrow(sub_df))
        ]
    end

    # - Maximum storage level
    model[:max_storage_level_intra_rp_limit] = [
        @constraint(
            model,
            storage_level_intra_rp[row.index] ≤
            profile_aggregation(
                Statistics.mean,
                graph[row.asset].rep_periods_profiles,
                row.year,
                row.year,
                ("max-storage-level", row.rep_period),
                row.timesteps_block,
                1.0,
            ) * accumulated_energy_capacity[row.year, row.asset],
            base_name = "max_storage_level_intra_rp_limit[$(row.asset),$(row.year),$(row.rep_period),$(row.timesteps_block)]"
        ) for row in eachrow(dataframes[:lowest_storage_level_intra_rp])
    ]

    # - Minimum storage level
    model[:min_storage_level_intra_rp_limit] = [
        @constraint(
            model,
            storage_level_intra_rp[row.index] ≥
            profile_aggregation(
                Statistics.mean,
                graph[row.asset].rep_periods_profiles,
                row.year,
                row.year,
                ("min_storage_level", row.rep_period),
                row.timesteps_block,
                0.0,
            ) * accumulated_energy_capacity[row.year, row.asset],
            base_name = "min_storage_level_intra_rp_limit[$(row.asset),$(row.year),$(row.rep_period),$(row.timesteps_block)]"
        ) for row in eachrow(dataframes[:lowest_storage_level_intra_rp])
    ]

    # - Cycling condition
    for ((a, _, y), sub_df) in pairs(df_storage_intra_rp_balance_grouped)
        # Ordering is assumed
        if !ismissing(graph[a].initial_storage_level[y])
            JuMP.set_lower_bound(
                storage_level_intra_rp[last(sub_df.index)],
                graph[a].initial_storage_level[y],
            )
        end
    end

    ## INTER-TEMPORAL CONSTRAINTS (between representative periods)

    # - Balance constraint (using the lowest temporal resolution)
    for ((a, y), sub_df) in pairs(df_storage_inter_rp_balance_grouped)
        # This assumes an ordering of the time blocks, that is guaranteed inside
        # construct_dataframes
        # The storage_inflows have been moved here
        model[Symbol("storage_inter_rp_balance_$(a)_$(y)")] = [
            @constraint(
                model,
                storage_level_inter_rp[row.index] ==
                (
                    if k > 1
                        storage_level_inter_rp[row.index-1] # This assumes contiguous index
                    else
                        (
                            if ismissing(graph[a].initial_storage_level[row.year])
                                storage_level_inter_rp[last(sub_df.index)]
                            else
                                graph[a].initial_storage_level[row.year]
                            end
                        )
                    end
                ) +
                row.inflows_profile_aggregation +
                incoming_flow_storage_inter_rp_balance[row.index] -
                outgoing_flow_storage_inter_rp_balance[row.index],
                base_name = "storage_inter_rp_balance[$a,$(row.year),$(row.periods_block)]"
            ) for (k, row) in enumerate(eachrow(sub_df))
        ]
    end

    # - Maximum storage level
    model[:max_storage_level_inter_rp_limit] = [
        @constraint(
            model,
            storage_level_inter_rp[row.index] ≤
            profile_aggregation(
                Statistics.mean,
                graph[row.asset].timeframe_profiles,
                row.year,
                row.year,
                "max_storage_level",
                row.periods_block,
                1.0,
            ) * accumulated_energy_capacity[row.year, row.asset],
            base_name = "max_storage_level_inter_rp_limit[$(row.asset),$(row.year),$(row.periods_block)]"
        ) for row in eachrow(dataframes[:storage_level_inter_rp])
    ]

    # - Minimum storage level
    model[:min_storage_level_inter_rp_limit] = [
        @constraint(
            model,
            storage_level_inter_rp[row.index] ≥
            profile_aggregation(
                Statistics.mean,
                graph[row.asset].timeframe_profiles,
                row.year,
                row.year,
                "min_storage_level",
                row.periods_block,
                0.0,
            ) * accumulated_energy_capacity[row.year, row.asset],
            base_name = "min_storage_level_inter_rp_limit[$(row.asset),$(row.year),$(row.periods_block)]"
        ) for row in eachrow(dataframes[:storage_level_inter_rp])
    ]

    # - Cycling condition
    for ((a, y), sub_df) in pairs(df_storage_inter_rp_balance_grouped)
        # Ordering is assumed
        if !ismissing(graph[a].initial_storage_level[y])
            JuMP.set_lower_bound(
                storage_level_inter_rp[last(sub_df.index)],
                graph[a].initial_storage_level[y],
            )
        end
    end
end
