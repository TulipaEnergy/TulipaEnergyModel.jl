export create_internal_structures!, export_solution_to_csv_files

"""
    create_internal_structures!(connection)

Return the `graph`, `representative_periods`, and `timeframe` structures given the input dataframes structure.

The details of these structures are:

  - `graph`: a MetaGraph with the following information:

      + `labels(graph)`: All assets.
      + `edge_labels(graph)`: All flows, in pair format `(u, v)`, where `u` and `v` are assets.
      + `graph[a]`: A [`TulipaEnergyModel.GraphAssetData`](@ref) structure for asset `a`.
      + `graph[u, v]`: A [`TulipaEnergyModel.GraphFlowData`](@ref) structure for flow `(u, v)`.

  - `representative_periods`: An array of
    [`TulipaEnergyModel.RepresentativePeriod`](@ref) ordered by their IDs.

  - `timeframe`: Information of
    [`TulipaEnergyModel.Timeframe`](@ref).
"""
function create_internal_structures!(connection)

    # Create tables that are allowed to be missing
    tables_allowed_to_be_missing = [
        "assets_rep_periods_partitions"
        "assets_timeframe_partitions"
        "assets_timeframe_profiles"
        "flows_rep_periods_partitions"
        "group_asset"
        "profiles_timeframe"
    ]
    for table in tables_allowed_to_be_missing
        _create_empty_unless_exists(connection, table)
    end

    # TODO: Move these function calls to the correct place
    @timeit to "tmp_create_partition_tables" tmp_create_partition_tables(connection)
    @timeit to "tmp_create_union_tables" tmp_create_union_tables(connection)
    @timeit to "tmp_create_lowest_resolution_table" tmp_create_lowest_resolution_table(connection)
    @timeit to "tmp_create_highest_resolution_table" tmp_create_highest_resolution_table(connection)

    return
end

function get_schema(tablename)
    if haskey(schema_per_table_name, tablename)
        return schema_per_table_name[tablename]
    else
        error("No implicit schema for table named $tablename")
    end
end

function _create_empty_unless_exists(connection, table_name)
    schema = get_schema(table_name)

    if !_check_if_table_exists(connection, table_name)
        columns_in_table = join(("$col $col_type" for (col, col_type) in schema), ",")
        DuckDB.query(connection, "CREATE TABLE $table_name ($columns_in_table)")
    end

    return
end

"""
    export_solution_to_csv_files(output_folder, energy_problem)

Saves the solution from `energy_problem` in CSV files inside `output_file`.
Notice that this assumes that the solution has been computed by [`save_solution!`](@ref).
"""
function export_solution_to_csv_files(output_folder, energy_problem::EnergyProblem)
    if !energy_problem.solved
        error("The energy_problem has not been solved yet.")
    end
    export_solution_to_csv_files(
        output_folder,
        energy_problem.db_connection,
        energy_problem.variables,
        energy_problem.constraints,
    )
    return
end

"""
    export_solution_to_csv_files(output_file, connection, variables, constraints)

Saves the solution in CSV files inside `output_folder`.
Notice that this assumes that the solution has been computed by [`save_solution!`](@ref).
"""
function export_solution_to_csv_files(output_folder, connection, variables, constraints)
    # Save each variable
    for (name, var) in variables
        if length(var.container) == 0
            continue
        end
        output_file = joinpath(output_folder, "var_$name.csv")
        DuckDB.execute(
            connection,
            "COPY $(var.table_name) TO '$output_file' (HEADER, DELIMITER ',')",
        )
    end

    # Save each constraint
    for (name, cons) in constraints
        if cons.num_rows == 0
            continue
        end

        output_file = joinpath(output_folder, "cons_$name.csv")
        DuckDB.execute(
            connection,
            "COPY $(cons.table_name) TO '$output_file' (HEADER, DELIMITER ',')",
        )
    end

    return
end

"""
    _check_initial_storage_level!(df)

Determine the starting value for the initial storage level for interpolating the storage level.
If there is no initial storage level given, we will use the final storage level.
Otherwise, we use the given initial storage level.
"""
function _check_initial_storage_level!(df, graph)
    initial_storage_level_dict = graph[unique(df.asset)[1]].initial_storage_level
    for (_, initial_storage_level) in initial_storage_level_dict
        if ismissing(initial_storage_level)
            df[!, :processed_value] = [df.value[end]; df[1:end-1, :value]]
        else
            df[!, :processed_value] = [initial_storage_level; df[1:end-1, :value]]
        end
    end
end

"""
    _interpolate_storage_level!(df, time_column::Symbol)

Transform the storage level dataframe from grouped timesteps or periods to incremental ones by interpolation.
The starting value is the value of the previous grouped timesteps or periods or the initial value.
The ending value is the value for the grouped timesteps or periods.
"""
function _interpolate_storage_level!(df, time_column)
    return DataFrames.flatten(
        DataFrames.transform(
            df,
            [time_column, :value, :processed_value] =>
                DataFrames.ByRow(
                    (period, value, start_value) -> begin
                        n = length(period)
                        interpolated_values = range(start_value; stop = value, length = n + 1)
                        (period, value, interpolated_values[2:end])
                    end,
                ) => [time_column, :value, :processed_value],
        ),
        [time_column, :processed_value],
    )
end
