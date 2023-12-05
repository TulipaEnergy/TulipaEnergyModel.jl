# [Tutorial](@id tutorial)

Here are some tutorials on how to use Tulipa.

## [Basic example](@id basic-example)

For our first example, let's use a very small existing dataset.
Inside the code for this package, you can find the folder [`test/inputs/Tiny`](https://github.com/TulipaEnergy/TulipaEnergyModel.jl/tree/main/test/inputs/Tiny), which includes all the files necessary to create a TulipaEnergyModel and solve it.

There are 7 files inside the "Tiny" folder. They define the assets and flows data, their profiles, and their time resolution.
Furthermore, there is a file to define the representative periods.
For more details on what are these files mean, see [Input](@ref)

### Run scenario

To read all data from the Tiny folder, perform all necessary steps to create a model and solve it, use the following snippet:

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

Now we can compute the model.

```@example manual
model = create_model(graph, representative_periods, constraints_partitions)
```

Finally, we can compute the solution.

```@example manual
solution = solve_model(model)
```

This `solution` structure is exactly the same as the one returned when using an `EnergyProblem`.

## [Using the graph structure](@id graph-tutorial)

Read about the graph structure in the [Graph](@ref) section first.

We will use the `graph` created above for the "Tiny" dataset.

The first thing that we can do is access all assets.
They are the labels of the graph and can be access via the MetaGraphsNext API:

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

To create a vector with all values of `flow` for a given `(u, v)` and `rp`, one can run

```@example solution
(u, v) = first(edge_labels(graph))
rp = 1
[solution.flow[(u, v), rp, B] for B in graph[u, v].partitions[rp]]
```

To create a vector with the all values of `storage_level` for a given `a` and `rp`, one can run

```@example solution
a = first(labels(graph))
rp = 1
cons_parts = energy_problem.constraints_partitions[:lowest_resolution]
[solution.storage_level[a, rp, B] for B in cons_parts[(a, rp)]]
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
[energy_problem.graph[u, v].flow[(rp, B)] for B in graph[u, v].partitions[rp]]
```

To create a vector with the all values of `storage_level` for a given `a` and `rp`, one can run

```@example solution
a = first(labels(graph))
rp = 1
cons_parts = energy_problem.constraints_partitions[:lowest_resolution]
[energy_problem.graph[a].storage_level[(rp, B)] for B in cons_parts[(a, rp)]]
```

### Values of constraints and expressions

By accessing the model directly, we can query the values of constraints and expresions.
For instance, we can get all incoming flow in the lowest resolution for a given asset at a given time block for a given representative periods with the following:

```@example solution
using JuMP
# a, rp, and cons_parts are defined above
B = cons_parts[(a, rp)][1]
value(energy_problem.model[:incoming_flow_lowest_resolution][a, rp, B])
```

The same can happen for constraints.
For instance, the code below gets the consumer balance:

```@example solution
a = "Asgard_E_demand"
B = cons_parts[(a, rp)][1]
value(energy_problem.model[:consumer_balance][a, rp, B])
```

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

The simplest thing to do is to create vectors.
For instance, in the example below, we plot the flow solution for a given flow.

```@example solution
using Plots

rp = 2
(u, v) = ("Asgard_Solar", "Asgard_E_demand")

domain = graph[u, v].partitions[rp]
flow_value = [solution.flow[(u, v), rp, B] for B in domain]

plot(1:length(domain), flow_value, leg=false)
xticks!(1:length(domain), string.(domain))
```

Notice that the time domain for this flow is regular, so you might want to do some kind of processing.
For instance, we can split the flow into every

```@example solution
domain = energy_problem.representative_periods[rp].time_steps
flow_value = zeros(length(domain))
for B in graph[u, v].partitions[rp]
    flow_value[B] .= solution.flow[(u, v), rp, B] / length(B)
end
ticks = first.(graph[u, v].partitions[rp]) # Starting point of each time block

plot(domain, flow_value, leg=false)
xticks!(ticks)
```
