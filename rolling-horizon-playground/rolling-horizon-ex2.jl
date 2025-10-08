using CSV
using DataFrames
using DuckDB
using TulipaEnergyModel
using TulipaIO
using Plots

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
    joinpath(@__DIR__, "..", "test", "inputs", "Rolling Horizon");
    schemas,
)

_q(s) = DataFrame(DuckDB.query(connection, s))

# Manually run rolling horizon simulation
try
    # MAKE SURE THAT num_rep_periods = 1, otherwise we don't know what to do yet
    # TODO: Create issue to add num_rep_periods to year_data
    # TODO: This should go to validation
    _validate_one_rep_period(connection)

    move_forward = 24
    maximum_window_length = 48
    global energy_problem = run_rolling_horizon(
        connection,
        move_forward,
        maximum_window_length;
        show_log = false,
        model_file_name = "jump-test.lp",
        save_rolling_solution = true,
    )

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

# Plotting
df_sql(s) = DataFrame(DuckDB.query(connection, s))
big_table = df_sql("""
    WITH cte_outgoing AS (
        SELECT
            rolsol.window_id,
            var.from_asset AS asset,
            var.time_block_start AS timestep,
            sum(rolsol.solution) AS solution
        FROM rolling_solution_var_flow AS rolsol
        LEFT JOIN var_flow AS var
            ON rolsol.var_id = var.id
        GROUP BY window_id, asset, timestep
    ), cte_incoming AS (
        SELECT
            rolsol.window_id,
            var.to_asset AS asset,
            var.time_block_start AS timestep,
            sum(rolsol.solution) AS solution
        FROM rolling_solution_var_flow AS rolsol
        LEFT JOIN var_flow AS var
            ON rolsol.var_id = var.id
        GROUP BY window_id, asset, timestep
    ), cte_unified AS (
        SELECT
            cte_outgoing.window_id,
            cte_outgoing.asset,
            cte_outgoing.timestep,
            coalesce(cte_outgoing.solution) AS outgoing,
            coalesce(cte_incoming.solution) AS incoming,
        FROM cte_outgoing
        LEFT JOIN cte_incoming
            ON cte_outgoing.window_id = cte_incoming.window_id
            AND cte_outgoing.asset = cte_incoming.asset
            AND cte_outgoing.timestep = cte_incoming.timestep
    ), cte_full_asset_data AS (
        SELECT
            cte_unified.*,
            IF(
                cte_unified.timestep < roldata.window_start,
                cte_unified.timestep + 168,
                cte_unified.timestep
            ) AS adjusted_timestep,
            asset.type,
        FROM cte_unified
        LEFT JOIN asset
            ON cte_unified.asset = asset.asset
        LEFT JOIN rolling_horizon_window AS roldata
            ON roldata.id = cte_unified.window_id
    )
    FROM cte_full_asset_data
    """)

num_windows = TulipaEnergyModel.get_num_rows(connection, "rolling_horizon_window")
horizon_length = maximum(big_table.timestep)
@info big_table[1:20, :]

big_table_grouped_per_window = groupby(big_table, :window_id)
rolling_horizon_window_df = df_sql("FROM rolling_horizon_window")
plt_vec = Plots.Plot[]
for ((window_id,), window_table) in pairs(big_table_grouped_per_window)
    @info window_table[(end-5):end, :]
    window_row = subset(rolling_horizon_window_df, :id => id -> id .== window_id)
    move_forward = only(window_row.move_forward)
    opt_window_length = only(window_row.opt_window_length)
    window_start = only(window_row.window_start)

    local timestep = range(extrema(window_table.adjusted_timestep)...)
    @info timestep

    thermal = sort(window_table[window_table.asset.=="thermal", :], :adjusted_timestep).outgoing
    solar = sort(window_table[window_table.asset.=="solar", :], :adjusted_timestep).outgoing
    discharge = sort(window_table[window_table.asset.=="battery", :], :adjusted_timestep).outgoing
    charge = sort(window_table[window_table.asset.=="battery", :], :adjusted_timestep).incoming

    y = hcat(thermal, solar, discharge)
    local plt = plot(;
        ylabel = "MW",
        xlims = (1, horizon_length + opt_window_length - move_forward),
        ylims = (-20, 100),
        xticks = 1:12:(horizon_length+1),
    )
    label = window_id == 1 ? ["thermal" "solar" "discharge"] : false
    areaplot!(timestep, y; lab = label)
    label = window_id == 1 ? "charge" : false
    areaplot!(timestep, -charge; lab = label)
    push!(plt_vec, plt)
end
Plots.plot(plt_vec...; layout = (length(plt_vec), 1), size = (800, 150 * num_windows))
plot!()

# TODO: fix naming of opt_window (just move_forward is enough)
