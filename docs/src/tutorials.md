# [Tutorials](@id tutorials)

Here are some tutorials on how to use Tulipa.

```@contents
Pages = ["tutorials.md"]
Depth = 5
```

## [Basic example](@id basic-example)

For our first example, let's use a tiny existing dataset.
Inside the code for this package, you can find the folder [`test/inputs/Tiny`](https://github.com/TulipaEnergy/TulipaEnergyModel.jl/tree/main/test/inputs/Tiny), which includes all the files necessary to create a model and solve it.

The files inside the "Tiny" folder define the assets and flows data, their profiles, and their time resolution, as well as define the representative periods and which periods in the full problem formulation they represent.¹

For more details about these files, see [Input](@ref input).

¹ _Ignore bad-assets-data.csv, which is used for testing._

### Run scenario

To read all data from the Tiny folder, perform all necessary steps to create a model, and solve the model, run the following in a Julia terminal:

```@example
using TulipaEnergyModel

input_dir = "../../test/inputs/Tiny" # hide
# input_dir should be the path to Tiny as a string (something like "test/inputs/Tiny")
energy_problem = run_scenario(input_dir)
```

The `energy_problem` variable is of type `EnergyProblem`.
For more details, see the [documentation for that type](@ref TulipaEnergyModel.EnergyProblem) or the section [Structures](@ref).

That's all it takes to run a scenario! To learn about the data required to run your own scenario, see the [Input section](@ref input) of [How to Use](@ref how-to-use).

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
This can be error-prone, so use it with care.
The full description for these structures can be found in [Structures](@ref).

```@example manual
using TulipaEnergyModel

input_dir = "../../test/inputs/Tiny" # hide
# input_dir should be the path to Tiny
table_tree = create_input_dataframes_from_csv_folder(input_dir)
```

The `table_tree` contains all tables in the folder, which are then processed into the internal structures below:

```@example manual
graph, representative_periods, timeframe = create_internal_structures(table_tree)
```

We also need a time partition for the constraints to create the model.
Creating an energy problem automatically computes this data, but since we are doing it manually, we need to calculate it ourselves.

```@example manual
constraints_partitions = compute_constraints_partitions(graph, representative_periods)
```

The `constraints_partitions` has two dictionaries with the keys `:lowest_resolution` and `:highest_resolution`. The lowest resolution dictionary is mainly used to create the constraints for energy balance, whereas the highest resolution dictionary is mainly used to create the capacity constraints in the model.

Finally, we also need dataframes that store the linearized indexes of the variables.

```@example manual
dataframes = construct_dataframes(graph, representative_periods, constraints_partitions, timeframe)
```

Now we can compute the model.

```@example manual
model = create_model(graph, representative_periods, dataframes, timeframe)
```

Finally, we can compute the solution.

```@example manual
solution = solve_model(model)
```

or, if we want to store the `flow`, `storage_level_intra_rp`, and `storage_level_inter_rp` optimal value in the dataframes:

```@example manual
solution = solve_model!(dataframes, model)
```

This `solution` structure is the same as the one returned when using an `EnergyProblem`.

### Change optimizer and specify parameters

By default, the model is solved using the [HiGHS](https://github.com/jump-dev/HiGHS.jl) optimizer (or solver).
To change this, we can give the functions `run_scenario`, `solve_model`, or
`solve_model!` a different optimizer.

For instance, we run the [GLPK](https://github.com/jump-dev/GLPK.jl) optimizer below:

```@example
using TulipaEnergyModel, GLPK

input_dir = "../../test/inputs/Tiny" # hide
energy_problem = run_scenario(input_dir, optimizer = GLPK.Optimizer)
```

or

```@example manual-energy-problem
using GLPK

solution = solve_model!(energy_problem, GLPK.Optimizer)
```

or

```@example manual
using GLPK

solution = solve_model(model, GLPK.Optimizer)
```

Notice that, in any of these cases, we need to explicitly add the GLPK package
ourselves and add `using GLPK` before using `GLPK.Optimizer`.

In any of these cases, default parameters for the `GLPK` optimizer are used,
which you can query using [`default_parameters`](@ref).
You can pass a dictionary using the keyword argument `parameters` to change the defaults.
For instance, in the example below, we change the maximum allowed runtime for
GLPK to be 1 seconds, which will most likely cause it to fail to converge in time.

```@example
using TulipaEnergyModel, GLPK

input_dir = "../../test/inputs/Tiny" # hide
parameters = Dict("tm_lim" => 1)
energy_problem = run_scenario(input_dir, optimizer = GLPK.Optimizer, parameters = parameters)
energy_problem.termination_status
```

For the complete list of parameters, check your chosen optimizer.

These parameters can also be passed via a file. See the
[`read_parameters_from_file`](@ref) function for more details.

### [Using the graph structure](@id graph-tutorial)

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
graph[:ocgt]
```

This is a Julia struct, or composite type, named [GraphAssetData](@ref).
We can access its fields with `.`:

```@example manual
graph[:ocgt].type
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
graph[:ocgt, :demand]
```

The type of the flow struct is [GraphFlowData](@ref).

We can easily find all assets `v` for which a flow `(a, v)` exists for a given asset `a` (in this case, demand):

```@example manual
inneighbor_labels(graph, :demand) |> collect
```

Similarly, all assets `u` for which a flow `(u, a)` exists for a given asset `a` (in this case, ocgt):

```@example manual
outneighbor_labels(graph, :ocgt) |> collect
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

The `solution.flow`, `solution.storage_level_intra_rp`, and `solution.storage_level_inter_rp` values are linearized according to the dataframes in the dictionary `energy_problem.dataframes` with keys `:flows`, `:lowest_storage_level_intra_rp`, and `:storage_level_inter_rp`, respectively.
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

To create a vector with the all values of `storage_level_intra_rp` for a given `a` and `rp`, one can run

```@example solution
a = energy_problem.dataframes[:lowest_storage_level_intra_rp].asset[1]
rp = 1
df = filter(
    row -> row.asset == a && row.rp == rp,
    energy_problem.dataframes[:lowest_storage_level_intra_rp],
    view = true,
)
[solution.storage_level_intra_rp[row.index] for row in eachrow(df)]
```

To create a vector with the all values of `storage_level_inter_rp` for a given `a`, one can run

```@example solution
a = energy_problem.dataframes[:storage_level_inter_rp].asset[1]
df = filter(
    row -> row.asset == a,
    energy_problem.dataframes[:storage_level_inter_rp],
    view = true,
)
[solution.storage_level_inter_rp[row.index] for row in eachrow(df)]
```

### The solution inside the graph

In addition to the solution object, the solution is also stored by the individual assets and flows when [`solve_model!`](@ref) is called (i.e., when using an [EnergyProblem](@ref) object).

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
[energy_problem.graph[u, v].flow[(rp, row.timesteps_block)] for row in eachrow(df)]
```

To create a vector with all the values of `storage_level_intra_rp` for a given `a` and `rp`, one can run

```@example solution
a = energy_problem.dataframes[:lowest_storage_level_intra_rp].asset[1]
rp = 1
df = filter(
    row -> row.asset == a && row.rp == rp,
    energy_problem.dataframes[:lowest_storage_level_intra_rp],
    view = true,
)
[energy_problem.graph[a].storage_level_intra_rp[(rp, row.timesteps_block)] for row in eachrow(df)]
```

To create a vector with all the values of `storage_level_inter_rp` for a given `a`, one can run

```@example solution
a = energy_problem.dataframes[:storage_level_inter_rp].asset[1]
df = filter(
    row -> row.asset == a,
    energy_problem.dataframes[:storage_level_inter_rp],
    view = true,
)
[energy_problem.graph[a].storage_level_inter_rp[row.periods_block] for row in eachrow(df)]
```

### The solution inside the dataframes object

In addition to being stored in the `solution` object, and in the `graph` object, the solution for the `flow`, `storage_level_intra_rp`, and `storage_level_inter_rp` is also stored inside the corresponding DataFrame objects if `solve_model!` is called.

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
a = energy_problem.dataframes[:storage_level_inter_rp].asset[1]
df = filter(
    row -> row.asset == a,
    energy_problem.dataframes[:storage_level_inter_rp],
    view = true,
)
df.solution
```

```@example solution
a = energy_problem.dataframes[:lowest_storage_level_intra_rp].asset[1]
rp = 1
df = filter(
    row -> row.asset == a && row.rp == rp,
    energy_problem.dataframes[:lowest_storage_level_intra_rp],
    view = true,
)
df.solution
```

### Values of constraints and expressions

By accessing the model directly, we can query the values of constraints and expressions.
We need to know the name of the constraint and how it is indexed, and for that, you will need to check the model.

For instance, we can get all incoming flows in the lowest resolution for a given asset for a given representative period with the following:

```@example solution
using JuMP
a = energy_problem.dataframes[:lowest].asset[end]
rp = 1
df = filter(
    row -> row.asset == a && row.rp == rp,
    energy_problem.dataframes[:lowest],
    view = true,
)
[value(energy_problem.model[:incoming_flow_lowest_resolution][row.index]) for row in eachrow(df)]
```

The values of constraints can also be obtained, however, they are frequently indexed in a subset, which means that their indexing is not straightforward.
To know how they are indexed, it is necessary to look at the model code.
For instance, to get the consumer balance, we first need to filter the `:highest_in_out` dataframes by consumers:

```@example solution
df_consumers = filter(
    row -> graph[row.asset].type == :consumer,
    energy_problem.dataframes[:highest_in_out],
    view = false,
);
nothing # hide
```

We set `view = false` to create a copy of this DataFrame so we can make our indexes:

```@example solution
df_consumers.index = 1:size(df_consumers, 1) # overwrites existing index
```

Now we can filter this DataFrame. Note that the names in the stored dataframes are defined as Symbol.

```@example solution
a = :Asgard_E_demand
df = filter(
    row -> row.asset == a && row.rp == rp,
    df_consumers,
    view = true,
)
value.(energy_problem.model[:consumer_balance][df.index])
```

Here `value.` (i.e., broadcasting) was used instead of the vector comprehension from previous examples just to show that it also works.

The value of the constraint is obtained by looking only at the part with variables. So a constraint like `2x + 3y - 1 <= 4` would return the value of `2x + 3y`.

### Writing the output to CSV

To save the solution to CSV files, you can use [`save_solution_to_file`](@ref):

```@example solution
mkdir("outputs")
save_solution_to_file("outputs", energy_problem)
```

### Plotting

In the previous sections, we have shown how to create vectors such as the one for flows. If you want simple plots, you can plot the vectors directly using any package you like.

If you would like more custom plots, check out [TulipaPlots.jl](https://github.com/TulipaEnergy/TulipaPlots.jl), under development, which provides tailor-made plots for _TulipaEnergyModel.jl_.

## [Hydrothermal Dispatch example](@id hydrothermal-example)

Under development!
