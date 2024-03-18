export add_balance_constraints!

function add_balance_constraints!(
    model,
    graph,
    dataframes,
    Ac,
    incoming_flow_highest_in_out_resolution,
    outgoing_flow_highest_in_out_resolution,
    incoming_flow_lowest_storage_resolution_intra_rp,
    outgoing_flow_lowest_storage_resolution_intra_rp,
    df_storage_intra_rp_balance_grouped,
    storage_level_intra_rp,
)
    # - consumer balance equation
    df = filter(row -> row.asset ∈ Ac, dataframes[:highest_in_out]; view = true)
    model[:consumer_balance] = [
        @constraint(
            model,
            incoming_flow_highest_in_out_resolution[row.index] -
            outgoing_flow_highest_in_out_resolution[row.index] ==
            profile_aggregation(
                Statistics.mean,
                graph[row.asset].rep_periods_profiles,
                (:demand, row.rp),
                row.timesteps_block,
                1.0,
            ) * graph[row.asset].peak_demand,
            base_name = "consumer_balance[$(row.asset),$(row.rp),$(row.timesteps_block)]"
        ) for row in eachrow(df)
    ]

    # - intra representative period (rp) storage balance equation
    for ((a, rp), sub_df) ∈ pairs(df_storage_intra_rp_balance_grouped)
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
            ) for (k, row) ∈ enumerate(eachrow(sub_df))
        ]
    end
end
