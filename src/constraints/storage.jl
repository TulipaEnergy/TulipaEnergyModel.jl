export add_storage_constraints!

"""
add_storage_constraints!(model, graph,...)

Adds the storage asset constraints to the model.
"""

function add_storage_constraints!(model, variables, constraints, graph)

    ## INTRA-TEMPORAL CONSTRAINTS (within a representative period)
    storage_level_intra_rp = variables[:storage_level_intra_rp]
    df_storage_intra_rp_balance_grouped =
        DataFrames.groupby(storage_level_intra_rp.indices, [:asset, :year, :rep_period])

    storage_level_inter_rp = variables[:storage_level_inter_rp]
    df_storage_inter_rp_balance_grouped =
        DataFrames.groupby(storage_level_inter_rp.indices, [:asset, :year])

    accumulated_energy_capacity = model[:accumulated_energy_capacity]
    incoming_flow_lowest_storage_resolution_intra_rp =
        constraints[:balance_storage_rep_period].expressions[:incoming]
    outgoing_flow_lowest_storage_resolution_intra_rp =
        constraints[:balance_storage_rep_period].expressions[:outgoing]
    incoming_flow_storage_inter_rp_balance =
        constraints[:balance_storage_over_clustered_year].expressions[:incoming]
    outgoing_flow_storage_inter_rp_balance =
        constraints[:balance_storage_over_clustered_year].expressions[:outgoing]

    # - Balance constraint (using the lowest temporal resolution)
    let table_name = :balance_storage_rep_period, cons = constraints[table_name]
        var_storage_level = variables[:storage_level_intra_rp].container
        attach_constraint!(
            model,
            cons,
            :balance_storage_rep_period,
            [
                begin
                    profile_agg = profile_aggregation(
                        sum,
                        graph[row.asset].rep_periods_profiles,
                        row.year,
                        row.year,
                        ("inflows", row.rep_period),
                        row.time_block_start:row.time_block_end,
                        0.0,
                    )
                    # TODO: Does this aux_value has a more significant name
                    previous_level = if row.time_block_start == 1
                        # Find last index of this group
                        if ismissing(graph[row.asset].initial_storage_level[row.year])
                            # TODO: Replace by DuckDB call when working on #955
                            last_index = last(
                                DataFrames.subset(
                                    cons.indices,
                                    [:asset, :year, :rep_period] =>
                                        (a, y, rp) ->
                                            a .== row.asset .&&
                                            y .== row.year .&&
                                            rp .== row.rep_period;
                                    view = true,
                                ).index,
                            )
                            var_storage_level[last_index]
                        else
                            graph[row.asset].initial_storage_level[row.year]
                        end
                    else
                        var_storage_level[row.index-1]
                    end
                    @constraint(
                        model,
                        var_storage_level[row.index] ==
                        previous_level +
                        profile_agg * graph[row.asset].storage_inflows[row.year] +
                        incoming_flow - outgoing_flow,
                        base_name = "$table_name[$(row.asset),$(row.year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]"
                    )
                end for (row, incoming_flow, outgoing_flow) in
                zip(eachrow(cons.indices), cons.expressions[:incoming], cons.expressions[:outgoing])
            ],
        )
    end

    # - Maximum storage level
    attach_constraint!(
        model,
        constraints[:balance_storage_rep_period],
        :max_storage_level_intra_rp_limit,
        [
            @constraint(
                model,
                storage_level_intra_rp.container[row.index] ≤
                profile_aggregation(
                    Statistics.mean,
                    graph[row.asset].rep_periods_profiles,
                    row.year,
                    row.year,
                    ("max-storage-level", row.rep_period),
                    row.time_block_start:row.time_block_end,
                    1.0,
                ) * accumulated_energy_capacity[row.year, row.asset],
                base_name = "max_storage_level_intra_rp_limit[$(row.asset),$(row.year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]"
            ) for row in eachrow(storage_level_intra_rp.indices)
        ],
    )

    # - Minimum storage level
    attach_constraint!(
        model,
        constraints[:balance_storage_rep_period],
        :min_storage_level_intra_rp_limit,
        [
            @constraint(
                model,
                storage_level_intra_rp.container[row.index] ≥
                profile_aggregation(
                    Statistics.mean,
                    graph[row.asset].rep_periods_profiles,
                    row.year,
                    row.year,
                    ("min_storage_level", row.rep_period),
                    row.time_block_start:row.time_block_end,
                    0.0,
                ) * accumulated_energy_capacity[row.year, row.asset],
                base_name = "min_storage_level_intra_rp_limit[$(row.asset),$(row.year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]"
            ) for row in eachrow(storage_level_intra_rp.indices)
        ],
    )

    # - Cycling condition
    for ((a, y, _), sub_df) in pairs(df_storage_intra_rp_balance_grouped)
        # Ordering is assumed
        if !ismissing(graph[a].initial_storage_level[y])
            JuMP.set_lower_bound(
                storage_level_intra_rp.container[last(sub_df.index)],
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
                storage_level_inter_rp.container[row.index] ==
                (
                    if k > 1
                        storage_level_inter_rp.container[row.index-1] # This assumes contiguous index
                    else
                        (
                            if ismissing(graph[a].initial_storage_level[row.year])
                                storage_level_inter_rp.container[last(sub_df.index)]
                            else
                                graph[a].initial_storage_level[row.year]
                            end
                        )
                    end
                ) +
                constraints[:balance_storage_over_clustered_year].expressions[:inflows_profile_aggregation][row.index] +
                incoming_flow_storage_inter_rp_balance[row.index] -
                outgoing_flow_storage_inter_rp_balance[row.index],
                base_name = "storage_inter_rp_balance[$a,$(row.year),$(row.period_block_start):$(row.period_block_end)]"
            ) for (k, row) in enumerate(eachrow(sub_df))
        ]
    end

    # - Maximum storage level
    attach_constraint!(
        model,
        constraints[:balance_storage_over_clustered_year],
        :max_storage_level_inter_rp_limit,
        [
            @constraint(
                model,
                storage_level_inter_rp.container[row.index] ≤
                profile_aggregation(
                    Statistics.mean,
                    graph[row.asset].timeframe_profiles,
                    row.year,
                    row.year,
                    "max_storage_level",
                    row.period_block_start:row.period_block_end,
                    1.0,
                ) * accumulated_energy_capacity[row.year, row.asset],
                base_name = "max_storage_level_inter_rp_limit[$(row.asset),$(row.year),$(row.period_block_start):$(row.period_block_end)]"
            ) for row in eachrow(storage_level_inter_rp.indices)
        ],
    )

    # - Minimum storage level
    attach_constraint!(
        model,
        constraints[:balance_storage_over_clustered_year],
        :min_storage_level_inter_rp_limit,
        [
            @constraint(
                model,
                storage_level_inter_rp.container[row.index] ≥
                profile_aggregation(
                    Statistics.mean,
                    graph[row.asset].timeframe_profiles,
                    row.year,
                    row.year,
                    "min_storage_level",
                    row.period_block_start:row.period_block_end,
                    0.0,
                ) * accumulated_energy_capacity[row.year, row.asset],
                base_name = "min_storage_level_inter_rp_limit[$(row.asset),$(row.year),$(row.period_block_start):$(row.period_block_end)]"
            ) for row in eachrow(storage_level_inter_rp.indices)
        ],
    )

    # - Cycling condition
    for ((a, y), sub_df) in pairs(df_storage_inter_rp_balance_grouped)
        # Ordering is assumed
        if !ismissing(graph[a].initial_storage_level[y])
            JuMP.set_lower_bound(
                storage_level_inter_rp.container[last(sub_df.index)],
                graph[a].initial_storage_level[y],
            )
        end
    end
end
