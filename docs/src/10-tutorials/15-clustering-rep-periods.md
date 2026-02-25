# [Blended Representative Periods with Tulipa Clustering](@id blended-representative-periods)

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
Pkg.add("TulipaClustering")
Pkg.add("Distances")
```

Import packages:

```julia
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

```julia
connection = DBInterface.connect(DuckDB.DB)
input_dir = "my-awesome-energy-system/tutorial-4"
output_dir = "my-awesome-energy-system/tutorial-4/results"
TIO.read_csv_folder(connection, input_dir)
```

!!! warning
    Since the output directory does not exist yet, we need to create the 'results' folder inside our tutorial folder, otherwise it will error later.

!!! tip
    You can use the line `mkdir(output_dir)` to create the results folder if it doesn't exist.

Try to run the problem as usual:

```julia
TEM.populate_with_defaults!(connection)
energy_problem = TEM.run_scenario(connection; output_folder=output_dir)
```

Uh oh! It doesn't work. Why not?

```txt
ERROR: DataValidationException: The following issues were found in the data:
- Column 'rep_period' of table 'rep_periods_data' does not have a default
```

In previous tutorials, the representative periods tables were available in the input directories asumming you had only one representative period for the whole year, e.g., have a look at the tables `profiles_rep_periods`, `rep_periods_data`, `rep_periods_mapping`, and `timeframe_data` in tutorials 1 to 3.

Now, we will learn how to generate these tables using TulipaClustering! 😉

## Using `TulipaClustering`

### Explore the Profiles Data

Let's first take a look at the profiles data we have by looking at the file `profiles-wide.csv` in the input directory. You can also use TulipaIO to read the table and see its contents:

```julia
profiles_wide_df = TIO.get_table(connection, "profiles_wide")
```

The wide is very convenient for humans to read, but not so much for computers to process. We need to transform it into a long format first.

### Transforming the Format from Wide to Long

TulipaClustering provides a function `transform_wide_to_long!` that does exactly that:

```julia
TC.transform_wide_to_long!(
    connection,
    "profiles_wide",
    "profiles";
)
```

Let's have a look at the new table:

```julia
profiles_df = TIO.get_table(connection, "profiles")
```

The new table stacks the columns with profile data into one column called `value` and adds a new column called `profile_name` that contains the names of the profiles. Each row now corresponds to one timestep of one profile per year.

### Clustering the Profiles

We can perform the clustering by using the `cluster!` function from TulipaClustering by passing the connection with the profiles table and two extra arguments:

- `period_duration`: How long are the periods (e.g., 24 for daily periods if the timestep is hourly);
- `num_rps`: How many representative periods.

Let's first use the function `cluster!` with its default parameters. Have a look at the default definition if you're curious.

```julia
period_duration = 24
num_rps = 4
clusters = TC.cluster!(connection, period_duration, num_rps)
```

Explore the results by looking at the new tables created, e.g., `profiles_rep_periods`, `rep_periods_data`, `rep_periods_mapping`, and `timeframe_data`. Remember that you can use  `TIO.get_table(connection, "table_name")` to explore the tables.

Now, let's have a look at the clustering results by plotting the representative periods:

```julia
df = TIO.get_table(connection, "profiles_rep_periods")
rep_periods = unique(df.rep_period)
plots = []

for rp in rep_periods
    df_rp = filter(row -> row.rep_period == rp, df)
    p = plot(size=(400, 300), title="Representative Period $rp")

    for group in groupby(df_rp, :profile_name)
        name = group.profile_name[1]
        plot!(p, group.timestep, group.value, label=name)
    end

    show_legend = (rp == rep_periods[1])
    plot!(p,
          xlabel="Timestep",
          ylabel="Value",
          xticks=0:2:period_duration,
          xlim=(1, period_duration),
          ylim=(0, 1),
          legend=show_legend ? :bottomleft : false,
          legendfontsize=6
         )
    push!(plots, p)
end

plot(plots..., layout=(2, 2), size=(800, 600))
```

Nice! But, do you know we can do better than this? Yes, we can! Let's explore a more advanced clustering method.

### Hull Clustering with Blended Representative Periods

The function `cluster!` has several keyword arguments that can be used to customize the clustering process. Alternatively, you can use the help mode in Julia REPL by typing `?cluster!` to see all the available keyword arguments and their descriptions. Here is a summary of the most important keyword arguments for this example:

