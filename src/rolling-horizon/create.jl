
"""
    add_rolling_horizon_parameters!(connection, model, variables, profiles, window_length)

Create Parameters to handle rolling horizon.

The profile parameters are attached to `profiles.rep_period`.

The other parameters are the ones that have initial value (currently only initial_storage_level).
These must be filtered from the corresponding indices table when time_block_start = 1.
The corresponding parameters is saved in the variables and in the model.
"""
function add_rolling_horizon_parameters!(connection, model, variables, profiles, window_length)
    # Profiles
    for (_, profile_object) in profiles.rep_period
        profile_object.rolling_horizon_variables =
            @variable(model, [1:window_length] in JuMP.Parameter(0.0))
    end

    # initial_storage_level
    # Storing inside the variables, for now TODO: Review if there is a better strategy after all parameters have been defined
    DuckDB.query(
        connection,
        """
        DROP SEQUENCE IF EXISTS id;
        CREATE SEQUENCE id START 1;
        CREATE OR REPLACE TABLE param_initial_storage_level AS
        SELECT
            nextval('id') as id,
            var.asset,
            var.year,
            var.rep_period,
            var.id as var_storage_id,
            asset_milestone.initial_storage_level as original_value
        FROM var_storage_level_rep_period as var
        LEFT JOIN asset_milestone
            ON var.asset = asset_milestone.asset
            AND var.year = asset_milestone.milestone_year
        WHERE time_block_start = 1;
        DROP SEQUENCE id;
        """,
    )
    initial_storage_level = [
        row.original_value::Float64 for
        row in DuckDB.query(connection, "FROM param_initial_storage_level")
    ]
    num_rows = length(initial_storage_level)
    param = TulipaVariable(connection, "param_initial_storage_level")
    model[:param_initial_storage_level] =
        param.container = @variable(model, [1:num_rows] in JuMP.Parameter.(initial_storage_level))
    variables[:param_initial_storage_level] = param

    return
end
