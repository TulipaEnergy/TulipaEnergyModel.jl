# Tutorial 4: Representative Periods with Tulipa Clustering

## Introduction

Using representative periods is a simplification method to reduce the size of the problem.
Instead of solving for every time period, the model solves for a few chosen representatives of the data.
The original data is then reconstructed or approximated by blending the representatives.

Tulipa uses the package [TulipaClustering.jl](https://github.com/TulipaEnergy/TulipaClustering.jl) to choose representatives and cluster input data.

## Set up the environment

Add the new packages:

```julia
using Pkg: Pkg
Pkg.activate(".")
Pkg.add(name="TulipaClustering")
Pkg.add("Distances")
```

Import packages:

```julia=
import TulipaIO as TIO
import TulipaEnergyModel as TEM
import TulipaClustering as TC
using DuckDB
using DataFrames
using Plots
using Distances
```

> **Question:** Do you remember how to install the two new libraries into your environment?

## Set up the workflow

The data for this tutorial can be found in the folder `my-awesome-energy-system/tutorial-4`

Load the data:

```julia=9
connection = DBInterface.connect(DuckDB.DB)
input_dir = "docs/src/10-tutorials/my-awesome-energy-system/tutorial-4"
output_dir = "docs/src/10-tutorials/my-awesome-energy-system/tutorial-4/results"
TIO.read_csv_folder(connection, input_dir)
```

Try to run the problem as usual:

```julia=14
TEM.populate_with_defaults!(connection)
energy_problem = TEM.run_scenario(connection; output_folder=output_dir)
```

Uh oh! It doesn't work. Why not?

```txt
ERROR: DataValidationException: The following issues were found in the data:
- Column 'rep_period' of table 'rep_periods_data' does not have a default
```

Because we need data from the clustering!

## Adding `TulipaClustering`

We need to produce representative period data from the base period data.

### Splitting the Profile Data into Periods

Let's say we want to split the year into days, i.e., periods of length 24. `TulipaClustering` provides two methods that can help: `combine_periods!` combines existing periods into consequentive timesteps, and `split_into_periods!` splits it back into periods of desired length:

```julia=17
period_duration = 24  # group data into days

profiles_df = TIO.get_table(connection, "profiles_periods")
TC.combine_periods!(profiles_df)
TC.split_into_periods!(profiles_df; period_duration)
```

### Clustering the Data

We use `find_representative_periods` to reduce the base periods to RPs. The method has two mandatory positional arguments:

- the profile dataframe,
- the number of representative periods you want to obtain.

You can also change two optional arguments (after a semicolon):

- `drop_incomplete_last_period` tells the algorithm how to treat the last period if it has fewer timesteps than the other ones (defaults to `false`),
- `method` clustering method (defaults to `:k_means`),
- `distance` a metric used to measure how different the datapoints are (defaults to `SqEuclidean()`),

```julia=23
num_rep_periods = 7
method = :k_medoids  # :k_means, :convex_hull, :convex_hull_with_null, :conical_hull
distance = Euclidean()  # CosineDist()

clustering_result = TC.find_representative_periods(profiles_df, num_rep_periods; method, distance)
```

The `clustering_result` contains some useful information:

- `profiles` is a dataframe with profiles for RPs,
- `weight_matrix` is a matrix of weights of RPs in blended periods,
- `clustering_matrix` and `rp_matrix` are matrices of profile data for each base and representative period (useful to keep for the next step, but you should not need these unless you want to do some extra math here)
- `auxiliary_data` contains some extra data that was generated during the clustering process and is generally not interesting to the user who is not planning to interact with the clustering method on a very low level.

### Weight Fitting

After the clustering is done, each period is assigned to one representative period. We call this a "Dirac assignment" after the Dirac measure: a measure that is concentrated on one item (i.e., one base period is mapped into exactly one representative period).

`TulipaClustering` supports blended weights for representative periods. To produce these, we use projected gradient descent. You don't need to know all the math behind it, but it has a few parameters that are useful to understand:

- `weight_type` can be `:conical` (weights are positive), `:conical_bounded` (weights are positive, add at most into one), `:convex` (weights are positive, add into one), `:dirac` (one unit weight and the rest are zeros). The order here is from less restrictive to more restrictive.
- `tol` is the algorithm's tolerance. A tolerance of `1e-2` means that weights are estimated up to two decimal places (e.g., something like `0.15`).
- `niters` and `learning_rate` tell for how many iterations to run the descent and by how much to adjust the weights in each iterations. More iterations make the method slower but produce better results. Larger learning rate makes the method converge faster but in a less stable manner (i.e., weights might start going up and down a lot from iteration to iteration). Sometimes you need to find the right balance for yourself. In general, if the weights produced by the method look strange, try decreasing the learning rate and/or increasing the number of iterations.

Now fit the weights:

```julia=29
weight_type = :dirac  # :convex, :conical, :conical_bounded
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
```

### Running the Model

To run the model, add the data to the system with `TulipaIO` and then run it as usual:

```julia=42
TC.write_clustering_result_to_tables(connection, clustering_result)

TEM.populate_with_defaults!(connection)
energy_problem = TEM.run_scenario(connection; output_folder=output_dir)
```

### Interpreting the Results

To plot the results, first read the data with `TulipaIO` and filter what's needed (and rename `time_block_start` to `timestep` while you're at it):