- `method` (default `:k_medoids`): clustering method to use `:k_means`, `:k_medoids`, `:convex_hull`, `:convex_hull_with_null`, or `:conical_hull`.
- `distance` (default `Distances.Euclidean()`): semimetric used to measure distance between data points from the the package Distances.jl.
- `weight_type` (default `:dirac`): the type of weights to find; possible values are:
  - `:dirac`: each period is represented by exactly one representative
    period (a one unit weight and the rest are zeros)
  - `:convex`: each period is represented as a convex sum of the
    representative periods (a sum with nonnegative weights adding into one)
  - `:conical`: each period is represented as a conical sum of the
    representative periods (a sum with nonnegative weights)
  - `:conical_bounded`: each period is represented as a conical sum of the
    representative periods (a sum with nonnegative weights) with the total
    weight bounded from above by one.

As you can see, there are several keyword arguments that can be combined to explore different clustering strategies. Our proposed method is the Hull Clustering with Blended Representative Periods, see the [references](https://tulipaenergy.github.io/TulipaClustering.jl/stable/80-scientific-references/) in the TulipaClustering package. To activate this method you need to set up the following keyword arguments:

- `method = :convex_hull`
- `distance = Distances.CosineDist()`
- `weight_type = :convex`

So, let's cluster again using the proposed method:

```julia
using Distances
clusters = TC.cluster!(connection,
                    period_duration,
                    num_rps;
                    method = :convex_hull,
                    distance = Distances.CosineDist(),
                    weight_type = :convex
                    )

# Let's have a look at the new rep_periods_mapping table
TIO.get_table(connection, "rep_periods_mapping")
```

What do you notice about the new representative periods mapping?

Let's plot again the resulting representative periods, but this time using the clustered profiles with the hull clustering method:

```julia
df = TIO.get_table(connection, "profiles_rep_periods")
rep_periods = unique(df.rep_period)
plots = []

for rp in rep_periods
    df_rp = filter(row -> row.rep_period == rp, df)
    p = plot(size=(400, 300), title="Hull Clustering RP $rp")

    for group in groupby(df_rp, :profile_name)
        name = group.profile_name[1]
        plot!(p, group.timestep, group.value, label=name)
    end

    show_legend = (rp == rep_periods[1])
    plot!(p,
          xlabel="Timestep",
          ylabel="Value",
          xticks=0:2:period_duration,
          xlim=(1, period_duration),
          ylim=(0, 1),
          legend=show_legend ? :topleft : false,
          legendfontsize=6
         )
    push!(plots, p)
end

plot(plots..., layout=(2, 2), size=(800, 600))
```

The first difference you may notice is that the representative periods (RPs) obtained with hull clustering are more extreme than those obtained with the default method. This is because hull clustering selects RPs that are more likely to be constraint-binding in an optimization model.

!!! tip "The Projected Gradient Descent Parameters"
    The parameters `niters` and `learning_rate` tell for how many iterations to run the descent and by how much to adjust the weights in each iterations. More iterations make the method slower but produce better results. Larger learning rate makes the method converge faster but in a less stable manner (i.e., weights might start going up and down a lot from iteration to iteration). Sometimes you need to find the right balance for yourself. In general, if the weights produced by the method look strange, try decreasing the learning rate and/or increasing the number of iterations.

## Running the Model

To run the model, add the data to the system with `TulipaIO` and then run it as usual:

```julia
TEM.populate_with_defaults!(connection)
energy_problem = TEM.run_scenario(connection; output_folder=output_dir)
```

## Interpreting the Results

To plot the results, first read the data with `TulipaIO` and filter what's needed (and rename `time_block_start` to `timestep` while you're at it):

```julia
flows = TIO.get_table(connection, "var_flow")

select!(
    flows,
    :from_asset,
    :to_asset,
    :milestone_year,
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
            row.milestone_year == year,
    flows,
)
```

To reinterpret the RP data as base periods data, first create a new dataframe that contains both by using the inner join operation:

```julia
rep_periods_mapping = TIO.get_table(connection, "rep_periods_mapping")
df = innerjoin(filtered_flow, rep_periods_mapping, on=[:milestone_year, :rep_period])
```

Next, use Julia's Split-Apply-Combine approach to group the dataframe into smaller ones. Each grouped dataframe contains a single data point for one base period and all RPs it maps to. Then multiply the results by weights and add them up.

```julia
gdf = groupby(df, [:from_asset, :to_asset, :milestone_year, :period, :timestep])
result_df = combine(gdf, [:weight, :solution] => ((w, s) -> sum(w .* s)) => :solution)
```

