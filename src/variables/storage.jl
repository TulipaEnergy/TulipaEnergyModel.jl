export add_storage_variables!

"""
    add_storage_variables!(model, ...)

Adds storage-related variables to the optimization `model`, including storage levels for both intra-representative periods and inter-representative periods, as well as charging state variables.
The function also optionally sets binary constraints for certain charging variables based on storage methods.

"""
function add_storage_variables!(model, graph, variables)
    storage_level_rep_period_indices = variables[:storage_level_rep_period].indices
    storage_level_over_clustered_year_indices =
        variables[:storage_level_over_clustered_year].indices
    is_charging_indices = variables[:is_charging].indices

    variables[:storage_level_rep_period].container = [
        @variable(
            model,
            lower_bound = 0.0,
            base_name = "storage_level_rep_period[$(row.asset),$(row.year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]"
        ) for row in eachrow(storage_level_rep_period_indices)
    ]

    variables[:storage_level_over_clustered_year].container = [
        @variable(
            model,
            lower_bound = 0.0,
            base_name = "storage_level_over_clustered_year[$(row.asset),$(row.year),$(row.period_block_start):$(row.period_block_end)]"
        ) for row in eachrow(storage_level_over_clustered_year_indices)
    ]

    variables[:is_charging].container = [
        @variable(
            model,
            lower_bound = 0.0,
            upper_bound = 1.0,
            binary = row.use_binary_storage_method == "binary",
            base_name = "is_charging[$(row.asset),$(row.year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]"
        ) for row in eachrow(is_charging_indices)
    ]

    ### Cycling conditions
    df_storage_rep_period_balance_grouped =
        DataFrames.groupby(storage_level_rep_period_indices, [:asset, :year, :rep_period])

    df_storage_over_clustered_year_balance_grouped =
        DataFrames.groupby(storage_level_over_clustered_year_indices, [:asset, :year])

    for ((a, y, _), sub_df) in pairs(df_storage_rep_period_balance_grouped)
        # Ordering is assumed
        if !ismissing(graph[a].initial_storage_level[y])
            JuMP.set_lower_bound(
                variables[:storage_level_rep_period].container[last(sub_df.index)],
                graph[a].initial_storage_level[y],
            )
        end
    end

    for ((a, y), sub_df) in pairs(df_storage_over_clustered_year_balance_grouped)
        # Ordering is assumed
        if !ismissing(graph[a].initial_storage_level[y])
            JuMP.set_lower_bound(
                variables[:storage_level_over_clustered_year].container[last(sub_df.index)],
                graph[a].initial_storage_level[y],
            )
        end
    end

    return
end
