export add_storage_constraints!

"""
add_storage_constraints!(model, graph,...)

Adds the storage asset constraints to the model.
"""

function add_storage_constraints!(model, variables, constraints, graph)
    var_storage_level_intra_rp = variables[:storage_level_intra_rp]
    var_storage_level_inter_rp = variables[:storage_level_inter_rp]

    accumulated_energy_capacity = model[:accumulated_energy_capacity]

    ## INTRA-TEMPORAL CONSTRAINTS (within a representative period)
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
                    initial_storage_level = graph[row.asset].initial_storage_level[row.year]

                    if row.time_block_start == 1 && !ismissing(initial_storage_level)
                        # Initial storage is a Float64
                        @constraint(
                            model,
                            var_storage_level[row.index] ==
                            initial_storage_level +
                            profile_agg * graph[row.asset].storage_inflows[row.year] +
                            incoming_flow - outgoing_flow,
                            base_name = "$table_name[$(row.asset),$(row.year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]"
                        )
                    else
                        # Initial storage is the previous level (a JuMP variable)
                        previous_level::JuMP.VariableRef = if row.time_block_start > 1
                            var_storage_level[row.index-1]
                        else
                            # Find last index of this group
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
                        end
                        @constraint(
                            model,
                            var_storage_level[row.index] ==
                            previous_level +
                            profile_agg * graph[row.asset].storage_inflows[row.year] +
                            incoming_flow - outgoing_flow,
                            base_name = "$table_name[$(row.asset),$(row.year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]"
                        )
                    end
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
                var_storage_level_intra_rp.container[row.index] ≤
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
            ) for row in eachrow(var_storage_level_intra_rp.indices)
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
                var_storage_level_intra_rp.container[row.index] ≥
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
            ) for row in eachrow(var_storage_level_intra_rp.indices)
        ],
    )

    ## INTER-TEMPORAL CONSTRAINTS (between representative periods)

    # - Balance constraint (using the lowest temporal resolution)
    let table_name = :balance_storage_over_clustered_year, cons = constraints[table_name]
        var_storage_level = variables[:storage_level_inter_rp].container

        # This assumes an ordering of the time blocks, that is guaranteed inside
        # construct_dataframes
        # The storage_inflows have been moved here
        attach_constraint!(
            model,
            cons,
            :balance_storage_over_clustered_year,
            [
                begin
                    initial_storage_level = graph[row.asset].initial_storage_level[row.year]

                    if row.period_block_start == 1 && !ismissing(initial_storage_level)
                        # Initial storage is a Float64
                        @constraint(
                            model,
                            var_storage_level_inter_rp.container[row.index] ==
                            initial_storage_level + inflows_agg + incoming_flow - outgoing_flow,
                            base_name = "$table_name[$(row.asset),$(row.year),$(row.period_block_start):$(row.period_block_end)]"
                        )
                    else
                        # Initial storage is the previous level (a JuMP variable)
                        previous_level::JuMP.VariableRef = if row.period_block_start > 1
                            var_storage_level[row.index-1]
                        else
                            # TODO: Replace by DuckDB call when working on #955
                            last_index = last(
                                DataFrames.subset(
                                    cons.indices,
                                    [:asset, :year] =>
                                        (a, y) -> a .== row.asset .&& y .== row.year;
                                    view = true,
                                ).index,
                            )
                            var_storage_level[last_index]
                        end

                        @constraint(
                            model,
                            var_storage_level_inter_rp.container[row.index] ==
                            previous_level + inflows_agg + incoming_flow - outgoing_flow,
                            base_name = "$table_name[$(row.asset),$(row.year),$(row.period_block_start):$(row.period_block_end)]"
                        )
                    end
                end for (row, incoming_flow, outgoing_flow, inflows_agg) in zip(
                    eachrow(cons.indices),
                    cons.expressions[:incoming],
                    cons.expressions[:outgoing],
                    cons.expressions[:inflows_profile_aggregation],
                )
            ],
        )
    end

    # - Maximum storage level
    attach_constraint!(
        model,
        constraints[:balance_storage_over_clustered_year],
        :max_storage_level_inter_rp_limit,
        [
            @constraint(
                model,
                var_storage_level_inter_rp.container[row.index] ≤
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
            ) for row in eachrow(var_storage_level_inter_rp.indices)
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
                var_storage_level_inter_rp.container[row.index] ≥
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
            ) for row in eachrow(var_storage_level_inter_rp.indices)
        ],
    )
end
