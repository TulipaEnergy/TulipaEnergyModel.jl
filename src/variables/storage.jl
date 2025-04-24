export add_storage_variables!

"""
    add_storage_variables!(connection, model, variables)

Adds storage-related variables to the optimization `model`, including storage levels for both within rep-period and over-clustered-year, as well as charging state variables.
The function also optionally sets binary constraints for certain charging variables based on storage methods.
"""
function add_storage_variables!(connection, model, variables)
    storage_level_rep_period_indices = variables[:storage_level_rep_period].indices
    storage_level_over_clustered_year_indices =
        variables[:storage_level_over_clustered_year].indices
    is_charging_indices = variables[:is_charging].indices

    variables[:storage_level_rep_period].container = [
        @variable(
            model,
            lower_bound = 0.0,
            base_name = "storage_level_rep_period[$(row.asset),$(row.year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]"
        ) for row in storage_level_rep_period_indices
    ]

    variables[:storage_level_over_clustered_year].container = [
        @variable(
            model,
            lower_bound = 0.0,
            base_name = "storage_level_over_clustered_year[$(row.asset),$(row.year),$(row.period_block_start):$(row.period_block_end)]"
        ) for row in storage_level_over_clustered_year_indices
    ]

    variables[:is_charging].container = [
        @variable(
            model,
            lower_bound = 0.0,
            upper_bound = 1.0,
            binary = row.use_binary_storage_method == "binary",
            base_name = "is_charging[$(row.asset),$(row.year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]"
        ) for row in is_charging_indices
    ]

    ### Cycling conditions
    let var = variables[:storage_level_rep_period]
        table_name = var.table_name
        for row in DuckDB.query(
            connection,
            "SELECT
                last(var.id) AS last_id,
                var.asset, var.year, var.rep_period,
                ANY_VALUE(asset_milestone.initial_storage_level) AS initial_storage_level,
            FROM $table_name AS var
            LEFT JOIN asset_milestone
                ON var.asset = asset_milestone.asset
                AND var.year = asset_milestone.milestone_year
            WHERE asset_milestone.initial_storage_level IS NOT NULL
            GROUP BY var.asset, var.year, var.rep_period
            ",
        )
            JuMP.set_lower_bound(var.container[row.last_id], row.initial_storage_level)
        end
    end

    let var = variables[:storage_level_over_clustered_year]
        table_name = var.table_name
        for row in DuckDB.query(
            connection,
            "SELECT
                last(var.id) AS last_id,
                var.asset, var.year,
                ANY_VALUE(asset_milestone.initial_storage_level) AS initial_storage_level,
            FROM $table_name AS var
            LEFT JOIN asset_milestone
                ON var.asset = asset_milestone.asset
                AND var.year = asset_milestone.milestone_year
            WHERE asset_milestone.initial_storage_level IS NOT NULL
            GROUP BY var.asset, var.year
            ",
        )
            JuMP.set_lower_bound(var.container[row.last_id], row.initial_storage_level)
        end
    end

    return
end