Now you can plot the results. Remove the period data since you don't need it anymore, and re-sort the data to make sure it is in the right order.

```julia
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

Here is the whole script for your convenience that runs from top to bottom, skipping errors we encountered along the explanations in this tutorial and not exporting the results to the output folder for sake of brevity:

```@example tutorial-4
# 1. Import packages
import TulipaIO as TIO
import TulipaEnergyModel as TEM
import TulipaClustering as TC
using DuckDB
using DataFrames
using Plots
using Distances

# 2. Set up the connection and read the data
connection = DBInterface.connect(DuckDB.DB)
input_dir = "my-awesome-energy-system/tutorial-4"
TIO.read_csv_folder(connection, input_dir)

# 3. Transform the profiles data from wide to long
profiles_wide_df = TIO.get_table(connection, "profiles_wide")
TC.transform_wide_to_long!(
    connection,
    "profiles_wide",
    "profiles";
)

# 4. Hull Clustering with Blended Representative Periods
period_duration = 24
num_rps = 4
clusters = TC.cluster!(connection,
                    period_duration,
                    num_rps;
                    method = :convex_hull,
                    distance = Distances.CosineDist(),
                    weight_type = :convex
                    )

# 5. plot the representative periods
df = TIO.get_table(connection, "profiles_rep_periods")
rep_periods = unique(df.rep_period)
plots = []
for rp in rep_periods
    df_rp = filter(row -> row.rep_period == rp, df)
    p = plot(size=(400, 300), title="Hull Clustering RP $rp")

    for group in groupby(df_rp, :profile_name)
        name = group.profile_name[1]
        plot!(p, group.timestep, group.value, label=name)
    end

    show_legend = (rp == rep_periods[1])
    plot!(p,
          xlabel="Timestep",
          ylabel="Value",
          xticks=0:2:period_duration,
          xlim=(1, period_duration),
          ylim=(0, 1),
          legend=show_legend ? :topleft : false,
          legendfontsize=6
         )
    push!(plots, p)
end
plot(plots..., layout=(2, 2), size=(800, 600))
```

Let's continue with running the model and plotting the results:

```@example tutorial-4
# 6. Run the model
TEM.populate_with_defaults!(connection)
energy_problem = TEM.run_scenario(connection; show_log = false)

# 7. Plot the results per representative period for a specific flow
flows = TIO.get_table(connection, "var_flow")
select!(
    flows,
    :from_asset,
    :to_asset,
    :milestone_year,
    :rep_period,
    :time_block_start => :timestep,
    :solution
)
from_asset = "electrolizer"
to_asset = "h2_demand"
year = 2030
filtered_flow = filter(
    row ->
        row.from_asset == from_asset &&
            row.to_asset == to_asset &&
            row.milestone_year == year,
    flows,
)
plot(
    filtered_flow.timestep,
    filtered_flow.solution;
    group=filtered_flow.rep_period,
    xlabel="Hour",
    ylabel="[MWh]",
    legend= Symbol(:outer,:bottom),
    legend_column = -1,
    marker=:circle,
    markersize=2,
    xlims=(1, 24),
    title="Flow $from_asset -> $to_asset",
    label=hcat([string("RP ", rp) for rp in 1:num_rps]...),
    dpi=600,
)
```

By using the representative periods results and the `rep_periods_mapping`, we can plot the results in the original periods:

```@example tutorial-4
# 7. Plot the results in the original periods using the representative period results
rep_periods_mapping = TIO.get_table(connection, "rep_periods_mapping")
df = innerjoin(filtered_flow, rep_periods_mapping, on=[:milestone_year, :rep_period])
gdf = groupby(df, [:from_asset, :to_asset, :milestone_year, :period, :timestep])
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

```julia
TIO.get_table(connection,"rep_periods_mapping")
```

If you want to save the intermediary tables created by the clustering, you can do this with DuckDB:

```julia
DuckDB.execute(
    connection,
    "COPY 'profiles_rep_periods' TO 'profiles-rep-periods.csv' (HEADER, DELIMITER ',')",
)
```

Remember, the new tables out from the TulipaClustering are:

- `profiles_rep_periods`
- `rep_periods_data`
- `rep_periods_mapping`
- `timeframe_data`

This is useful when you don't have to rerun the clustering every time.

!!! tip
    If you want to create the tables programmatically using only one dummy representative period for the whole year, you can use the `dummy_cluster!` function from the `TulipaClustering` package. We will use this function in the next tutorial to create a benchmark with hourly data.
