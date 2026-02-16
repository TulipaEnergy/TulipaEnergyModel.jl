# Two-Stage Stochastic Optimization

## Introduction

Stochastic programming is often used to represent the uncertainty in medium- and long-term optimization problems in energy systems, based on the basis that the *uncertainty can be represented by a known probability distribution*. In the context of energy systems, this uncertainty can be related to the availability of renewable energy sources, demand fluctuations, or hydro inflows. Stochastic programming allows for the incorporation of uncertainty by sampling the uncertainty space and creating multiple scenarios that represent different possible future outcomes. This approach enables decision-makers to make informed choices that are prepared against a range of possible future conditions.

A **two-stage stochastic** setting is when there are first stage decisions that are unique for each scenario and there are second stage decisions that are made after the uncertainty is realized. In the context of energy systems, the first stage decisions could be related to investment decisions, such as the capacity of new renewable energy sources to be built, while the second stage decisions could be related to operational decisions, such as how to dispatch the available generation resources to meet demand.

![two stage stochastic programming](../figs/two-stage-stochastic-programming.png)

## Two-Stage Stochastic Optimization with TulipaEnergyModel.jl

TulipaEnergyModel.jl approach to two-stage stochastic optimization is based on the concept of Representative Periods (RPs). RPs are a way to reduce the size of the problem by clustering similar time periods together, see tutorial [Blended Representative Periods with Tulipa Clustering](@ref blended-representative-periods). This is particularly useful in the context of energy systems, where there can be a large number of time periods to consider. By clustering similar time periods together, we can reduce the number of variables and constraints in the optimization problem, making it more tractable.

