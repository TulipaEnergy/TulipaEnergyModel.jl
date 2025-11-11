export create_internal_tables!, export_solution_to_csv_files

# Create tables that are allowed to be missing
const tables_allowed_to_be_missing = [
    "assets_profiles"
    "assets_rep_periods_partitions"
    "assets_timeframe_partitions"
    "assets_timeframe_profiles"
    "flows_profiles"
    "flows_relationships"
    "flows_rep_periods_partitions"
    "group_asset"
    "profiles_rep_periods"
    "profiles_timeframe"
    "stochastic_scenario"
]

"""
    create_internal_tables!(connection)

Creates internal tables.
"""
function create_internal_tables!(connection; skip_validation = false)
    for table in TulipaEnergyModel.tables_allowed_to_be_missing
        _create_empty_unless_exists(connection, table)
    end
    _calculate_stochastic_scenario_probabilities(connection)

    if !skip_validation
        # Data validation - ensure that data is correct before
        @timeit to "validate data" validate_data!(connection)
    end

    @timeit to "create_unrolled_partition_tables" create_unrolled_partition_tables!(connection)
    @timeit to "create_merged_tables" create_merged_tables!(connection)
    @timeit to "create_lowest_resolution_table" create_lowest_resolution_table!(connection)
    @timeit to "create_highest_resolution_table" create_highest_resolution_table!(connection)

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
    export_solution_to_csv_files(output_folder, energy_problem.db_connection)
    return
end

"""
    export_solution_to_csv_files(output_file, connection)

Saves the solution in CSV files inside `output_folder`.
Notice that this assumes that the solution has already been computed (e.g., by
[`save_solution!`](@ref), or using rolling horizon).
"""
function export_solution_to_csv_files(output_folder, connection)
    # Save each variable and constraint
    for prefix in ("var", "cons")
        for table_name in [
            row.table_name for row in DuckDB.query(
                connection,
                "FROM duckdb_tables() WHERE table_name LIKE '$(prefix)_%' AND estimated_size > 0",
            )
        ]
            output_file = joinpath(output_folder, "$table_name.csv")
            DuckDB.execute(connection, "COPY $table_name TO '$output_file' (HEADER, DELIMITER ',')")
        end
    end

    return
end