```julia=47
flows = TIO.get_table(connection, "var_flow")

select!(
    flows,
    :from_asset,
    :to_asset,
    :year,
    :rep_period,
    :time_block_start => :timestep,
    :solution
)

from_asset = "ccgt"
to_asset = "e_demand"
year = 2030

filtered_flow = filter(
    row ->
        row.from_asset == from_asset &&
            row.to_asset == to_asset &&
            row.year == year,
    flows,
)
```

To reinterpret the RP data as base periods data, first create a new dataframe that contains both by using the inner join operation:

```julia=71
rep_periods_mapping = TIO.get_table(connection, "rep_periods_mapping")
df = innerjoin(filtered_flow, rep_periods_mapping, on=[:year, :rep_period])
```

Next, use Julia's Split-Apply-Combine approach to group the dataframe into smaller ones. Each grouped dataframe contains a single data point for one base period and all RPs it maps to. Then multiply the results by weights and add them up.

```julia=73
gdf = groupby(df, [:from_asset, :to_asset, :year, :period, :timestep])
result_df = combine(gdf, [:weight, :solution] => ((w, s) -> sum(w .* s)) => :solution)
```

Now you can plot the results. Remove the period data since you don't need it anymore, and re-sort the data to make sure it is in the right order.

```julia=76
TC.combine_periods!(result_df)
sort!(result_df, :timestep)

plot(
    result_df.timestep,
    result_df.solution;
    label=string(from_asset, " -> ", to_asset),
    xlabel="Hour",
    ylabel="[MWh]",
    marker=:circle,
    markersize=2,
    xlims=(1, 168),
    dpi=600,
)
```

This concludes this tutorial! Play around with different parameters to see how the results change. For example, when you use `:dirac` vs `:convex` weights, do you see the difference? How does the solution change as you increase the number of RPs?

## The Script as a Whole

```julia=
using Pkg
Pkg.activate(".")
# Pkg.add("TulipaEnergyModel")
# Pkg.add("TulipaIO")
Pkg.add("TulipaClustering")
# Pkg.add("DuckDB")
# Pkg.add("DataFrames")
# Pkg.add("Plots")
Pkg.add("Distances")

Pkg.instantiate()

import TulipaIO as TIO
import TulipaEnergyModel as TEM
import TulipaClustering as TC
using DuckDB
using DataFrames
using Plots
using Distances

connection = DBInterface.connect(DuckDB.DB)

input_dir = "my-awesome-energy-system/tutorial-4"
output_dir = "my-awesome-energy-system/tutorial-4/results"

TIO.read_csv_folder(connection, input_dir)


period_duration = 24
profiles_df = TIO.get_table(connection, "profiles_periods")
TC.combine_periods!(profiles_df)
TC.split_into_periods!(profiles_df; period_duration)

num_rep_periods = 2
method = :k_medoids  # :k_means, :convex_hull, :convex_hull_with_null, :conical_hull
distance = Euclidean()  # CosineDist()

clustering_result = TC.find_representative_periods(profiles_df, num_rep_periods; method, distance)

weight_type = :dirac  # :convex, :conical, :conical_bounded
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


flows = TIO.get_table(connection, "var_flow")
select!(
    flows,
    :from_asset,
    :to_asset,
    :year,
    :rep_period,
    :time_block_start => :timestep,
    :solution
)

from_asset = "ccgt"
to_asset = "e_demand"
year = 2030

filtered_flow = filter(
    row ->
        row.from_asset == from_asset &&
            row.to_asset == to_asset &&
            row.year == year,
    flows,
)


rep_periods_mapping = TIO.get_table(connection, "rep_periods_mapping")

df = innerjoin(filtered_flow, rep_periods_mapping, on=[:year, :rep_period])
gdf = groupby(df, [:from_asset, :to_asset, :year, :period, :timestep])
result_df = combine(gdf, [:weight, :solution] => ((w, s) -> sum(w .* s)) => :solution)
TC.combine_periods!(result_df)
sort!(result_df, :timestep)
plot(
    result_df.timestep,
    result_df.solution;
    label=string(from_asset, " -> ", to_asset),
    xlabel="Hour",
    ylabel="[MWh]",
    marker=:circle,
    markersize=2,
    xlims=(1, 168),
    dpi=600,
)

```

## Working with the New Tables Created by TulipaClustering

You can check the new tables with TulipaIO, for example:

```julia=
TIO.get_table(connection,"rep_periods_mapping")
```

If you want to save the intermediary tables created by the clustering, you can do this with DuckDB:

```julia=
DuckDB.execute(
    connection,
    "COPY 'profiles_rep_periods' TO 'profiles-rep-periods.csv' (HEADER, DELIMITER ',')",
)
```

The new tables are:

- profiles_rep_periods
- rep_periods_data
- rep_periods_mapping
- timeframe_data

This is useful when you don't have to rerun the clustering every time.
