
"""
    validate_rolling_horizon_input(connection, move_forward, opt_window)

Validation of the rolling horizon input:
- opt_window_length ≥ move_forward
- Only one representative period per milestone_year
- Only 'uniform' partitions are allowed
- Only partitions that exactly divide opt_window_length are allowed
"""
function validate_rolling_horizon_input(connection, move_forward, opt_window_length)
    @assert opt_window_length >= move_forward
    for row in DuckDB.query(
        connection,
        "SELECT milestone_year, max(rep_period) as num_rep_periods
        FROM rep_periods_data
        GROUP BY milestone_year",
    )
        @assert row.num_rep_periods == 1
    end
    partition_tables = [
        row.table_name for row in
        DuckDB.query(connection, "FROM duckdb_tables() WHERE table_name LIKE '%_partitions'")
    ]

    for table_name in partition_tables
        for row in DuckDB.query(connection, "FROM $table_name")
            @assert row.specification == "uniform" "Only 'uniform' specification is accepted"
            partition = tryparse(Int, row.partition)
            @assert !isnothing(partition) "Invalid partition"
            @assert move_forward % partition == 0
            @assert opt_window_length % partition == 0
        end
    end

    return
end

"""
    prepare_rolling_horizon_tables!(connection, variable_tables, save_rolling_solution, opt_window_length)

Modify and create tables to prepare to start the rolling horizon execution.
The changes are:

- Stored the original variable tables as `full_var_%` per variable table
- Add `solution` column to each full variable table.
- If `save_rolling_solution`, create the `rolling_solution_var_%` tables per variable table.
- Backup `rep_periods_data` and `year_data` into `full_rep_periods_data` and `full_year_data`.
- Modify `rep_periods_data` and `year_data` to use `opt_window_length` as `num_timesteps`/`length`, respectively.
"""
function prepare_rolling_horizon_tables!(
    connection,
    variable_tables,
    constraint_tables,
    save_rolling_solution,
    opt_window_length,
)
    # Preparing the table to save the rolling solution
    for table in variable_tables
        # Rename var_% table to full_var_%
        DuckDB.execute(connection, "ALTER TABLE $table RENAME TO full_$table")

        if save_rolling_solution
            # Save solutions with a table linking the window to the id of the (no-rolling) variable
            DuckDB.execute(
                connection,
                """
                CREATE OR REPLACE TABLE rolling_solution_$table (
                    window_id INTEGER,
                    var_id INTEGER,
                    solution FLOAT8,
                );
                """,
            )
        end
    end

    for table in constraint_tables
        # Rename cons_% table to full_cons_%
        DuckDB.execute(connection, "ALTER TABLE $table RENAME TO full_$table")
    end

    # Create backup tables for rep_periods_data and year_data
    for table_name in ["rep_periods_data", "year_data"]
        DuckDB.query(
            connection,
            "CREATE OR REPLACE TABLE full_$table_name AS
            FROM $table_name",
        )
    end

    # Modify tables that keep horizon information to limit the horizon to the rolling window
    DuckDB.query(connection, "UPDATE rep_periods_data SET num_timesteps = $opt_window_length")
    DuckDB.query(connection, "UPDATE year_data SET length = $opt_window_length")

    return
end

function get_where_condition(connection, table_name)
    # Guessing which columns should be used as key for matching with the larger no-rolling variables
    # We list the possible primary keys and filter the columns of the table based on them
    key_columns = [
        row.column_name for row in DuckDB.query(
            connection,
            """
            FROM duckdb_columns
            WHERE table_name = '$table_name'
                AND column_name IN ('asset', 'from_asset', 'to_asset',
                    'milestone_year', 'commission_year', 'rep_period')
            """,
        )
    ]

    # Construct the WHERE condition matching the keys
    where_condition =
        join(["full_$table_name.$key = $table_name.$key" for key in key_columns], " AND ")

    return where_condition
end

