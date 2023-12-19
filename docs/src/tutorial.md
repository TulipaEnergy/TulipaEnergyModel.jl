# [Tutorial](@id tutorial)

Here are some tutorials on how to use Tulipa.

## [Basic example](@id basic-example)

For our first example, let's use a very small existing dataset.
Inside the code for this package, you can find the folder [`test/inputs/Tiny`](https://github.com/TulipaEnergy/TulipaEnergyModel.jl/tree/main/test/inputs/Tiny), which includes all the files necessary to create a TulipaEnergyModel and solve it.

There are 8 relevant¹ files inside the "Tiny" folder. They define the assets and flows data, their profiles, and their time resolution, as well as two files to define the representative periods and which periods in the full problem formulation they stand for.

For more details about these files, see [Input](@ref).

¹ _Ignore the 9th file, bad-assets-data.csv, which is used for testing._

### Run scenario

To read all data from the Tiny folder, perform all necessary steps to create a model, and solve the model, use the following snippet:

```@example
using TulipaEnergyModel

input_dir = "../../test/inputs/Tiny" # hide
# input_dir should be the path to Tiny
energy_problem = run_scenario(input_dir)
```

The `energy_problem` variable is of type `EnergyProblem`.
For more details, see the [documentation for that type](@ref TulipaEnergyModel.EnergyProblem), or the section [Structures](@ref).

### Manually running each step

If we need more control, we can create the energy problem first, then the optimization model inside it, and finally ask for it to be solved.

```@example manual-energy-problem
using TulipaEnergyModel

input_dir = "../../test/inputs/Tiny" # hide
# input_dir should be the path to Tiny
energy_problem = create_energy_problem_from_csv_folder(input_dir)
```

The energy problem does not have a model yet:

```@example manual-energy-problem
energy_problem.model === nothing
```

To create the internal model, we call the function [`create_model!`](@ref).

```@example manual-energy-problem
create_model!(energy_problem)
energy_problem.model
```

The model has not been solved yet, which can be verified through the `solved` flag inside the energy problem:

```@example manual-energy-problem
energy_problem.solved
```

Finally, we can solve the model:

```@example manual-energy-problem
solution = solve_model!(energy_problem)
```

The solution is included in the individual assets and flows, but for completeness, we return the full `solution` object, also defined in the [Structures](@ref) section.

In particular, the objective value and the termination status are also included in the energy problem:

```@example manual-energy-problem
energy_problem.objective_value, energy_problem.termination_status
```

### Manually creating all structures without EnergyProblem

For additional control, it might be desirable to use the internal structures of `EnergyProblem` directly.
This can be error prone, but it is slightly more efficient.
The full description for these structures can be found in [Structures](@ref).

```@example manual
using TulipaEnergyModel

input_dir = "../../test/inputs/Tiny" # hide
# input_dir should be the path to Tiny
graph, representative_periods = create_graph_and_representative_periods_from_csv_folder(input_dir)
```

To create the model we also need a time partition for the constraints.
Creating an energy problem automatically computes this data, but since we are doing it manually, we need to compute it ourselves.

```@example manual
constraints_partitions = compute_constraints_partitions(graph, representative_periods)
```

The `constraints_partitions` has two dictionaries with the keys `:lowest_resolution` and `:highest_resolution`. The lowest resolution dictionary is mainly used to create the constraints for energy balance, whereas the highest resolution dictionary is mainly used to create the capacity constraints in the model.

Finally, we also need dataframes that store the linearized indexes of the variables.

```@example manual
dataframes = construct_dataframes(graph, representative_periods, constraints_partitions)
```

Now we can compute the model.

```@example manual
model = create_model(graph, representative_periods, dataframes)
```

Finally, we can compute the solution.

```@example manual
solution = solve_model(model)
```

or, if we want to store the `flow` and `storage_level` optimal value in the dataframes:

```@example manual
solution = solve_model!(dataframes, model)
```

This `solution` structure is exactly the same as the one returned when using an `EnergyProblem`.

### Change optimizer and specify parameters

By default, the model is solved using the [HiGHS](https://github.com/jump-dev/HiGHS.jl) optimizer (or solver).
To change this, we can give the functions `run_scenario`, `solve_model`, or
`solve_model!` a different optimizer.

For instance, we run the [Cbc](https://github.com/jump-dev/Cbc.jl) optimizer below:

```@example
using TulipaEnergyModel, Cbc

input_dir = "../../test/inputs/Tiny" # hide
energy_problem = run_scenario(input_dir, optimizer = Cbc.Optimizer)
```

or

```@example manual-energy-problem
using Cbc

solution = solve_model!(energy_problem, Cbc.Optimizer)
```

or

```@example manual
using Cbc

solution = solve_model(model, Cbc.Optimizer)
```

Notice that, in any of these cases, we need to explicitly add the Cbc package
ourselves and add `using Cbc` before using `Cbc.Optimizer`.

In any of these cases, default parameters for the `Cbc` optimizer are used,
which you can query using [`default_parameters`](@ref).
If you want to change these, you can pass a dictionary via the keyword argument `parameters`.
For instance, in the example below, we change the maximum allowed runtime for
Cbc to be 0.01 seconds, which causes it to fail to converge in time.

```@example
using TulipaEnergyModel, Cbc

input_dir = "../../test/inputs/Tiny" # hide
parameters = Dict("seconds" => 0.01)
energy_problem = run_scenario(input_dir, optimizer = Cbc.Optimizer, parameters = parameters)
energy_problem.termination_status
```

For the full list of parameters, check your chosen optimizer.

These parameters can also be passed via a file. See the
[`read_parameters_from_file`](@ref) function for more details.

## [Using the graph structure](@id graph-tutorial)

Read about the graph structure in the [Graph](@ref) section first.

We will use the `graph` created above for the "Tiny" dataset.

The first thing that we can do is access all assets.
They are the labels of the graph and can be accessed via the MetaGraphsNext API:

```@example manual
using MetaGraphsNext
# Accessing assets
labels(graph)
```

Notice that the result is a generator, so if we want the actual results, we have to collect it:

```@example manual
labels(graph) |> collect
```

To access the asset data, we can index the graph with an asset label:

```@example manual
graph["ocgt"]
```

This is a Julia struct, or composite type, named [GraphAssetData](@ref).
We can access its fields with `.`:

```@example manual
graph["ocgt"].type
```

Since `labels` returns a generator, we can iterate over its contents without collecting it into a vector.

```@example manual
for a in labels(graph)
    println("Asset $a has type $(graph[a].type)")
end
```

To get all flows we can use `edge_labels`:

```@example manual
edge_labels(graph) |> collect
```

To access the flow data, we index with `graph[u, v]`:

```@example manual
graph["ocgt", "demand"]
```

The type of the flow struct is [GraphFlowData](@ref).

We can easily find all assets `v` for which a flow `(a, v)` exists:

```@example manual
inneighbor_labels(graph, "demand") |> collect
```

Similarly, all assets `u` for which a flow `(u, a)` exists:

```@example manual
outneighbor_labels(graph, "ocgt") |> collect
```

## [Manipulating the solution](@id solution-tutorial)

First, see the description of the [solution](@ref Solution) object.

Let's consider the larger dataset "Norse" in this section. And let's talk about two ways to access the solution.

### The solution returned by solve_model

The solution, as shown before, can be obtained when calling [`solve_model`](@ref) or [`solve_model!`](@ref).

```@example solution
using TulipaEnergyModel

input_dir = "../../test/inputs/Norse" # hide
# input_dir should be the path to Norse
energy_problem = create_energy_problem_from_csv_folder(input_dir)
create_model!(energy_problem)
solution = solve_model!(energy_problem)
nothing # hide
```

To create a traditional array in the order given by the investable assets, one can run

```@example solution
using MetaGraphsNext

graph = energy_problem.graph
[solution.assets_investment[a] for a in labels(graph) if graph[a].investable]
```

To create a traditional array in the order given by the investable flows, one can run

```@example solution
[solution.flows_investment[(u, v)] for (u, v) in edge_labels(graph) if graph[u, v].investable]
```

The `solution.flow` and `solution.storage_level` values are linearized according to the dataframes in the dictionary `energy_problem.dataframes` with keys `:flows` and `:storage_level`, respectively.
You need to query the data from these dataframes and then use the column `index` to select the appropriate value.

To create a vector with all values of `flow` for a given `(u, v)` and `rp`, one can run

```@example solution
(u, v) = first(edge_labels(graph))
rp = 1
df = filter(
    row -> row.rp == rp && row.from == u && row.to == v,
    energy_problem.dataframes[:flows],
    view = true,
)
[solution.flow[row.index] for row in eachrow(df)]
```

To create a vector with the all values of `storage_level` for a given `a` and `rp`, one can run

```@example solution
a = energy_problem.dataframes[:storage_level].asset[1]
rp = 1
df = filter(
    row -> row.asset == a && row.rp == rp,
    energy_problem.dataframes[:storage_level],
    view = true,
)
[solution.storage_level[row.index] for row in eachrow(df)]
```

> **Note**
> Make sure to specify `constraints_partitions[:lowest_resolution]` since the storage level is determined in the energy balance constraint for the storage assets. This constraint is defined in the lowest resolution of all assets and flows involved.

### The solution inside the graph

In addition to the solution object, the solution is also stored by the individual assets and flows when [`solve_model!`](@ref) is called - i.e., when using a [EnergyProblem](@ref) object.

They can be accessed like any other value from [GraphAssetData](@ref) or [GraphFlowData](@ref), which means that we recreate the values from the previous section in a new way:

```@example solution
[energy_problem.graph[a].investment for a in labels(graph) if graph[a].investable]
```

```@example solution
[energy_problem.graph[u, v].investment for (u, v) in edge_labels(graph) if graph[u, v].investable]
```

```@example solution
(u, v) = first(edge_labels(graph))
rp = 1
df = filter(
    row -> row.rp == rp && row.from == u && row.to == v,
    energy_problem.dataframes[:flows],
    view = true,
)
[energy_problem.graph[u, v].flow[(rp, row.time_block)] for row in eachrow(df)]
```

To create a vector with the all values of `storage_level` for a given `a` and `rp`, one can run

```@example solution
a = energy_problem.dataframes[:storage_level].asset[1]
rp = 1
df = filter(
    row -> row.asset == a && row.rp == rp,
    energy_problem.dataframes[:storage_level],
    view = true,
)
[energy_problem.graph[a].storage_level[(rp, row.time_block)] for row in eachrow(df)]
```

### The solution inside the dataframes object

In addition to being stored in the `solution` object, and in the `graph` object, the solution for the flow and the storage_level is also stored inside the corresponding DataFrame objects if `solve_model!` is called.

The code below will do the same as in the two previous examples:

```@example solution
(u, v) = first(edge_labels(graph))
rp = 1
df = filter(
    row -> row.rp == rp && row.from == u && row.to == v,
    energy_problem.dataframes[:flows],
    view = true,
)
df.solution
```

```@example solution
a = energy_problem.dataframes[:storage_level].asset[1]
rp = 1
df = filter(
    row -> row.asset == a && row.rp == rp,
    energy_problem.dataframes[:storage_level],
    view = true,
)
df.solution
```

### Values of constraints and expressions

By accessing the model directly, we can query the values of constraints and expressions.
We need to know the name of the constraint and how it is indexed, and for that you will need to check the model.

For instance, we can get all incoming flow in the lowest resolution for a given asset for a given representative periods with the following:

```@example solution
using JuMP
# a and rp are defined above
df = filter(
    row -> row.asset == a && row.rp == rp,
    energy_problem.dataframes[:cons_lowest],
    view = true,
)
[value(energy_problem.model[:incoming_flow_lowest_resolution][row.index]) for row in eachrow(df)];
```

The values of constraints can also be obtained, however they are frequently indexed in a subset, which means that their indexing is not straightforward.
To know how they are indexed, it is necessary to look at the code of the model.
For instance, to get the consumer balance, we first need to filter the `:cons_lowest` dataframes by consumers:

```@example solution
df_consumers = filter(
    row -> graph[row.asset].type == "consumer",
    energy_problem.dataframes[:cons_lowest],
    view = false,
);
nothing # hide
```

We set `view = false` to create a copy of this DataFrame, so we can create our indexes:

```@example solution
df_consumers.index = 1:size(df_consumers, 1) # overwrites existing index
```

Now we can filter this DataFrame.

```@example solution
a = "Asgard_E_demand"
df = filter(
    row -> row.asset == a && row.rp == rp,
    df_consumers,
    view = true,
)
value.(energy_problem.model[:consumer_balance][df.index]);
```

Here `value.` (i.e., broadcasting) was used instead of the vector comprehension from previous examples just to show that it also works.

The value of the constraint is obtained by looking only at the part with variables. So a constraint like `2x + 3y - 1 <= 4` would return the value of `2x + 3y`.

### Writing the output to CSV

The simplest way to save the output to CSV is to use packages CSV and DataFrames.
Here is an example that saves the investment on the investable flows.

```@example solution
using CSV, DataFrames
df = DataFrame(; asset_from = String[], asset_to = String[], investment = Float64[])
for (u, v) in edge_labels(graph)
    if graph[u, v].investable
        push!(df, (u, v, solution.flows_investment[(u, v)]))
    end
end
CSV.write("flows_investment.csv", df)
```

Reading it back to show the  result:

```@example solution
CSV.read("flows_investment.csv", DataFrame)
```

### Plotting

Tulipa has three functions for plotting: a time-series flows, a visualisation of the graph (with asset and flow capacities), and a bar graph of the initial and invested asset capacities.

Plot a single flow for a single representative period:

```@example solution
plot_single_flow(graph, "Asgard_Solar", "Asgard_E_demand", 1)
```

Plot the graph, with asset and flow capacities:

```@example solution
plot_graph(graph)
```

Graph the final capacities of assets:

```@example solution
plot_assets_capacity(graph)
```

If you would like more custom plots, explore the code of [plot](https://github.com/TulipaEnergy/TulipaEnergyModel.jl/blob/main/src/plot.jl) for ideas.
