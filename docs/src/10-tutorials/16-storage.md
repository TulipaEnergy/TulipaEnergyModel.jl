# Tutorial 5: Seasonal and Non-seasonal Storage

## Introduction

Tulipa has two types of storage representations:

1. seasonal - inter-temporal constraints over the clustered analysis period (i.e. year)
2. non-seasonal - intra-temporal constraints inside the representative periods

Here is the concept documentation for more details: [Storage Modelling](https://tulipaenergy.github.io/TulipaEnergyModel.jl/dev/30-concepts/#storage-modeling)

The data we will be working with is once again located in the `my-awesome-energy-system` folder, this time under tutorial 5

Let's have a look at their input parameters...

For instance, what are the storage capacities? Efficiencies? Initial storage levels? Any other parameters?

## Previously in the TLC

Let's reuse most of the final script from the Tutorial 4, but using the data from tutorial 5:

```julia
using Pkg
Pkg.activate(".")
# Pkg.add("TulipaEnergyModel")
# Pkg.add("TulipaIO")
# Pkg.add("TulipaClustering")
# Pkg.add("DuckDB")
# Pkg.add("DataFrames")
# Pkg.add("Plots")
# Pkg.add("Distances")
Pkg.instantiate()

import TulipaIO as TIO
import TulipaEnergyModel as TEM
import TulipaClustering as TC
using DuckDB
using DataFrames
using Plots
using Distances

connection = DBInterface.connect(DuckDB.DB)
input_dir = "my-awesome-energy-system/tutorial-5"
output_dir = "my-awesome-energy-system/tutorial-5/results"
#mkdir(output_dir) # optional if the output folder doesn't exist yet
TIO.read_csv_folder(connection, input_dir)

TC.transform_wide_to_long!(
    connection,
    "profiles_wide",
    "profiles";
)

period_duration = 24
num_rps = 12
clusters = TC.cluster!(connection,
                    period_duration,
                    num_rps;
                    method = :convex_hull,
                    distance = Distances.CosineDist(),
                    weight_type = :convex
                    )

TEM.populate_with_defaults!(connection)
energy_problem = TEM.run_scenario(connection; output_folder=output_dir)
```

!!! warning
    Since the output directory does not exist yet, we need to create the 'results' folder inside our tutorial folder, otherwise it will error.

At this point, everything should work similiar as Tutorial 4.

## Results

> **Note:** Remember to look at your output folder to see the exported results and check which primal and dual information you want to analyze.

Nice, so what about the storage level?

```julia
# Retrieve and group the data
storage_levels = TIO.get_table(connection, "var_storage_level_rep_period")
gdf = groupby(storage_levels, [:asset])

# Create a simple plot
n_subplots = length(gdf)
p = plot(; layout=grid(n_subplots, 1))
for (i, group) in enumerate(gdf)
    plot!(
        p[i],
        group.time_block_end,
        group.solution;
        group=group.rep_period,
        title=string(unique(group.asset)),
        xlabel="Hour",
        ylabel="[MWh]",
        xlims=(1, 24),
        dpi=600,
    )
end
p
```

What is happening with the storage assets? Any ideas?

The battery storage looks reasonable, but what is happening with the hydrogen storage?

## The parameter `is_seasonal`

Change the parameter `is_seasonal` from `false` to `true` for the hydrogen storage in the file `assets.csv`.

Rerun the workflow and check the results again...

!!! tip "Pro tip"
    You can use the following command to update a parameter in the database directly from Julia and then rerun:
    ```julia
    DuckDB.query(connection, "UPDATE asset SET is_seasonal = true WHERE asset = 'h2_storage'")
    energy_problem = TEM.run_scenario(connection; output_folder=output_dir)
    ```

What do you notice in the output folder? Any new variables/constraints?

Check the storage level of the hydrogen storage.

!!! tip
    It's now in the variable `var_storage_level_over_clustered_year` because it's seasonal.
    Use `TIO.get_table(connection, "var_storage_level_over_clustered_year")` to access it.

```julia
seasonal_storage_levels = TIO.get_table(connection, "var_storage_level_over_clustered_year")
gdf = groupby(seasonal_storage_levels, [:asset])
n_subplots = length(gdf)
p = plot(; layout=grid(n_subplots, 1))
for (i, group) in enumerate(gdf)
    plot!(
        p[i],
        group.period_block_end,
        group.solution;
        title=string(unique(group.asset)),
        xlabel="Day",
        ylabel="[MWh]",
        dpi=600,
    )
end
p
```

## Changing other storage parameters

As you saw before, there are several parameters for the storage assets. Let's play with some of them...

### The parameter `initial_storage_level`

Change the `initial_storage_level` of the battery to empty (blank) and rerun the workflow.

### The parameter `storage_loss_from_stored_energy`

Change the `storage_loss_from_stored_energy` of the battery to empty (blank) and rerun the workflow.

## Comparing with the full year of optimization

The following code:

1. Creates a new connection `conn_hourly_benchmark` to store the results of the hourly benchmark
2. Runs TulipaClustering using the `dummy_cluster!` function to create 1 representative period of 8760 hours
3. Updates the values of the `is_seasonal` parameter to `false`.\
   *Since it is 1 year and 1 representative, the storage is not considered seasonal (it is within the representative period)*
4. Stores the run in a new object called `ep_hourly`

```julia
# 1. Create a new connection for the hourly benchmark
conn_hourly_benchmark = DBInterface.connect(DuckDB.DB)
TIO.read_csv_folder(conn_hourly_benchmark, input_dir)

# 2. Transform the profiles and create the tables with 1 representative period of 8760 hours
TC.transform_wide_to_long!(
    conn_hourly_benchmark,
    "profiles_wide",
    "profiles";
)
TC.dummy_cluster!(conn_hourly_benchmark)

# 3. Populate with defaults
TEM.populate_with_defaults!(conn_hourly_benchmark)

# 4. We update the `is_seasonal` column to false to make sure all the storage assets are non-seasonal since we only have one representative period that is the whole year
DuckDB.query(
    conn_hourly_benchmark, "UPDATE asset SET is_seasonal = false")

# 5. We can solve it now
ep_hourly = TEM.run_scenario(conn_hourly_benchmark)
```

You can use this result and the ones from the clustering to see the comparison of the two solutions.\
Here is an example of how to combine the plots for this case:

```julia
# plotting the results for the hourly benchmark
storage_levels_hourly = TIO.get_table(conn_hourly_benchmark, "var_storage_level_rep_period")
asset_to_filter = "h2_storage"
hourly_filtered_asset = filter(
    row ->
        row.asset == asset_to_filter,
    storage_levels_hourly,
)
plot(
    hourly_filtered_asset.time_block_end,
    hourly_filtered_asset.solution;
    label="hourly",
    title="Storage level for $asset_to_filter",
    xlabel="Hour",
    ylabel="[MWh]",
    xlims=(1, 8760),
    dpi=600,
)
# adding the seasonal storage levels
seasonal_filtered_asset = filter(
    row ->
        row.asset == asset_to_filter,
    seasonal_storage_levels,
)

# multiplying the period_block_end by period_duration (24 in the original example) to have the same time scale
seasonal_filtered_asset.period_block_end .*= period_duration
seasonal_filtered_asset
plot!(
    seasonal_filtered_asset.period_block_end,
    seasonal_filtered_asset.solution;
    label="$num_rps rep periods",
)
```

!!! warning
    This is a mock-up case study with several symmetries in the data, so the results here show the trend but shouldn't be taken as general rules. Each case study needs to be fine-tuned to determine the best number of representatives.

## Finding the Balance

Here you can see a whole script to compare the results from different number of representative periods. See, that the more representatives, the better the approximations (but watch out! the longer the time to solve).

```@example tutorial-5
import TulipaIO as TIO
import TulipaEnergyModel as TEM
import TulipaClustering as TC
using DuckDB
using DataFrames
using Plots
using Distances

input_dir = "my-awesome-energy-system/tutorial-5"

# The hourly benchmark
conn_hourly_benchmark = DBInterface.connect(DuckDB.DB)
TIO.read_csv_folder(conn_hourly_benchmark, input_dir)
TC.transform_wide_to_long!(conn_hourly_benchmark, "profiles_wide", "profiles";)
TC.dummy_cluster!(conn_hourly_benchmark)
TEM.populate_with_defaults!(conn_hourly_benchmark)
DuckDB.query(conn_hourly_benchmark, "UPDATE asset SET is_seasonal = false")
ep_hourly = TEM.run_scenario(conn_hourly_benchmark; show_log = false)

# The plot of the hourly benchmark
storage_levels_hourly = TIO.get_table(conn_hourly_benchmark, "var_storage_level_rep_period")
asset_to_filter = "h2_storage"
hourly_filtered_asset = filter(row -> row.asset == asset_to_filter, storage_levels_hourly)
p = plot(
    hourly_filtered_asset.time_block_end,
    hourly_filtered_asset.solution;
    label = "hourly",
    title = "Storage level for $asset_to_filter",
    xlabel = "Hour",
    ylabel = "[MWh]",
    xlims = (1, 8760),
    legend = Symbol(:outer,:bottom),
    legend_column = -1,
    dpi = 600,
)

# The base for each representative periods run
connection = DBInterface.connect(DuckDB.DB)
TIO.read_csv_folder(connection, input_dir)
TC.transform_wide_to_long!(connection, "profiles_wide", "profiles";)
period_duration = 24

# loop over a list of representatives
list_num_rps = [n * 12 for n in 1:4:10]
for num_rps in list_num_rps
    clusters = TC.cluster!(
        connection,
        period_duration,
        num_rps;
        method = :convex_hull,
        distance = Distances.CosineDist(),
        weight_type = :convex,
    )
    TEM.populate_with_defaults!(connection)
    DuckDB.query(connection, "UPDATE asset SET is_seasonal = true WHERE asset = 'h2_storage'")
    energy_problem = TEM.run_scenario(connection; show_log = false)

    # update the plot for each num_rps
    seasonal_storage_levels = TIO.get_table(connection, "var_storage_level_over_clustered_year")
    seasonal_filtered_asset = filter(row -> row.asset == asset_to_filter, seasonal_storage_levels)
    seasonal_filtered_asset.period_block_end .*= period_duration
    seasonal_filtered_asset
    plot!(
        seasonal_filtered_asset.period_block_end,
        seasonal_filtered_asset.solution;
        label = "$num_rps rps",
    )
end

# show the final plot
p
```
