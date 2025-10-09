using CSV
using DataFrames
using DuckDB
using Plots
using TidierData
using TulipaEnergyModel
using TulipaIO

function create_connection()
    connection = DBInterface.connect(DuckDB.DB)
    schemas = TulipaEnergyModel.schema_per_table_name
    TulipaIO.read_csv_folder(
        connection,
        joinpath(@__DIR__, "..", "test", "inputs", "Rolling Horizon");
        schemas,
    )

    return connection
end

function create_energy_problem(connection)
    energy_problem = run_scenario(
        connection;
        show_log = false,
        model_file_name = joinpath(@__DIR__, "rolling-horizon.lp"),
    )

    if !energy_problem.solved
        error("Infeasible")
    end

    return energy_problem
end

function plot_solution(connection)
    df_sql(s) = DataFrame(DuckDB.query(connection, s))
    big_table = df_sql("""
        WITH cte_outgoing AS (
            SELECT
                var.from_asset AS asset,
                var.time_block_start AS timestep,
                SUM(var.solution) AS solution,
            FROM var_flow AS var
            WHERE rep_period = 1 AND year = 2030
            GROUP BY asset, timestep
        ), cte_incoming AS (
            SELECT
                var.to_asset AS asset,
                var.time_block_start AS timestep,
                SUM(var.solution) AS solution,
            FROM var_flow AS var
            WHERE rep_period = 1 AND year = 2030
            GROUP BY asset, timestep
        ), cte_unified AS (
            SELECT
                cte_outgoing.asset,
                cte_outgoing.timestep,
                coalesce(cte_outgoing.solution) AS outgoing,
                coalesce(cte_incoming.solution) AS incoming,
            FROM cte_outgoing
            LEFT JOIN cte_incoming
                ON cte_outgoing.asset = cte_incoming.asset
                AND cte_outgoing.timestep = cte_incoming.timestep
        ), cte_full_asset_data AS (
            SELECT
                cte_unified.*,
                asset.type,
                asset.group,
            FROM cte_unified
            LEFT JOIN asset
                ON cte_unified.asset = asset.asset
        )
        FROM cte_full_asset_data
        """)

    timestep = range(extrema(big_table.timestep)...)

    thermal = @chain big_table begin
        @filter(asset == "thermal")
        @arrange(timestep)
        @pull(outgoing)
    end
    solar = @chain big_table begin
        @filter(asset == "solar")
        @arrange(timestep)
        @pull(outgoing)
    end
    discharge = @chain big_table begin
        @filter(asset == "battery")
        @arrange(timestep)
        @pull(outgoing)
    end
    charge = @chain big_table begin
        @filter(asset == "battery")
        @arrange(timestep)
        @pull(incoming)
    end

    horizon_length = length(timestep)
    @info "AAA" length(thermal) length(solar) length(discharge)
    y = hcat(thermal, solar, discharge)
    plot(;
        ylabel = "MW",
        xlims = (1, horizon_length),
        xticks = 1:12:horizon_length,
        size = (800, 150),
    )

    areaplot!(timestep, y; label = ["thermal" "solar" "discharge"])
    return areaplot!(timestep, -charge; label = "charge")
end

connection = create_connection()
energy_problem = create_energy_problem(connection)
plot_solution(connection)
