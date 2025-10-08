using CSV
using DataFrames
using DuckDB
using TulipaEnergyModel
using TulipaIO

function _validate_one_rep_period(connection)
    for row in DuckDB.query(
        connection,
        "SELECT year, max(rep_period) as num_rep_periods
        FROM rep_periods_data
        GROUP BY year
        ",
    )
        if row.num_rep_periods > 1
            error("We should have only 1 rep period for rolling horizon")
        end
    end
end

connection = DBInterface.connect(DuckDB.DB)
schemas = TulipaEnergyModel.schema_per_table_name
TulipaIO.read_csv_folder(
    connection,
    joinpath(@__DIR__, "test", "inputs", "Rolling Horizon");
    schemas,
)

_q(s) = DataFrame(DuckDB.query(connection, s))

# Manually run rolling horizon simulation
try
    # MAKE SURE THAT num_rep_periods = 1, otherwise we don't know what to do yet
    # TODO: Create issue to add num_rep_periods to year_data
    # TODO: This should go to validation
    _validate_one_rep_period(connection)

    global energy_problem = run_scenario(connection; show_log = false)
    @info "Full run" energy_problem
    if energy_problem.solved
        # @info "Asset investment" _q("FROM var_assets_investment")
        @info "Storage" count(_q("FROM var_storage_level_rep_period").solution .> 0)
        @assert any(_q("FROM var_storage_level_rep_period").solution .> 0)
        # @info "Flow from solar" count(_q("FROM var_flow WHERE from_asset='Solar'").solution .> 0)
        # @info "Positive flows in the first 3 hours" _q(
        #     "FROM var_flow WHERE solution > 0 AND time_block_start in (11, 12)",
        # )
        @info energy_problem
    else
        @warn "Infeasible"
        error("Infeasible")
    end

    # Store old solution for comparison
    # And create a place for storage of the new solution
    variable_tables = [
        row.table_name::String for row in DuckDB.query(
            connection,
            "FROM duckdb_tables() WHERE table_name LIKE 'var_%' AND estimated_size > 0",
        )
    ]
    for table_name in variable_tables
        _q("CREATE OR REPLACE TABLE full_$table_name AS FROM $table_name")
        _q("ALTER TABLE full_$table_name ADD COLUMN rolling_solution DOUBLE")
    end

    # Backing up the complete profiles_rep_periods, rep_periods_data, year_data, and asset_milestone
    for table_name in ("profiles_rep_periods", "rep_periods_data", "year_data", "asset_milestone")
        _q("CREATE OR REPLACE TABLE full_$table_name AS SELECT * FROM $table_name")
    end

    horizon_length = maximum(_q("FROM profiles_rep_periods").timestep)
    move_forward = 24 * 28 * 3
    maximum_window_length = move_forward * 2

    _q("UPDATE rep_periods_data SET num_timesteps = $maximum_window_length")
    _q("UPDATE year_data SET length = $maximum_window_length")

    for window_start in 1:move_forward:(horizon_length-move_forward)
        window_end = min(window_start + maximum_window_length - 1, horizon_length)
        window_length = window_end - window_start + 1

        @info "Optimisation window: $window_start:$window_end"

        if window_length < maximum_window_length
            _q("UPDATE rep_periods_data SET num_timesteps = $window_length")
            _q("UPDATE year_data SET length = $window_length")
        end

        # Create profiles
        _q("CREATE OR REPLACE TABLE profiles_rep_periods AS
        SELECT * REPLACE (timestep - $window_start + 1 AS timestep)
        FROM full_profiles_rep_periods
        WHERE timestep >= $window_start AND timestep <= $window_end
        ")

        @info _q("FROM asset_milestone")
        # Update initial_storage_level
        _q("UPDATE asset_milestone
        SET initial_storage_level = var_storage_level_rep_period.solution
        FROM var_storage_level_rep_period
        WHERE asset_milestone.asset = var_storage_level_rep_period.asset
            AND asset_milestone.milestone_year = var_storage_level_rep_period.year
            AND var_storage_level_rep_period.rep_period = 1 -- just to make the key explicit
            AND var_storage_level_rep_period.time_block_start = $window_length -- the last
        ")
        @info _q("FROM asset_milestone")

        # DROP all temporary tables
        for row in DuckDB.query(connection, "FROM duckdb_tables() WHERE temporary")
            _q("DROP TABLE $(row.table_name)")
        end
        sub_ep = run_scenario(connection; show_log = false)

        # @info _q("FROM var_flow WHERE time_block_start < 3")
        # Save solution
        for table_name in variable_tables
            key_columns = [
                row.column_name for row in DuckDB.query(
                    connection,
                    "FROM duckdb_columns
                    WHERE table_name = '$table_name'
                        AND column_name IN ('asset', 'from_asset', 'to_asset', 'milestone_year', 'commission_year', 'year', 'rep_period')
                        -- AND column_name NOT IN ('id', 'time_block_start', 'time_block_end', 'solution')
                    ",
                )
            ]
            where_condition =
                join(["full_$table_name.$key = $table_name.$key" for key in key_columns], " AND ")
            query = """
                    UPDATE full_$table_name
                    SET rolling_solution = $table_name.solution
                    FROM $table_name WHERE $where_condition
                        AND full_$table_name.time_block_start = $(window_start - 1) + $table_name.time_block_start
                    """
            # @info query
            _q(query)
        end
        @info _q("FROM full_var_flow WHERE time_block_start in ($window_start, $window_start + 1)")
        # @warn "Early exit"
        # break
    end

    @info _q("with cte_diff as (
                SELECT id, time_block_start, solution, solution - rolling_solution as diff
                FROM full_var_flow
            )
            select max(abs(diff)) as abs_diff, max(abs(diff)) / max(abs(solution)) as rel_diff
            from cte_diff")
catch ex
    rethrow(ex)
finally
    # close(connection)
end
