# [How to Use](@id how-to-use)

```@contents
Pages = ["how-to-use.md"]
Depth = 5
```

## Install

In Julia:

-   Enter package mode (press "]")

```julia-pkg
pkg> add TulipaEnergyModel
```

-   Return to Julia mode (backspace)

```julia
julia> using TulipaEnergyModel
```

Optional (takes a minute or two):

-   Enter package mode (press "]")

```julia-pkg
pkg> test TulipaEnergyModel
```

(All tests should pass.)

## Run Scenario

To run a scenario, use the function:

-   [`run_scenario(input_folder)`](@ref)
-   [`run_scenario(input_folder, output_folder)`](@ref)

The `input_folder` should contain CSV files as described below. The `output_folder` is optional if the user wants to export the output.

## [Input](@id input)

Currently, we only accept input from CSV files that follow the [Schemas](@ref schemas).
You can also check the [`test/inputs` folder](https://github.com/TulipaEnergy/TulipaEnergyModel.jl/tree/main/test/inputs) for examples.

### CSV

Below, we have a description of the files.
At the end, in [Schemas](@ref schemas), we have the expected columns in these CSVs.

#### [`assets-data.csv`](@id assets-data)

This file contains the list of assets and the data associated with each of them.

The investment parameters are as follows:

-   The `investable` parameter determines whether there is an investment decision for the asset or flow.
-   The `investment_integer` parameter determines if the investment decision is integer or continuous.
-   The `investment_cost` parameter represents the cost in the defined [timeframe](@ref timeframe). Thus, if the timeframe is a year, the investment cost is the annualized cost of the asset.
-   The `investment_limit` parameter limits the total investment capacity of the asset or flow. This limit represents the potential of that particular asset or flow. Without data in this parameter, the model assumes no investment limit.

The meaning of `Missing` data depends on the parameter, for instance:

-   `investment_limit`: There is no investment limit.
-   `initial_storage_level`: The initial storage level is free (between the storage level limits), meaning that the optimization problem decides the best starting point for the storage asset. In addition, the first and last time blocks in a representative period are linked to create continuity in the storage level.

#### [`flows-data.csv`](@id flows-data)

The same as [`assets-data.csv`](@ref assets-data), but for flows. Each flow is defined as a pair of assets.

The meaning of `Missing` data depends on the parameter, for instance:

-   `investment_limit`: There is no investment limit.

#### [`assets-profiles.csv`] (@id assets-profiles-definition)

These files contain information about assets and their associated profiles. Each row lists an asset, the type of profile (e.g., availability, demand, maximum or minimum storage level), and the profile's name.
These profiles are used in the [intra-temporal constraints](@ref concepts-summary).

#### [`flows-profiles.csv`](@id flows-profiles-definition)

This file contains information about flows and their representative period profiles for intra-temporal constraints. Each flow is defined as a pair of assets.

#### [`rep-periods-data.csv`](@id rep-periods-data)

Describes the [representative periods](@ref representative-periods) by their unique ID, the number of timesteps per representative period, and the resolution per timestep. Note that in the test files the resolution units are given as hours for understandability, but the resolution is technically unitless.

#### [`rep-periods-mapping.csv`](@id rep-periods-mapping)

Describes the periods of the [timeframe](@ref timeframe) that map into a [representative period](@ref representative-periods) and the weight of the representative periods that construct a period. Note that each weight is a decimal between 0 and 1, and that the sum of weights for a given period must also be between 0 and 1 (but do not have to sum to 1).

#### `profiles-rep-periods.csv`

Define all the profiles for the `rep-periods`.
The `profile_name` is a unique identifier, the `period` and `value` define the profile, and the `rep_period` field informs the representative period.

The profiles are linked to assets and flows in the files [`assets-profiles`](@ref assets-profiles-definition), [`assets-timeframe-profiles`](@ref assets-profiles-definition), and [`flows-profiles`](@ref flows-profiles-definition).

#### `assets-timeframe-profiles.csv`

Like the [`assets-profiles.csv`](@ref assets-profiles-definition), but for the [inter-temporal constraints](@ref concepts-summary).

#### `profiles-timeframe.csv` (optional)

Define all the profiles for the `timeframe`.
This is similar to the [`profiles-rep-periods.csv`](@ref) except that it doesn't have a `rep-period` field and if this is not passed, default values are used in the timeframe constraints.

#### [`assets-rep-periods-partitions.csv` (optional)](@id assets-rep-periods-partitions-definition)

Contains a description of the [partition](@ref Partition) for each asset with respect to representative periods.
If not specified, each asset will have the same time resolution as the representative period, which is hourly by default.

There are currently three ways to specify the desired resolution, indicated in the column `specification`.
The column `partition` serves to define the partitions in the specified style.

-   `specification = uniform`: Set the resolution to a uniform amount, i.e., a time block is made of `X` timesteps. The number `X` is defined in the column `partition`. The number of timesteps in the representative period must be divisible by `X`.
-   `specification = explicit`: Set the resolution according to a list of numbers separated by `;` on the `partition`. Each number in the list is the number of timesteps for that time block. For instance, `2;3;4` means that there are three time blocks, the first has 2 timesteps, the second has 3 timesteps, and the last has 4 timesteps. The sum of the list must be equal to the total number of timesteps in that representative period, as specified in `num_timesteps` of [`rep-periods-data.csv`](@ref rep-periods-data).
-   `specification = math`: Similar to explicit, but using `+` and `x` for simplification. The value of `partition` is a sequence of elements of the form `NxT` separated by `+`, indicating `N` time blocks of length `T`. For instance, `2x3+3x6` is 2 time blocks of 3 timesteps, followed by 3 time blocks of 6 timesteps, for a total of 24 timesteps in the representative period.

The table below shows various results for different formats for a representative period with 12 timesteps.

| Time Block            | :uniform | :explicit               | :math       |
| :-------------------- | :------- | :---------------------- | :---------- |
| 1:3, 4:6, 7:9, 10:12  | 3        | 3;3;3;3                 | 4x3         |
| 1:4, 5:8, 9:12        | 4        | 4;4;4                   | 3x4         |
| 1:1, 2:2, …, 12:12    | 1        | 1;1;1;1;1;1;1;1;1;1;1;1 | 12x1        |
| 1:3, 4:6, 7:10, 11:12 | NA       | 3;3;4;2                 | 2x3+1x4+1x2 |

Note: If an asset is not specified in this file, the balance equation will be written in the lowest resolution of both the incoming and outgoing flows to the asset.

#### [`flows-rep-periods-partitions.csv` (optional)](@id flow-rep-periods-partitions-definition)

The same as [`assets-rep-periods-partitions.csv`](@ref assets-rep-periods-partitions-definition), but for flows.

If a flow is not specified in this file, the flow time resolution will be for each timestep by default (e.g., hourly).

#### [`assets-timeframe-partitions.csv` (optional)](@id assets-timeframe-partitions)

The same as their [`assets-rep-periods-partitions.csv`](@ref assets-rep-periods-partitions-definition) counterpart, but for the periods in the [timeframe](@ref timeframe) of the model.

#### [Schemas](@id schemas)

```@eval
using Markdown, TulipaEnergyModel

Markdown.parse(
    join(["- **$filename**\n" *
        join(
            ["  - `$f: $t`" for (f, t) in schema],
            "\n",
        ) for (filename, schema) in TulipaEnergyModel.schema_per_file
    ] |> sort, "\n")
)
```

## Structures

The list of relevant structures used in this package are listed below:

### EnergyProblem

The `EnergyProblem` structure is a wrapper around various other relevant structures.
It hides the complexity behind the energy problem, making the usage more friendly, although more verbose.

#### Fields

-   `graph`: The [Graph](@ref) object that defines the geometry of the energy problem.
-   `representative_periods`: A vector of [Representative Periods](@ref representative-periods).
-   `constraints_partitions`: Dictionaries that connect pairs of asset and representative periods to [time partitions](@ref Partition) (vectors of time blocks).
-   `timeframe`: The number of periods in the `representative_periods`.
-   `dataframes`: A Dictionary of dataframes used to linearize the variables and constraints. These are used internally in the model only.
-   `model`: A JuMP.Model object representing the optimization model.
-   `solution`: A structure of the variable values (investments, flows, etc) in the solution.
-   `solved`: A boolean indicating whether the `model` has been solved or not.
-   `objective_value`: The objective value of the solved problem (Float64).
-   `termination_status`: The termination status of the optimization model.
-   `time_read_data`: Time taken (in seconds) for reading the data (Float64).
-   `time_create_model`: Time taken (in seconds) for creating the model (Float64).
-   `time_solve_model`: Time taken (in seconds) for solving the model (Float64).

#### Constructor

The `EnergyProblem` can also be constructed using the minimal constructor below.

-   `EnergyProblem(table_tree)`: Constructs a new `EnergyProblem` object with the given [`table_tree`](@ref TableTree) object. The `graph`, `representative_periods`, and `timeframe` are computed using `create_internal_structures`. The `constraints_partitions` field is computed from the `representative_periods`, and the other fields are initialized with default values.

See the [basic example tutorial](@ref basic-example) to see how these can be used.

### TableTree

To move and keep data, we use [DataFrames](https://dataframes.juliadata.org) and a tree-like structure to link to these structures.
Each field in this structure is a NamedTuple. Below, you will find its fields:

-   `static`: Stores the data that does not vary inside a year. Its fields are
    -   `assets`: Assets data.
    -   `flows`: Flows data.
-   `profiles`: Stores the profile data indexed by:
    -   `assets`: Dictionary with the reference to assets' profiles indexed by periods (`"rep-periods"` or `"timeframe"`).
    -   `flows`: Reference to flows' profiles for representative periods.
    -   `profiles`: Actual profile data. Dictionary of dictionary indexed by periods and then by the profile name.
-   `partitions`: Stores the partitions data indexed by:
    -   `assets`: Dictionary with the specification of the assets' partitions indexed by periods.
    -   `flows`: Specification of the flows' partitions for representative periods.
-   `periods`: Stores the periods data, indexed by:
    -   `rep_periods`: Representative periods.
    -   `timeframe`: Timeframe periods.

### Graph

The energy problem is defined using a graph.
Each vertex is an asset, and each edge is a flow.

We use [MetaGraphsNext.jl](https://github.com/JuliaGraphs/MetaGraphsNext.jl) to define the graph and its objects.
Using MetaGraphsNext we can define a graph with metadata, i.e., associate data with each asset and flow.
Furthermore, we can define the labels of each asset as keys to access the elements of the graph.
The assets in the graph are of type [GraphAssetData](@ref), and the flows are of type [GraphFlowData](@ref).

The graph can be created using the [`create_internal_structures`](@ref) function, or it can be accessed from an [EnergyProblem](@ref).

See how to use the graph in the [graph tutorial](@ref graph-tutorial).

### GraphAssetData

This structure holds all the information of a given asset.
These are stored inside the [Graph](@ref).
Given a graph `graph`, an asset `a` can be accessed through `graph[a]`.

### GraphFlowData

This structure holds all the information of a given flow.
These are stored inside the [Graph](@ref).
Given a graph `graph`, a flow from asset `u` to asset `v` can be accessed through `graph[u, v]`.

### Partition

A [representative period](@ref representative-periods) will be defined with a number of timesteps.
A partition is a division of these timesteps into [time blocks](@ref time-blocks) such that the time blocks are disjunct (not overlapping) and that all timesteps belong to some time block.
Some variables and constraints are defined over every time block in a partition.

For instance, for a representative period with 12 timesteps, all sets below are partitions:

-   $\{\{1, 2, 3\}, \{4, 5, 6\}, \{7, 8, 9\}, \{10, 11, 12\}\}$
-   $\{\{1, 2, 3, 4\}, \{5, 6, 7, 8\}, \{9, 10, 11, 12\}\}$
-   $\{\{1\}, \{2, 3\}, \{4\}, \{5, 6, 7, 8\}, \{9, 10, 11, 12\}\}$

### [Timeframe](@id timeframe)

The timeframe is the total period we want to analyze with the model. Usually this is a year, but it can be any length of time. A timeframe has two fields:

-   `num_periods`: The timeframe is defined by a certain number of periods. For instance, a year can be defined by 365 periods, each describing a day.
-   `map_periods_to_rp`: Indicates the periods of the timeframe that map into a [representative period](@ref representative-periods) and the weight of the representative period to construct that period.

### [Representative Periods](@id representative-periods)

The [timeframe](@ref timeframe) (e.g., a full year) is described by a selection of representative periods, for instance, days or weeks, that nicely summarize other similar periods. For example, we could model the year into 3 days, by clustering all days of the year into 3 representative days. Each one of these days is called a representative period. _TulipaEnergyModel.jl_ has the flexibility to consider representative periods of different lengths for the same timeframe (e.g., a year can be represented by a set of 4 days and 2 weeks). To obtain the representative periods, we recommend using [TulipaClustering](https://github.com/TulipaEnergy/TulipaClustering.jl).

A representative period has four fields:

-   `mapping`: Indicates the periods of the [timeframe](@ref timeframe) that map into a representative period and the weight of the representative period in them.
-   `weight`: Indicates how many representative periods are contained in the [timeframe](@ref timeframe); this is inferred automatically from `mapping`.
-   `timesteps`: The number of timesteps blocks in the representative period.
-   `resolution`: The duration in time of each timestep.

The number of timesteps and resolution work together to define the coarseness of the period.
Nothing is defined outside of these timesteps; for instance, if the representative period represents a day and you want to specify a variable or constraint with a coarseness of 30 minutes. You need to define the number of timesteps to 48 and the resolution to `0.5`.

### Solution

The solution object `energy_problem.solution` is a mutable struct with the following fields:

-   `assets_investment[a]`: The investment for each asset, indexed on the investable asset `a`.
-   `flows_investment[u, v]`: The investment for each flow, indexed on the investable flow `(u, v)`.
-   `storage_level_intra_rp[a, rp, timesteps_block]`: The storage level for the storage asset `a` within (intra) a representative period `rp` and a time block `timesteps_block`. The list of time blocks is defined by `constraints_partitions`, which was used to create the model.
-   `storage_level_inter_rp[a, periods_block]`: The storage level for the storage asset `a` between (inter) representative periods in the periods block `periods_block`.
-   `flow[(u, v), rp, timesteps_block]`: The flow value for a given flow `(u, v)` at a given representative period `rp`, and time block `timesteps_block`. The list of time blocks is defined by `graph[(u, v)].partitions[rp]`.
-   `objective_value`: A Float64 with the objective value at the solution.
-   `duals`: A Dictionary containing the dual variables of selected constraints.

Check the [tutorial](@ref solution-tutorial) for tips on manipulating the solution.

### [Time Blocks](@id time-blocks)

A time block is a range for which a variable or constraint is defined.
It is a range of numbers, i.e., all integer numbers inside an interval.
Time blocks are used for the periods in the [timeframe](@ref timeframe) and the timesteps in the [representative period](@ref representative-periods). Time blocks are disjunct (not overlapping), but do not have to be sequential.

## [Exploring infeasibility](@id infeasible)

If your model is infeasible, you can try exploring the infeasibility with [JuMP.compute_conflict!](https://jump.dev/JuMP.jl/stable/api/JuMP/#JuMP.compute_conflict!) and [JuMP.copy_conflict](https://jump.dev/JuMP.jl/stable/api/JuMP/#JuMP.copy_conflict).

> **Note:** Not all solvers support this functionality.

Use `energy_problem.model` for the model argument. For instance:

```julia
if energy_problem.termination_status == INFEASIBLE
 compute_conflict!(energy_problem.model)
 iis_model, reference_map = copy_conflict(energy_problem.model)
 print(iis_model)
end
```

## [Setup seasonal and non-seasonal storage](@id seasonal-setup)

Section [Storage Modeling](@ref storage-modeling) explains the main concepts for modeling seasonal and non-seasonal storage in _TulipaEnergyModel.jl_. To define if an asset is one type or the other then consider the following:

-   _Seasonal storage_: When the storage capacity of an asset is greater than the total length of representative periods, we recommend using the inter-temporal constraints. To apply these constraints, you must set the input parameter `is_seasonal` to `true` in the [`assets-data.csv`](@ref schemas).
-   _Non-seasonal storage_: When the storage capacity of an asset is lower than the total length of representative periods, we recommend using the intra-temporal constraints. To apply these constraints, you must set the input parameter `is_seasonal` to `false` in the [`assets-data.csv`](@ref schemas).

> **Note:**
> If the input data covers only one representative period for the entire year, for example, with 8760-hour timesteps, and you have a monthly hydropower plant, then you should set the `is_seasonal` parameter for that asset to `false`. This is because the length of the representative period is greater than the storage capacity of the storage asset.

## [Setup the energy storage investment method](@id storage-investment-setup)

Energy storage assets have a unique characteristic wherein the investment is not solely based on the capacity to charge and discharge, but also on the energy capacity. Some storage asset types have a fixed duration for a given capacity, which means that there is a predefined ratio between energy and power. For instance, a battery of 10MW/unit and 4h duration implies that the energy capacity is 40MWh. Conversely, other storage asset types don't have a fixed ratio between the investment of capacity and storage capacity. Therefore, the energy capacity can be optimized independently of the capacity investment, such as hydrogen storage in salt caverns. To define if an energy asset is one type or the other then consider the following parameter setting in the file [`assets-data.csv`](@ref schemas):

-   _Investment energy method_: To use this method, set the parameter `storage_method_energy` to `true`. In addition, it is necessary to define:

    -   `investment_cost_storage_energy`: To establish the cost of investing in the storage capacity (e.g., kEUR/MWh/unit).
    -   `investment_limit_storage_energy`: To define the potential of the energy capacity investment (e.g., MWh). `Missing` values mean that there is no limit.
    -   `capacity_storage_energy`: To define the energy per unit of storage capacity invested in (e.g., MWh/unit).
    -   `investment_integer_storage_energy`: To determine whether the investment variables of storage capacity are integers of continuous.

-   _Fixed energy-to-power ratio method_: To use this method, set the parameter `storage_method_energy` to `false`. In addition, it is necessary to define the parameter `energy_to_power_ratio` to establish the predefined duration of the storage asset or ratio between energy and power. Note that all the investment costs should be allocated in the parameter `investment_cost`.

For more details on the constraints that apply when selecting one method or the other, please visit the [`mathematical formulation`](@ref formulation) section.

## [Setup the energy storage asset to avoid charging and discharging simultaneously](@id storage-binary-method-setup)

Depending on the configuration of the energy storage assets, it may or may not be possible to charge and discharge them simultaneously. For instance, a single battery cannot charge and discharge at the same time, but some pumped hydro storage technologies have separate components for charging (pump) and discharging (turbine) that can function independently, allowing them to charge and discharge simultaneously. To account for these differences, the model provides users with three options for the `use_binary_storage_method` parameter in the [`assets-data.csv`](@ref schemas) file:

-   `binary`: the model adds a binary variable to prevent charging and discharging simultaneously.
-   `relaxed_binary`: the model adds a binary variable that allows values between 0 and 1, reducing the likelihood of charging and discharging simultaneously. This option uses a tighter set of constraints close to the convex hull of the full formulation, resulting in fewer instances of simultaneous charging and discharging in the results.

If no value is set in the parameter `use_binary_storage_method`, i.e., `missing` value, the storage asset can charge and discharge simultaneously.

For more details on the constraints that apply when selecting this method, please visit the [`mathematical formulation`](@ref formulation) section.
