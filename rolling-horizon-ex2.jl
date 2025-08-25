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

    move_forward = 24 * 28 * 3
    maximum_window_length = move_forward * 2
    global energy_problem =
        run_rolling_horizon(connection, move_forward, maximum_window_length; show_log = false)

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

catch ex
    rethrow(ex)
finally
    # close(connection)
end
