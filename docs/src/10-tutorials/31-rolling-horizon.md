# Tutorial 8: Rolling Horizon

In this example we will replicate the [rolling horizon example in JuMP](https://jump.dev/JuMP.jl/stable/tutorials/algorithms/rolling_horizon/).

For this example we will use the [Rolling Horizon](https://github.com/TulipaEnergy/TulipaEnergyModel.jl/blob/main/test/inputs/Rolling%20Horizon/) test files.
If you are following along, make sure to download all of these files beforehand.

```@example rolling_horizon
using DuckDB: DBInterface, DuckDB
using TulipaIO: TulipaIO
using TulipaEnergyModel: TulipaEnergyModel

# Define rolling_horizon_folder as the path to where you download the data
rolling_horizon_folder = joinpath(@__DIR__, "..", "..", "..", "test", "inputs", "Rolling Horizon") # hide
connection = DBInterface.connect(DuckDB.DB)
schemas = TulipaEnergyModel.schema_per_table_name
TulipaIO.read_csv_folder(connection, rolling_horizon_folder; schemas)
```

To better visualize the data, we will create a helper function `nice_query`.
This is optional.

```@example rolling_horizon
using DataFrames

nice_query(sql) = DuckDB.query(connection, sql) |> DataFrame
```

In this data, we have four assets: `solar`, `thermal`, `battery` and `demand`.
You can see the connection between them in the `flow` table:

```@example rolling_horizon
nice_query("SELECT from_asset, to_asset FROM flow")
```

## Solution without rolling horizon

Let's first solve this problem directly and inspect the solution

```@example rolling_horizon
energy_problem = TulipaEnergyModel.run_scenario(connection, show_log=false)
```

We will aggregate the flow solution and visualize the "solar" and "thermal" assets, and the "charge" and "discharge" of the battery.

```@example rolling_horizon
using Plots: Plots

big_table_no_rh = nice_query("""
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
            coalesce(cte_outgoing.solution, 0.0) AS outgoing,
            coalesce(cte_incoming.solution, 0.0) AS incoming,
        FROM cte_outgoing
        LEFT JOIN cte_incoming
            ON cte_outgoing.asset = cte_incoming.asset
            AND cte_outgoing.timestep = cte_incoming.timestep
    ) FROM cte_unified
""")

timestep = range(extrema(big_table_no_rh.timestep)...)
thermal = sort(big_table_no_rh[big_table_no_rh.asset .== "thermal", :], :timestep).outgoing
solar = sort(big_table_no_rh[big_table_no_rh.asset .== "solar", :], :timestep).outgoing
discharge = sort(big_table_no_rh[big_table_no_rh.asset .== "battery", :], :timestep).outgoing
charge = sort(big_table_no_rh[big_table_no_rh.asset .== "battery", :], :timestep).incoming

horizon_length = length(timestep)
y = hcat(thermal, solar, discharge)
Plots.plot(;
    ylabel = "MW",
    xlims = (1, horizon_length),
    xticks = 1:12:horizon_length,
    size = (800, 150),
    legend = :outerright,
)

Plots.areaplot!(timestep, y; label = ["thermal" "solar" "discharge"])
Plots.areaplot!(timestep, -charge; label = "charge")
```

## Solution with rolling horizon

The rolling horizon solution is obtained by considering a model in a smaller timeframe, called the "optimisation window".
We limit out data to only the timesteps inside the optimisation window, solve the model that we obtain, save part of the solution, and move the window forward by some amount.

The "move forward" amount defines how much of the solution we store, and how much we move the window forward.

Some variables from previous windows are used to update relevant parameters.
Most notably, the initial storage value of the batteries start at a given parameter, but after the first window, it is updated to use the solution obtained in the previous window.

This process is repeated until the complete horizon is covered by the **"move forward" window**. This is done since only the solution in the "move forward" window is copied to the full problem.

This also means that the optimisation window is larger than the horizon. To handle this, we "loop around" the horizon, i.e., we extend the profiles by defining the profile at `timestep = horizon + X` to be the profile at `X`.

The image below (recreated from the JuMP tutorial) exemplifies the process:

```@example rolling_horizon
profiles = nice_query("FROM profiles")
demand = sort(profiles[profiles.profile_name .== "demand-demand-2030",:], :timestep)
solar = sort(profiles[profiles.profile_name .== "solar-availability-2030",:], :timestep)

horizon_length = size(demand, 1)
move_forward = 24
opt_window_length = 48

plots = Plots.Plot[]
for window_id = 1:2
    plt = if window_id == 1
        Plots.plot(leg = :bottomright)
    else
        Plots.plot(leg = false)
    end
    Plots.plot!(
        plt,
        demand.timestep,
        demand.value,
        c = :blue,
        lw = 2,
        label = "demand",
    )
    Plots.plot!(plt,
        solar.timestep,
        solar.value,
        c = :red,
        lw = 2,
        label = "solar",
    )
    window_start = (window_id - 1) * move_forward
    Plots.vspan!(
        plt,
        [window_start, window_start + opt_window_length],
        alpha = 0.25,
        c = :green,
        label = "optimisation window",
    )
    push!(plots, plt)
end
Plots.plot!(plots..., layout = (length(plots), 1), size = (800, 150 * length(plots)))
```

To solve the same problem using rolling horizon, we use [`run_rolling_horizon`](@ref) instead of [`run_scenario`](@ref).
In addition to the `connection`, we also give the `move_forward` and the `opt_window_length` positional parameters.

```@example rolling_horizon
energy_problem = TulipaEnergyModel.run_rolling_horizon(
    connection,
    move_forward,
    opt_window_length,
    show_log = false,
    save_rolling_solution = true, # optional: saves intermediate solutions
)
```

To visualise each step of the rolling horizon solution, we set `save_rolling_solution = true`, but that's optional.
The default option is to ignore those extras tables to save storage.

```@example rolling_horizon
big_table_rh_all = nice_query("""
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
horizon_length = maximum(big_table_rh_all.timestep)

big_table_rh_grouped = groupby(big_table_rh_all, :window_id)
rolling_horizon_window_df = sort(nice_query("FROM rolling_horizon_window"), :id)
plots = Plots.Plot[]

for ((window_id,), window_table) in pairs(big_table_rh_grouped)
    window_row = rolling_horizon_window_df[window_id, :]
    window_start = window_row.window_start

    timestep = range(extrema(window_table.adjusted_timestep)...)
    thermal = sort(window_table[window_table.asset .== "thermal", :], :adjusted_timestep).outgoing
    solar = sort(window_table[window_table.asset .== "solar", :], :adjusted_timestep).outgoing
    discharge = sort(window_table[window_table.asset .== "battery", :], :adjusted_timestep).outgoing
    charge = sort(window_table[window_table.asset .== "battery", :], :adjusted_timestep).incoming

    y = hcat(thermal, solar, discharge)
    plt = if window_id == 1
        Plots.plot(leg = :bottomright)
    else
        Plots.plot(leg = false)
    end
    Plots.plot!(
        plt;
        ylabel = "MW",
        xlims = (1, horizon_length + opt_window_length - move_forward), # extended for the loop around
        xticks = 1:12:(horizon_length + 1),
        size = (800, 150),
    )
    Plots.areaplot!(plt, timestep, y; label = ["thermal" "solar" "discharge"])
    Plots.areaplot!(plt, timestep, -charge; label = "charge")
    push!(plots, plt)
end
Plots.plot!(plots..., layout = (length(plots), 1), size = (800, 150 * length(plots)))
```

We can also look at the full solution. Notice that the code below is the same as the non-rolling horizon version (except for the name) because the solution populates the full model solution.

```@example rolling_horizon
big_table_rh = nice_query("""
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
            coalesce(cte_outgoing.solution, 0.0) AS outgoing,
            coalesce(cte_incoming.solution, 0.0) AS incoming,
        FROM cte_outgoing
        LEFT JOIN cte_incoming
            ON cte_outgoing.asset = cte_incoming.asset
            AND cte_outgoing.timestep = cte_incoming.timestep
    ) FROM cte_unified
""")

timestep = range(extrema(big_table_rh.timestep)...)
thermal = sort(big_table_rh[big_table_rh.asset .== "thermal", :], :timestep).outgoing
solar = sort(big_table_rh[big_table_rh.asset .== "solar", :], :timestep).outgoing
discharge = sort(big_table_rh[big_table_rh.asset .== "battery", :], :timestep).outgoing
charge = sort(big_table_rh[big_table_rh.asset .== "battery", :], :timestep).incoming

horizon_length = length(timestep)
y = hcat(thermal, solar, discharge)
Plots.plot(;
    ylabel = "MW",
    xlims = (1, horizon_length),
    xticks = 1:12:horizon_length,
    size = (800, 150),
    legend = :outerright,
)

Plots.areaplot!(timestep, y; label = ["thermal" "solar" "discharge"])
Plots.areaplot!(timestep, -charge; label = "charge")
```

### Comparison

For completeness, let's show the difference between the solutions using rolling horizon and not using it.

```@example rolling_horizon
thermal_no_rh = sort(big_table_no_rh[big_table_no_rh.asset .== "thermal", :], :timestep).outgoing
solar_no_rh = sort(big_table_no_rh[big_table_no_rh.asset .== "solar", :], :timestep).outgoing
discharge_no_rh = sort(big_table_no_rh[big_table_no_rh.asset .== "battery", :], :timestep).outgoing
charge_no_rh = sort(big_table_no_rh[big_table_no_rh.asset .== "battery", :], :timestep).incoming
thermal_rh = sort(big_table_rh[big_table_rh.asset .== "thermal", :], :timestep).outgoing
solar_rh = sort(big_table_rh[big_table_rh.asset .== "solar", :], :timestep).outgoing
discharge_rh = sort(big_table_rh[big_table_rh.asset .== "battery", :], :timestep).outgoing
charge_rh = sort(big_table_rh[big_table_rh.asset .== "battery", :], :timestep).incoming

both_plots = [
    Plots.plot(;
        ylabel = "MW",
        xlims = (1, horizon_length),
        xticks = 1:12:horizon_length,
        size = (800, 150),
        legend = :outerright,
    ) for _ in 1:2
]

y = hcat(thermal_no_rh, solar_no_rh, discharge_no_rh)
Plots.areaplot!(both_plots[1], timestep, y; label = ["thermal" "solar" "discharge"])
Plots.areaplot!(both_plots[1], timestep, -charge_no_rh; label = "charge")

y = hcat(thermal_rh, solar_rh, discharge_rh)
Plots.areaplot!(both_plots[2], timestep, y; label = ["thermal" "solar" "discharge"])
Plots.areaplot!(both_plots[2], timestep, -charge_rh; label = "charge")

Plots.plot(both_plots..., layout = (2, 1), size = (800, 150 * 2))
```

Finally, as a sanity check, we can compare that indeed both solutions reach the same demand value by comparing the aggregated outgoing flow and the charge between the rolling horizon and the no-rolling horizon versions.

```@example rolling_horizon
outgoing_rh = thermal_rh + solar_rh + discharge_rh
outgoing_no_rh = thermal_no_rh + solar_no_rh + discharge_no_rh

Plots.plot(
    Plots.plot(timestep, outgoing_no_rh - outgoing_rh, title="thermal + solar + discharge error"),
    Plots.plot(timestep, charge_no_rh - charge_rh, title="charge error"),
    layout = (2, 1),
    size = (800, 150 * 2),
    xticks = 1:move_forward:horizon_length,
)
```

## Rolling horizon tables

In addition to the tables normally created by Tulipa, we also stored tables specific for rolling horizon.
Still using the same input as the tutorial above, let's explore these tables.

### `rolling_horizon_window`

Contain information of each window of the rolling horizon.
Notably, this table stores the objective value of each window.

```@example rolling_horizon
nice_query("FROM rolling_horizon_window")
```

### `rolling_solution_var_%`

For each variable table `var_X`, a `rolling_solution_var_X` is created if `save_rolling_solution` is `true`.
This table stores the intermediate solution per window, including the full optimisation window.

```@example rolling_horizon
nice_query("FROM rolling_solution_var_flow ORDER BY RANDOM() LIMIT 5")
```

### `full_%` (intermediate)

During the execution of the rolling horizon, we also created intermediate tables to store the full problem. These are named `full_X` for each varable table `X`, and for the `rep_periods_data` and `year_data` tables.

The `rep_periods_data` and `year_data` are modified to pretend that the horizon is limited to the optimisation window, thus the `full_X` version of these tables serve as backup.

The `full_var_X` tables are created to hold the final solution of rolling horizon execution.
For each window, we copy all `var_X` solution within the "move forward" window to the correct position in `full_var_X`.
After the rolling horizon execution is completed, the `full_var_X` tables are renamed to `var_X`.