In the stochastic setting, RPs can be clustered Per or Cross the stochastic scenarios. In that case, the representative periods mapping matrix will relate original periods to representative periods either per scenario (diagonal block structure) or across scenarios (full matrix structure). Here is the concept documentation for more detail: [Clustering per or Cross](https://tulipaenergy.github.io/TulipaClustering.jl/stable/20-concepts/#Clustering-Per-or-Cross)

The TulipaClustering.jl package allows the creation of blended Representative Periods (RPs) to reduce the size of the problem. A tutorial on this package is available under [Tutorial4](https://tulipaenergy.github.io/TulipaEnergyModel.jl/stable/10-tutorials/15-clustering-rep-periods/)

## Previously in the TLC

We reuse the instantiation from previous tutorials, and subsequently use the data of tutorial 9

```julia
using Pkg: Pkg
Pkg.activate(".")
Pkg.instantiate()
Pkg.add("TulipaClustering")
Pkg.add("Distances") # only if update packages
import TulipaIO as TIO
import TulipaEnergyModel as TEM #forces TEM. before calling functions
import TulipaClustering as TC
import CSV
using DuckDB
using DataFrames
import Distances
using Plots
using Statistics

connection = DBInterface.connect(DuckDB.DB)
input_dir = "docs/src/10-tutorials/my-awesome-energy-system/tutorial-9"
output_dir = "docs/src/10-tutorials/my-awesome-energy-system/tutorial-9/results"
TIO.read_csv_folder(connection, input_dir)
```

## Profiles for Stochastic

Show the profiles `profiles-wide`.

```julia
profiles = TIO.get_table(connection, "profiles_wide")
```

Observe a DataFrame of 8760 time steps per scenario. Group the DataFrame by year and scenario and summarize the capacities by taking the mean.

```julia
gdf = groupby(profiles, [:year, :scenario])
result_df = combine(gdf, [:solar, :wind_offshore, :wind_onshore, :demand, :hydro_inflow] .=> mean)
```

There are 3 different weather years and you see the difference in the average capacities of the availability of the RESs and demand in different scenarios.

## Clustering Per Scenario

Transform the data from wide to long and

```julia
TC.transform_wide_to_long!(
    connection,
    "profiles_wide",
    "profiles";
    exclude_columns=["scenario", "year", "timestep"],
)
```

> **Note:** Make the stochastic methods comparable on level of detail by ensuring that the num_rps is not divisible by the number of scenarios.

```julia
n_scenarios = length(unique(profiles_wide.scenario))
layout = TC.ProfilesTableLayout(; cols_to_groupby=[:year, :scenario])
num_rps = 8
period_duration = 24
clusters = TC.cluster!(connection,
                    period_duration,
                    num_rps;
                    method = :convex_hull,
                    distance = Distances.CosineDist(),
                    weight_type = :convex,
                    layout = layout
                    )
```

Populate with defaults and solve the instance.

```julia
TEM.populate_with_defaults!(connection)
energy_problem = TEM.run_scenario(
    connection;
    output_folder=output_dir,
    model_file_name="some-name.lp",
)
```

By clustering, the rep_periods_mapping becomes available in connection.

```julia
df = TIO.get_table(connection, "rep_periods_mapping")
```

### Heat Map visualization Per

How do we want to visualize the RPs? A heat map is a tool that plots large matrices in a scaled manner.

> **Note:** How many rps do you expect?

```julia
df_wide = unstack(df, :rep_period, :weight, fill=0.0)
M = Matrix(df_wide[:, Not([:scenario, :year, :period])])

using Plots

heatmap(
    M,
    xlabel="Representative period",
    ylabel="Origin
    al period",
    colorbar_title="Weight",
    title="Representative period mapping"
)
```

Observe n_rps *n_years* n_scenarios = 8 *1* 3 = 24 rps. Observe the 8 periods over 1 year for each of the 3 scenarios.
> **Note:** The y axis represents an aggregation of scenarios, years, and periods.

## Clustering Cross Scenario

```julia
connection = DBInterface.connect(DuckDB.DB)
input_dir = "docs/src/10-tutorials/my-awesome-energy-system/tutorial-9"
output_dir = "docs/src/10-tutorials/my-awesome-energy-system/tutorial-9/results"
TIO.read_csv_folder(connection, input_dir)
```

```julia
TC.transform_wide_to_long!(
    connection,
    "profiles_wide",
    "profiles";
    exclude_columns=["scenario", "year", "timestep"],
)
```

When clustering Cross Scenario, in the layout we group by years and cross by scenarios.

```julia
layout = TC.ProfilesTableLayout(; cols_to_groupby=[:year], cols_to_crossby=[:scenario])
num_rps = 8
period_duration = 24
clusters = TC.cluster!(connection,
                    period_duration,
                    num_rps;
                    method = :convex_hull,
                    distance = Distances.CosineDist(),
                    weight_type = :convex,
                    layout = layout
                    )
```

Populate with defaults and solve the instance.

```julia
TEM.populate_with_defaults!(connection)
energy_problem = TEM.run_scenario(
    connection;
    output_folder=output_dir,
    model_file_name="some-name.lp",
)
```

By clustering, the rep_periods_mapping becomes available in connection.

```julia
df = TIO.get_table(connection, "rep_periods_mapping")
```

### Heat Map visualization Cross

How do we want to visualize the RPs? A heat map is a tool that plots large matrices in a scaled manner.

> **Note:** How many rps do you expect?

```julia
df_wide = unstack(df, :rep_period, :weight, fill=0.0)
M = Matrix(df_wide[:, Not([:scenario, :year, :period])])

using Plots

heatmap(
    M,
    xlabel="Representative period",
    ylabel="Original period",
    colorbar_title="Weight",
    title="Representative period mapping"
)
```

Observe n_rps *n_years = 8* 1 = 8 representative periods. Observe that with cross-scenario clustering, representative periods can be shared across scenarios (full matrix structure).

## Making the representatives periods comparable on level of detail

Increase the number of rps in the cross scenario clustered case from 8 to 24.

```julia
layout = TC.ProfilesTableLayout(; cols_to_groupby=[:year], cols_to_crossby=[:scenario])
num_rps = 24
period_duration = 24
clusters = TC.cluster!(connection,
                    period_duration,
                    num_rps;
                    method = :convex_hull,
                    distance = Distances.CosineDist(),
                    weight_type = :convex,
                    layout = layout
                    )

df = TIO.get_table(connection, "rep_periods_mapping")
```

### Heat Map visualization

```julia
df_wide = unstack(df, :rep_period, :weight, fill=0.0)
M = Matrix(df_wide[:, Not([:scenario, :year, :period])])

using Plots

heatmap(
    M,
    xlabel="Representative period",
    ylabel="Original period",
    colorbar_title="Weight",
    title="Representative period mapping"
)
```

Observe n_rps *n_years = 24* 1 = 24 representative periods. The Per and Cross Scenario Clustering methods can be compared in terms of level of detail and performance once they produced the same number of representative periods.

## Implications

See [Tutorial 5](https://tulipaenergy.github.io/TulipaEnergyModel.jl/stable/10-tutorials/16-storage/) on seasonal and non-seasonal storage.

### Intra-period constraints

1. Intra-period constraints are always **cyclic** by default in current implementation
2. Intra-period constraints are **scenario independent** and remain the same whether using cross-scenario or per-scenario approaches. Without inter-period constraints, cross vs per-scenario makes no difference

### Inter-period constraints

1. Inter-period constraints are **always scenario dependent**, regardless of cross or per-scenario approach

### Cross vs per scenario approach

1. **Seasonal storage must use per-scenario inter-period constraints** to track seasonality within each scenario (Cross-scenario approach impacts weights but storage still requires scenario-dependent tracking)
2. The key difference appears in the **mapping matrix structure**, not the constraint formulation

<!-- This is a comment

## Clustering Per Scenario

Now we run a case where the representative periods are clustered per scenario. Inspect the data

```julia
connection = DBInterface.connect(DuckDB.DB)
input_dir = "docs/src/10-tutorials/my-awesome-energy-system/tutorial-9/per"
output_dir = "docs/src/10-tutorials/my-awesome-energy-system/tutorial-9/per/results"
TIO.read_csv_folder(connection, input_dir)
TEM.populate_with_defaults!(connection)
```

Solve the instance and plot the heat map.

```julia
energy_problem = TEM.run_scenario(
    connection;
    output_folder=output_dir,
    model_file_name="some-name.lp",
)

df = TIO.get_table(connection, "rep_periods_mapping")

df_wide = unstack(df, :rep_period, :weight, fill=0.0)
M = Matrix(df_wide[:, Not([:scenario, :year, :period])])

using Plots

heatmap(
    M,
    xlabel="Representative period",
    ylabel="Original period",
    colorbar_title="Weight",
    title="Representative period mapping"
)
```
Analyze the results. Observe 3 clusters of 24 periods for both years. With per-scenario: each scenario has its own set of representative periods (diagonal block structure in mapping matrix)

## Cross Scenario Clustering

Inspect the data for the case where we cluster per scenario. How many RPs are you considering? Over how many years?

```julia
connection = DBInterface.connect(DuckDB.DB)
input_dir = "docs/src/10-tutorials/my-awesome-energy-system/tutorial-9"
output_dir = "docs/src/10-tutorials/my-awesome-energy-system/tutorial-9/results"
TIO.read_csv_folder(connection, input_dir)
```

Solve the problem.

```julia
TIO.read_csv_folder(connection, input_dir)
TEM.populate_with_defaults!(connection) # can do this safely if you have all the data, otherw

energy_problem = TEM.run_scenario(
    connection;
    output_folder = output_dir,
    model_file_name = "some-name.lp",
)
```

## Heat Map visualization

How do we want to visualize the RPs? A heat map is a tool that plots large matrices in a scaled manner.

```julia
df = TIO.get_table(connection, "rep_periods_mapping")

df_wide = unstack(df, :rep_period, :weight, fill=0.0)
M = Matrix(df_wide[:, Not([:scenario, :year, :period])])

using Plots

heatmap(
    M,
    xlabel = "Representative period",
    ylabel = "Original period",
    colorbar_title = "Weight",
    title = "Representative period mapping"
)
```

Observe the 8 periods over 2 years across 3 scenarios. With cross-scenario: representative periods can be shared across scenarios (full matrix structure).
> **Note:** The y axis represents an aggregation of scenarios, years, and periods.
-->