function save_solution_of_one_table_into_full_table!(
    connection,
    table_name,
    where_condition,
    solution_column,
    horizon_length,
    window_start,
    move_forward,
)
    DuckDB.query(
        connection,
        """
        UPDATE full_$table_name
        SET $solution_column = $table_name.$solution_column
        FROM $table_name WHERE $where_condition
            AND full_$table_name.time_block_start = ($(window_start - 1) + $table_name.time_block_start - 1) % $horizon_length + 1
            AND $table_name.time_block_end <= $move_forward -- only save the move_forward window
        """,
    )

    return
end

"""
    save_solution_into_tables!(energy_problem, variable_tables, window_id, move_forward, window_start, horizon_length, save_rolling_solution)

Save the current rolling horizon solution from the model into the connection.
This involves:
- Calling [`save_solution!`](@ref) to copy the internal solution from the JuMP model to the connection.
- Copying the solution from the internal variables to the full variables for the `move_forward` sub-window.
- If `save_rolling_solution`, save the complete rolling solution in the table `rolling_solution_var_%` per variable table.
"""
function save_solution_into_tables!(
    energy_problem,
    variable_tables,
    constraint_tables,
    window_id,
    move_forward,
    window_start,
    horizon_length,
    save_rolling_solution,
    compute_duals,
)
    @timeit to "Save internal rolling horizon solution to connection" save_solution!(
        energy_problem;
        compute_duals,
    )

    # Save rolling solution of each variable
    for table_name in variable_tables
        where_condition = get_where_condition(energy_problem.db_connection, table_name)

        # Save solution to full table
        save_solution_of_one_table_into_full_table!(
            energy_problem.db_connection,
            table_name,
            where_condition,
            "solution",
            horizon_length,
            window_start,
            move_forward,
        )

        if save_rolling_solution
            # Store the solution in the corresponding rolling_solution_$table_name
            # This also uses the `where_condition`, but to join the no-rolling and rolling variable tables
            DuckDB.query(
                energy_problem.db_connection,
                """
                WITH cte_var_solution AS (
                    SELECT
                        $window_id as window_id,
                        full_$table_name.id as var_id, -- the ids are from the main model
                        $table_name.solution
                    FROM $table_name
                    LEFT JOIN full_$table_name
                        ON $where_condition -- this condition should match
                        AND full_$table_name.time_block_start = ($(window_start - 1) + $table_name.time_block_start - 1) % $horizon_length + 1
                )
                INSERT INTO rolling_solution_$table_name
                SELECT *
                FROM cte_var_solution
                """,
            )
        end
    end

    # Save rolling solution of each dual variable
    if !compute_duals
        return
    end

    for table_name in constraint_tables
        where_condition = get_where_condition(energy_problem.db_connection, table_name)

        dual_columns = [
            row.column_name for row in DuckDB.query(
                energy_problem.db_connection,
                """
                SELECT column_name FROM duckdb_columns() WHERE table_name = '$table_name' AND column_name LIKE 'dual_%'
                """,
            )
        ]
        for dual_column in dual_columns
            # Create the dual_* column in full_$table_name in case it doesn't exist
            DuckDB.execute(
                energy_problem.db_connection,
                "ALTER TABLE full_$table_name ADD COLUMN IF NOT EXISTS $dual_column FLOAT8",
            )
            save_solution_of_one_table_into_full_table!(
                energy_problem.db_connection,
                table_name,
                where_condition,
                dual_column,
                horizon_length,
                window_start,
                move_forward,
            )
        end
    end

    return
end

"""
    prepare_tables_to_leave_rolling_horizon!(connection, variable_tables)

Undo some of the changes done by [`prepare_rolling_horizon_tables`] to go back to the original input data.
This involves:
- Revert `rep_periods_data` and `year_data` to their original values.
- Drop the internal variable tables and replace them with the full variable tables.
"""
function prepare_tables_to_leave_rolling_horizon!(connection, variable_tables, constraint_tables)
    # Drop the rolling horizon variable tables and rename the full_var_% tables to var_%
    # Do the same for rep_periods_data and year_data
    for table_name in ["rep_periods_data"; "year_data"; variable_tables; constraint_tables]
        DuckDB.query(connection, "DROP TABLE IF EXISTS $table_name")
        DuckDB.query(connection, "ALTER TABLE full_$table_name RENAME TO $table_name")
    end

    return
end
