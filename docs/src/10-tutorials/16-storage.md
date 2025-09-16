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

Let's start the workflow in Lesson 4, but using our new storage data (and a temporary hack - sorry, a fix is coming soon):

```julia=
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

input_dir = "docs/src/10-tutorials/my-awesome-energy-system/tutorial-5"
output_dir = "docs/src/10-tutorials/my-awesome-energy-system/tutorial-5/results"

TIO.read_csv_folder(connection, input_dir)

period_duration = 24
profiles_df = TIO.get_table(connection, "profiles_periods")
TC.combine_periods!(profiles_df)
TC.split_into_periods!(profiles_df; period_duration)

num_rep_periods = 10
method = :convex_hull  # :k_means, :convex_hull, :convex_hull_with_null, :conical_hull
distance = CosineDist()  # CosineDist()

clustering_result = TC.find_representative_periods(profiles_df, num_rep_periods; method, distance)

weight_type = :convex  # :convex, :conical, :conical_bounded
tol = 1e-2
niters = 100
learning_rate = 0.001

TC.fit_rep_period_weights!(
    clustering_result;
    weight_type,
    tol,
    niters,
    learning_rate,
)
TC.write_clustering_result_to_tables(connection, clustering_result)

TEM.populate_with_defaults!(connection)

energy_problem = TEM.run_scenario(connection; output_folder=output_dir)
```

At this point, everything should work the same as Lesson 4.

## Results

> **Note:** Remember to look at your output folder to see the exported results and check which primal and dual information you want to analyze.

Nice, so what about the storage level?

```julia=98
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

What is happening? Any ideas?

It seems that 2 representative periods is not that fun.

Change the number of representatives to 10 and rerun the whole workflow.

>**Note:** You need to run the whole workflow to update the representatives.

The battery storage looks reasonable, but what is happening with the hydrogen storage?

## The parameter `is_seasonal`

Change the parameter `is_seasonal` from `false` to `true` for the hydrogen storage in the file `assets.csv`.

Rerun the workflow and check the results again...

What do you notice in the output folder? Any new variables/constraints?

Check the storage level of the hydrogen storage.
>**Note:** It's now in the variable `var_storage_level_over_clustered_year` because it's seasonal.
TIO.get_table(connection, "var_storage_level_over_clustered_year") # Or any other table name

```julia=
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
        xlabel="Hour",
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
2. Runs TulipaClustering with 1 representative period of 8760 hours. Therefore, the whole hourly year\
   *TulipaClustering does not cluster in this case, it just runs to create the necessary tables for TulipaEnergyModel*
3. Updates the values of the `is_seasonal` parameter to `false`.\
   *Since it is 1 year and 1 representative, the storage is not considered seasonal (it is within the representative period)*
4. Stores the run in a new object called `ep_hourly`

```julia=
## Hourly benchmark
conn_hourly_benchmark = DBInterface.connect(DuckDB.DB)
TIO.read_csv_folder(conn_hourly_benchmark, input_dir)
period_duration_year = 8760 # the whole year
### we are working in a wrapper function to have less code when calling TulipaClustering ;)
profiles_df = TIO.get_table(conn_hourly_benchmark, "profiles_periods")
TC.combine_periods!(profiles_df)
TC.split_into_periods!(profiles_df; period_duration=period_duration_year)
num_rep_periods_year = 1 # the whole year
method = :convex_hull  # :k_means, :convex_hull, :convex_hull_with_null, :conical_hull
distance = CosineDist()  # CosineDist()
clustering_result = TC.find_representative_periods(profiles_df, num_rep_periods_year; method, distance)
weight_type = :convex  # :convex, :conical, :conical_bounded
tol = 1e-2
niters = 100
learning_rate = 0.001
TC.fit_rep_period_weights!(
    clustering_result;
    weight_type,
    tol,
    niters,
    learning_rate,
)
TC.write_clustering_result_to_tables(conn_hourly_benchmark, clustering_result)
TEM.populate_with_defaults!(conn_hourly_benchmark)
DuckDB.query(
    conn_hourly_benchmark, "ALTER TABLE rep_periods_mapping ALTER COLUMN period SET DATA TYPE INT")
### we update the `is_seasonal` column to false to make sure all the storage assets are non-seasonal since we only have one representative period that is the whole year
DuckDB.query(
    conn_hourly_benchmark, "UPDATE asset SET is_seasonal = false")
### we can solve it know
ep_hourly = TEM.run_scenario(conn_hourly_benchmark)
```

You can use this result and the ones from the clustering to see the comparison of the two solutions.\
Here is an example of how to combine the plots for this case:

```julia=
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
    label="$num_rep_periods rep periods",
)
```

> Caveat! This is a mock-up case study with several symmetries in the data, so the results here show the trend but shouldn't be taken as general rules. Each case study needs to be fine-tuned to determine the best number of representatives.

Here you can see the results comparing from different number of representative periods. See, that the more representatives, the better the approximations (but watch out! the longer the time to solve).

![seasonal_storage_levels](https://hackmd.io/_uploads/Hy-oYMGWel.png)

Here there is a zoom to best approximation of the hydrogen storage:

![seasonal_storage_levels-2](https://hackmd.io/_uploads/HkhIpMfWge.png)
