# [How to Use](@id how-to-use)

```@contents
Pages = ["how-to-use.md"]
Depth = 5
```

## Install

* Clone the repository from [TulipaEnergyModel.jl](https://github.com/TulipaEnergy/TulipaEnergyModel.jl) into your local machine
* Open the project in your favorite IDE (e.g., [Visual Studio Code](https://code.visualstudio.com/))
* Start a Julia REPL and then:
  * `]`: Enter package mode
  * `activate .` : Activate here (root of project)
  * `instantiate` : Instantiate any packages you need according to the Project.toml
  * `test`: (Optional) Try running the tests to see if you're set up correctly - they should pass

## Run Scenario

To run a scenario, use the function:

* [`run_scenario(input_folder)`](@ref)
* [`run_scenario(input_folder, output_folder)`](@ref)

The input_folder should contain CSV files as described below. The output_folder is optional, if the user wants to export the output.

## Input

Currently, we only accept input from CSV files.
There should be 7 files, each following the specification of input structures.
You can also check the [`test/inputs` folder](https://github.com/TulipaEnergy/TulipaEnergyModel.jl/tree/main/test/inputs) for examples.

### CSV

#### `assets-data.csv`

This files includes the list of assets and the data associate with each of them.

Required columns:

```@eval
using Markdown, TulipaEnergyModel
out = ""
for (f, t) in zip(fieldnames(TulipaEnergyModel.AssetData), fieldtypes(TulipaEnergyModel.AssetData))
    global out *= "- `$f: $t`\n"
end
Markdown.parse(out)
```

#### `flows-data.csv`

Similar to `assets-data.csv`, but for flows. Each flow is defined as a pair of assets.

Required columns:

```@eval
using Markdown, TulipaEnergyModel
out = ""
for (f, t) in zip(fieldnames(TulipaEnergyModel.FlowData), fieldtypes(TulipaEnergyModel.FlowData))
    global out *= "- `$f: $t`\n"
end
Markdown.parse(out)
```

#### `assets-profiles.csv`

This file contains the profiles for each asset.

Required columns:

```@eval
using Markdown, TulipaEnergyModel
out = ""
for (f, t) in zip(fieldnames(TulipaEnergyModel.AssetProfiles), fieldtypes(TulipaEnergyModel.AssetProfiles))
    global out *= "- `$f: $t`\n"
end
Markdown.parse(out)
```

#### `flows-profiles.csv`

Similar to `assets-profiels.csv`, but for flows.

Required columns:

```@eval
using Markdown, TulipaEnergyModel
out = ""
for (f, t) in zip(fieldnames(TulipaEnergyModel.FlowProfiles), fieldtypes(TulipaEnergyModel.FlowData))
    global out *= "- `$f: $t`\n"
end
Markdown.parse(out)
```

#### `assets-partitions.csv`

Contains a description of the [partition](@ref Partition) for each asset.
If not specified, each asset will have the same time resolution as representative period.

To specify the desired resolution, there are currently three options, based on the value of the column `specification`.
The column `partition` serves to specify the partitions in the specification given by the column `specification`.

* `specification = uniform`: Set the resolution to a uniform amount, i.e., a time block is made of X time steps. The number X is defined in the column `partition`. The number of time steps in the representative period must be divisible by `X`.
* `specification = explicit`: Set the resolution acording to a list of numbers separated by `;` on the `partition`. Each number the list is the number of time steps for that time block. For instance, `2;3;4` means that there are three time blocks, the first has 2 time steps, the second has 3 time steps, and the last has 4 time steps. The sum of the number of time steps must be equal to the total number of time steps in that representative period.
* `specification = math`: Similar to explicit, but using `+` and `x` to give the number of time steps. The value of `partition` is a sequence of elements of the form `NxT` separated by `+`. `NxT` means `N` time blocks of length `T`.

The table below shows various results for different formats for a representative period with 12 time steps.

| Time Block            | :uniform | :explicit               | :math       |
|:--------------------- |:-------- |:----------------------- |:----------- |
| 1:3, 4:6, 7:9, 10:12  | 3        | 3;3;3;3                 | 4x3         |
| 1:4, 5:8, 9:12        | 4        | 4;4;4                   | 3x4         |
| 1:1, 2:2, …, 12:12    | 1        | 1;1;1;1;1;1;1;1;1;1;1;1 | 12x1        |
| 1:3, 4:6, 7:10, 11:12 | NA       | 3;3;4;2                 | 2x3+1x4+1x2 |

Required columns:

```@eval
using Markdown, TulipaEnergyModel
out = ""
for (f, t) in zip(fieldnames(TulipaEnergyModel.AssetPartitionData), fieldtypes(TulipaEnergyModel.AssetPartitionData))
    global out *= "- `$f: $t`\n"
end
Markdown.parse(out)
```

#### `flows-partitions.csv`

Similar to `assets-partitions.csv`, but for flows.

Required columns:

```@eval
using Markdown, TulipaEnergyModel
out = ""
for (f, t) in zip(fieldnames(TulipaEnergyModel.FlowPartitionData), fieldtypes(TulipaEnergyModel.FlowPartitionData))
    global out *= "- `$f: $t`\n"
end
Markdown.parse(out)
```

#### `rep-periods-data.csv`

Describes the [representative periods](@ref representative-periods).

Required columns:

```@eval
using Markdown, TulipaEnergyModel
out = ""
for (f, t) in zip(fieldnames(TulipaEnergyModel.RepPeriodData), fieldtypes(TulipaEnergyModel.RepPeriodData))
    global out *= "- `$f: $t`\n"
end
Markdown.parse(out)
```

## Structures

The list of relevant structures used in this package are listed below:

### EnergyProblem

The `EnergyProblem` structure is a wrapper around various other relevant structures.
It hides the complexity behind the energy problem, making the usage more friendly, although more verbose.

The fields of `EnergyProblem` are

* `graph`: The [Graph](@ref) object that defines the geometry of the energy problem.
* `representative_periods`: A vector of [Representative Periods](@ref representative-periods).
* `constraints_partitions`: Dictionaries that connects pairs of asset and representative periods to [time partitions (vectors of time blocks)](@ref Partition)
* `model`: A JuMP model object. Initially `nothing`.
* `solved`: A boolean indicating whether the `model` has been solved or not.
* `objective_value`: After the model has been solved, this is the objective value at the solution.
* `termination_status`: After the model has been solved, this is the termination status.

See the [basic example tutorial](@ref basic-example) to see how these can be used.

### Graph

The energy problem is defined using a graph.
Each vertex is an asset and each edge is a flow.

We use [MetaGraphsNext.jl](https://github.com/JuliaGraphs/MetaGraphsNext.jl) to define the graph and its objects.
Using MetaGraphsNext we can define a graph with metadata, i.e., we can associate data to each asset and each flow.
Furthermore, we can define the labels of each asset as keys to access the elements of the graph.
The assets in the graph are of type [GraphAssetData](@ref), and the flows are of type [GraphFlowData](@ref).

The graph can be created using the [`create_graph_and_representative_periods_from_csv_folder`](@ref) function, or it can be accessed from an [EnergyProblem](@ref).

See how to use the graph in the [graph tutorial](@ref graph-tutorial).

### GraphAssetData

This structure holds all the information of a given asset.
These are stored inside the [Graph](@ref).
Given a graph `graph` and an asset `a`, it can be access through `graph[a]`.

### GraphFlowData

This structure holds all the information of a given flow.
These are stored inside the [Graph](@ref).
Given a graph `graph` and a flow `(u, v)`, it can be access through `graph[u, v]`.

### Partition

A [representative period](@ref representative-periods) will be defined with a number of time steps.
A partition is a division of these time steps into [time blocks](@ref time-blocks) such that the time blocks are disjunct and that all time steps belong to some time block.
Some variables and constraints are defined over every time block in a partition.

For instance, for a representative period with 12 time steps, all sets below are partitions:

* ``\{\{1, 2, 3\}, \{4, 5, 6\}, \{7, 8, 9\}, \{10, 11, 12\}\}``
* ``\{\{1, 2, 3, 4\}, \{5, 6, 7, 8\}, \{9, 10, 11, 12\}\}``
* ``\{\{1\}, \{2, 3\}, \{4\}, \{5, 6, 7, 8\}, \{9, 10, 11, 12\}\}``

### [Representative Periods](@id representative-periods)

The full year is represented by a few periods of time, for instance, days or weeks, that nicely summarize other similar periods.
For instance, we could model the year into 3 days, by clustering all days of the year into 3 representative days.
Each one of these periods of time is called a representative period.
They have been obtained by clustering through [TulipaClustering](https://github.com/TulipaEnergy/TulipaClustering.jl).

A representative period was three fields:

* `weight`: indicates how many representative periods is contained in that year.
* `time_steps`: The number of time steps in that year.
* `resolution`: The duration in time of a time step.

The number of time steps and resolution work together to define the coarseness of the period.
Nothing is defined outside of these time steps, so, for instance, if the representative period represents a day, and you want to define a variable or constraint with coarseness of 30 minutes, then you need to define the number of time steps to 48 and the resolution to `0.5`.

### Solution

The solution object is a NamedTuple with the following fields:

* `objective_value`: A Float64 with the objective value at the solution.
* `assets_investment[a]`: The investment for each asset, indexed on the investable asset `a`.
* `flows_investment[u, v]`: The investment for each flow, indexed on the investable flow `(u, v)`.
* `flow[(u, v), rp, B]`: The flow value for a given flow `(u, v)` at a given representative period `rp`, and time block `B`. The list of time blocks is defined by `graph[(u, v)].partitions[rp]`.
* `storage_level[a, rp, B]`: The storage level for the storage asset `a` for a representative period `rp` and a time block `B`. The list of time blocks is defined by `constraints_partitions`, which was used to create the model.

For tips on manipulating the solution, check the [tutorial](@ref solution-tutorial).

### [Time Blocks](@id time-blocks)

A time block is a quantity of time for which a variable or constraint is defined.
Currently, it is a range of numbers, i.e., all integer numbers inside an interval.
