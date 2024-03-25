export add_storage_constraints!

"""
add_storage_constraints!(model,
                         graph,
                         dataframes,
                         Ai,
                         energy_limit,
                         incoming_flow_lowest_storage_resolution_intra_rp,
                         outgoing_flow_lowest_storage_resolution_intra_rp,
                         df_storage_intra_rp_balance_grouped,
                         df_storage_inter_rp_balance_grouped,
                         storage_level_intra_rp,
                         storage_level_inter_rp,
                         incoming_flow_storage_inter_rp_balance,
                         outgoing_flow_storage_inter_rp_balance,
                         )

Adds the storage asset constraints to the model.
"""

function add_storage_constraints!(
    model,
    graph,
    dataframes,
    Ai,
    energy_limit,
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
    for ((a, rp), sub_df) in pairs(df_storage_intra_rp_balance_grouped)
        # This assumes an ordering of the time blocks, that is guaranteed inside
        # construct_dataframes
        # The storage_inflows have been moved here
        model[Symbol("storage_intra_rp_balance_$(a)_$(rp)")] = [
            @constraint(
                model,
                storage_level_intra_rp[row.index] ==
                (
                    if k > 1
                        storage_level_intra_rp[row.index-1] # This assumes contiguous index
                    else
                        (
                            if ismissing(graph[a].initial_storage_level)
                                storage_level_intra_rp[last(sub_df.index)]
                            else
                                graph[a].initial_storage_level
                            end
                        )
                    end
                ) +
                profile_aggregation(
                    sum,
                    graph[a].rep_periods_profiles,
                    (:inflows, rp),
                    row.timesteps_block,
                    0.0,
                ) * graph[a].storage_inflows +
                incoming_flow_lowest_storage_resolution_intra_rp[row.index] -
                outgoing_flow_lowest_storage_resolution_intra_rp[row.index],
                base_name = "storage_intra_rp_balance[$a,$rp,$(row.timesteps_block)]"
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
                ("max-storage-level", row.rp),
                row.timesteps_block,
                1.0,
            ) * (
                graph[row.asset].initial_storage_capacity +
                (row.asset ∈ Ai ? energy_limit[row.asset] : 0.0)
            ),
            base_name = "max_storage_level_intra_rp_limit[$(row.asset),$(row.rp),$(row.timesteps_block)]"
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
                (:min_storage_level, row.rp),
                row.timesteps_block,
                0.0,
            ) * (
                graph[row.asset].initial_storage_capacity +
                (row.asset ∈ Ai ? energy_limit[row.asset] : 0.0)
            ),
            base_name = "min_storage_level_intra_rp_limit[$(row.asset),$(row.rp),$(row.timesteps_block)]"
        ) for row in eachrow(dataframes[:lowest_storage_level_intra_rp])
    ]

    # - Cycling condition
    for ((a, _), sub_df) in pairs(df_storage_intra_rp_balance_grouped)
        # Ordering is assumed
        if !ismissing(graph[a].initial_storage_level)
            JuMP.set_lower_bound(
                storage_level_intra_rp[last(sub_df.index)],
                graph[a].initial_storage_level,
            )
        end
    end

    ## INTER-TEMPORAL CONSTRAINTS (between representative periods)

    # - Balance constraint (using the lowest temporal resolution)
    for ((a,), sub_df) in pairs(df_storage_inter_rp_balance_grouped)
        # This assumes an ordering of the time blocks, that is guaranteed inside
        # construct_dataframes
        # The storage_inflows have been moved here
        model[Symbol("storage_inter_rp_balance_$(a)")] = [
            @constraint(
                model,
                storage_level_inter_rp[row.index] ==
                (
                    if k > 1
                        storage_level_inter_rp[row.index-1] # This assumes contiguous index
                    else
                        (
                            if ismissing(graph[a].initial_storage_level)
                                storage_level_inter_rp[last(sub_df.index)]
                            else
                                graph[a].initial_storage_level
                            end
                        )
                    end
                ) +
                row.inflows_profile_aggregation +
                incoming_flow_storage_inter_rp_balance[row.index] -
                outgoing_flow_storage_inter_rp_balance[row.index],
                base_name = "storage_inter_rp_balance[$a,$(row.periods_block)]"
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
                :max_storage_level,
                row.periods_block,
                1.0,
            ) * (
                graph[row.asset].initial_storage_capacity +
                (row.asset ∈ Ai ? energy_limit[row.asset] : 0.0)
            ),
            base_name = "max_storage_level_inter_rp_limit[$(row.asset),$(row.periods_block)]"
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
                :min_storage_level,
                row.periods_block,
                0.0,
            ) * (
                graph[row.asset].initial_storage_capacity +
                (row.asset ∈ Ai ? energy_limit[row.asset] : 0.0)
            ),
            base_name = "min_storage_level_inter_rp_limit[$(row.asset),$(row.periods_block)]"
        ) for row in eachrow(dataframes[:storage_level_inter_rp])
    ]

    # - Cycling condition
    for ((a,), sub_df) in pairs(df_storage_inter_rp_balance_grouped)
        # Ordering is assumed
        if !ismissing(graph[a].initial_storage_level)
            JuMP.set_lower_bound(
                storage_level_inter_rp[last(sub_df.index)],
                graph[a].initial_storage_level,
            )
        end
    end
end
