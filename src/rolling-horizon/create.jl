"""
    add_scalar_rolling_horizon_parameter!(model, variables, connection, param_table_name)

Create the rolling horizon Parameters for the table `param_table_name`.
This assumes that the table named `param_table_name` has a column
`original_value` and uses that as initial value for the variable.

The container is saved in the `model[key]` and the `TulipaVariable` for the
parameter is stored in `variables[key]`, where `key = Symbol(param_table_name)`.
"""
function add_scalar_rolling_horizon_parameter!(model, variables, connection, param_table_name)
    initial_value =
        [row.original_value::Float64 for row in DuckDB.query(connection, "FROM $param_table_name")]
    num_rows = length(initial_value)
    param = TulipaVariable(connection, param_table_name)
    param.container = @variable(model, [1:num_rows] in JuMP.Parameter.(initial_value))

    key = Symbol(param_table_name)
    model[key] = param.container
    variables[key] = param
    return param
end

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

    # Scalar rolling horizon parameters
    # These need a table filtering where time_block_start = 1, and the current
    # strategy is to create a table `param_NAME` and call
    # add_scalar_rolling_horizon_parameter!.

    ## initial_storage_level
    DuckDB.query(
        connection,
        """
        DROP SEQUENCE IF EXISTS id;
        CREATE SEQUENCE id START 1;
        CREATE OR REPLACE TABLE param_initial_storage_level AS
        SELECT
            nextval('id') as id,
            var.asset,
            var.milestone_year,
            var.rep_period,
            var.id as var_storage_id,
            asset_milestone.initial_storage_level as original_value
        FROM var_storage_level_rep_period as var
        LEFT JOIN asset_milestone
            ON var.asset = asset_milestone.asset
            AND var.milestone_year = asset_milestone.milestone_year
        WHERE time_block_start = 1;
        DROP SEQUENCE id;
        """,
    )
    add_scalar_rolling_horizon_parameter!(
        model,
        variables,
        connection,
        "param_initial_storage_level",
    )

    return
end
