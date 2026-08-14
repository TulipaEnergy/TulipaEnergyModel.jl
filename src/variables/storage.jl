"""
    add_storage_variables!(connection, model, variables)

Adds storage-related variables to the optimization `model`, including storage levels for both within rep-period and inter-period, as well as charging state variables.
The function also optionally sets binary constraints for certain charging variables based on storage methods.
"""
function add_storage_variables!(connection, model, variables)
    storage_level_intra_rep_period_indices = variables[:storage_level_intra_rep_period].indices
    storage_level_inter_period_indices = variables[:storage_level_inter_period].indices
    accumulated_storage_level_intra_rep_period_indices =
        variables[:accumulated_storage_level_intra_rep_period].indices
    max_storage_level_increase_intra_rep_period_indices =
        variables[:max_storage_level_increase_intra_rep_period].indices
    max_storage_level_decrease_intra_rep_period_indices =
        variables[:max_storage_level_decrease_intra_rep_period].indices
    is_charging_indices = variables[:is_charging].indices

    variables[:storage_level_intra_rep_period].container = [
        @variable(
            model,
            lower_bound = 0.0,
            base_name = "storage_level_intra_rep_period[$(row.asset),$(row.milestone_year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]"
        ) for row in storage_level_intra_rep_period_indices
    ]

    variables[:storage_level_inter_period].container = [
        @variable(
            model,
            lower_bound = 0.0,
            base_name = "storage_level_inter_period[$(row.asset),$(row.milestone_year),$(row.scenario),$(row.period_block_start):$(row.period_block_end)]"
        ) for row in storage_level_inter_period_indices
    ]

    variables[:accumulated_storage_level_intra_rep_period].container = [
        @variable(
            model,
            base_name = "accumulated_storage_level_intra_rep_period[$(row.asset),$(row.milestone_year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]"
        ) for row in accumulated_storage_level_intra_rep_period_indices
    ]

    variables[:max_storage_level_increase_intra_rep_period].container = [
        @variable(
            model,
            lower_bound = 0.0,
            base_name = "max_storage_level_increase_intra_rep_period[$(row.asset),$(row.milestone_year),$(row.rep_period)]"
        ) for row in max_storage_level_increase_intra_rep_period_indices
    ]

    variables[:max_storage_level_decrease_intra_rep_period].container = [
        @variable(
            model,
            lower_bound = 0.0,
            base_name = "max_storage_level_decrease_intra_rep_period[$(row.asset),$(row.milestone_year),$(row.rep_period)]"
        ) for row in max_storage_level_decrease_intra_rep_period_indices
    ]

    variables[:is_charging].container = [
        @variable(
            model,
            lower_bound = 0.0,
            upper_bound = 1.0,
            binary = row.use_binary_storage_method == "binary",
            base_name = "is_charging[$(row.asset),$(row.milestone_year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]"
        ) for row in is_charging_indices
    ]

    return
end
