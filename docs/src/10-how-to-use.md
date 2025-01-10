# [How to Use](@id how-to-use)

```@contents
Pages = ["10-how-to-use.md"]
Depth = 3
```

## Install

To use Tulipa, you first need to install the opensource [Julia](https://julialang.org) programming language.

Then consider installing a user-friendly code editor, such as [VSCode](https://code.visualstudio.com). Otherwise you will be running from the terminal/command prompt.

### Starting Julia

Choose one:

- In VSCode: Press CTRL+Shift+P and press Enter to start a Julia REPL.
- In the terminal: Type `julia` and press Enter

### Adding TulipaEnergyModel

In Julia:

- Enter package mode (press "]")

```julia-pkg
pkg> add TulipaEnergyModel
```

- Return to Julia mode (backspace)

```julia
julia> using TulipaEnergyModel
```

### (Optional) Running automatic tests

It is nice to check that tests are passing to make sure your environment is working. (This takes a minute or two.)

- Enter package mode (press "]")

```julia-pkg
pkg> test TulipaEnergyModel
```

All tests should pass.

## Running a Scenario

To run a scenario, use the function:

- [`run_scenario(connection)`](@ref)
- [`run_scenario(connection; output_folder)`](@ref)

The `connection` should have been created and the data loaded into it using [TulipaIO](https://github.com/TulipaEnergy/TulipaIO.jl).
See the [tutorials](@ref tutorials) for a complete guide on how to achieve this.
The `output_folder` is optional if the user wants to export the output.

## [Input](@id input)

Currently, we only accept input from [CSV files](@ref csv-files) that follow the [Schemas](@ref schemas).
You can also check the [`test/inputs` folder](https://github.com/TulipaEnergy/TulipaEnergyModel.jl/tree/main/test/inputs) for examples.

### [CSV Files](@id csv-files)

Below, we have a description of the files.
At the end, in [Schemas](@ref schemas), we have the expected columns in these CSVs.

> **Tip:**
> If you modify CSV files and want to see your modifications, the normal `git diff` command will not be informative.
> Instead, you can use
>
> ```bash
> git diff --word-diff-regex="[^[:space:],]+"
> ```
>
> to make `git` treat the `,` as word separators.
> You can also compare two CSV files with
>
> ```bash
> git diff --no-index --word-diff-regex="[^[:space:],]+" file1 file2
> ```

#### [`graph-assets-data.csv`](@id graph-assets-data)

This file contains the list of assets and the static data associated with each of them.

The meaning of `Missing` data depends on the parameter, for instance:

- `group`: No group assigned to the asset.

#### [`graph-flows-data.csv`](@id graph-flows-data)

The same as [`graph-assets-data.csv`](@ref graph-assets-data), but for flows. Each flow is defined as a pair of assets.

#### [`assets-data.csv`](@id assets-data)

This file contains the yearly data of each asset.

The investment parameters are as follows:

- The `investable` parameter determines whether there is an investment decision for the asset or flow.
- The `investment_integer` parameter determines if the investment decision is integer or continuous.
- The `investment_cost` parameter represents the cost in the defined [timeframe](@ref timeframe). Thus, if the timeframe is a year, the investment cost is the annualized cost of the asset.
- The `investment_limit` parameter limits the total investment capacity of the asset or flow. This limit represents the potential of that particular asset or flow. Without data in this parameter, the model assumes no investment limit.

The meaning of `Missing` data depends on the parameter, for instance:

- `investment_limit`: There is no investment limit.
- `initial_storage_level`: The initial storage level is free (between the storage level limits), meaning that the optimization problem decides the best starting point for the storage asset. In addition, the first and last time blocks in a representative period are linked to create continuity in the storage level.

#### [`flows-data.csv`](@id flows-data)

The same as [`assets-data.csv`](@ref assets-data), but for flows. Each flow is defined as a pair of assets.

The meaning of `Missing` data depends on the parameter, for instance:

- `investment_limit`: There is no investment limit.

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

#### `group-asset.csv` (optional)

This file contains the list of groups and the methods that apply to each group, along with their respective parameters.

#### `profiles-timeframe.csv` (optional)

Define all the profiles for the `timeframe`.
This is similar to the [`profiles-rep-periods.csv`](@ref) except that it doesn't have a `rep-period` field and if this is not passed, default values are used in the timeframe constraints.

#### [`assets-rep-periods-partitions.csv` (optional)](@id assets-rep-periods-partitions-definition)

Contains a description of the [partition](@ref Partition) for each asset with respect to representative periods.
If not specified, each asset will have the same time resolution as the representative period, which is hourly by default.

There are currently three ways to specify the desired resolution, indicated in the column `specification`.
The column `partition` serves to define the partitions in the specified style.

- `specification = uniform`: Set the resolution to a uniform amount, i.e., a time block is made of `X` timesteps. The number `X` is defined in the column `partition`. The number of timesteps in the representative period must be divisible by `X`.
- `specification = explicit`: Set the resolution according to a list of numbers separated by `;` on the `partition`. Each number in the list is the number of timesteps for that time block. For instance, `2;3;4` means that there are three time blocks, the first has 2 timesteps, the second has 3 timesteps, and the last has 4 timesteps. The sum of the list must be equal to the total number of timesteps in that representative period, as specified in `num_timesteps` of [`rep-periods-data.csv`](@ref rep-periods-data).
- `specification = math`: Similar to explicit, but using `+` and `x` for simplification. The value of `partition` is a sequence of elements of the form `NxT` separated by `+`, indicating `N` time blocks of length `T`. For instance, `2x3+3x6` is 2 time blocks of 3 timesteps, followed by 3 time blocks of 6 timesteps, for a total of 24 timesteps in the representative period.

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

### [Schemas](@id schemas)

```@eval
using Markdown, TulipaEnergyModel

Markdown.parse(
    join(["- **`$filename`**\n" *
        join(
            ["  - `$f: $t`" for (f, t) in schema],
            "\n",
        ) for (filename, schema) in TulipaEnergyModel.schema_per_table_name
    ] |> sort, "\n")
)
```

## [Structures](@id structures)

The list of relevant structures used in this package are listed below:

### EnergyProblem

The `EnergyProblem` structure is a wrapper around various other relevant structures.
It hides the complexity behind the energy problem, making the usage more friendly, although more verbose.

#### Fields

- `graph`: The [Graph](@ref) object that defines the geometry of the energy problem.
- `representative_periods`: A vector of [Representative Periods](@ref representative-periods).
- `constraints_partitions`: Dictionaries that connect pairs of asset and representative periods to [time partitions](@ref Partition) (vectors of time blocks).
- `timeframe`: The number of periods in the `representative_periods`.
- `dataframes`: A Dictionary of dataframes used to linearize the variables and constraints. These are used internally in the model only.
- `groups`: A vector of [Groups](@ref group).
- `model`: A JuMP.Model object representing the optimization model.
- `solution`: A structure of the variable values (investments, flows, etc) in the solution.
- `solved`: A boolean indicating whether the `model` has been solved or not.
- `objective_value`: The objective value of the solved problem (Float64).
- `termination_status`: The termination status of the optimization model.
- `time_read_data`: Time taken (in seconds) for reading the data (Float64).
- `time_create_model`: Time taken (in seconds) for creating the model (Float64).
- `time_solve_model`: Time taken (in seconds) for solving the model (Float64).

#### Constructor

The `EnergyProblem` can also be constructed using the minimal constructor below.

- `EnergyProblem(connection)`: Constructs a new `EnergyProblem` object with the given `connection` that has been created and the data loaded into it using [TulipaIO](https://github.com/TulipaEnergy/TulipaIO.jl). The `graph`, `representative_periods`, and `timeframe` are computed using `create_internal_structures`. The `constraints_partitions` field is computed from the `representative_periods`, and the other fields are initialized with default values.

See the [basic example tutorial](@ref basic-example) to see how these can be used.

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

- $\{\{1, 2, 3\}, \{4, 5, 6\}, \{7, 8, 9\}, \{10, 11, 12\}\}$
- $\{\{1, 2, 3, 4\}, \{5, 6, 7, 8\}, \{9, 10, 11, 12\}\}$
- $\{\{1\}, \{2, 3\}, \{4\}, \{5, 6, 7, 8\}, \{9, 10, 11, 12\}\}$

### [Timeframe](@id timeframe)

The timeframe is the total period we want to analyze with the model. Usually this is a year, but it can be any length of time. A timeframe has two fields:

- `num_periods`: The timeframe is defined by a certain number of periods. For instance, a year can be defined by 365 periods, each describing a day.
- `map_periods_to_rp`: Indicates the periods of the timeframe that map into a [representative period](@ref representative-periods) and the weight of the representative period to construct that period.

### [Representative Periods](@id representative-periods)

The [timeframe](@ref timeframe) (e.g., a full year) is described by a selection of representative periods, for instance, days or weeks, that nicely summarize other similar periods. For example, we could model the year into 3 days, by clustering all days of the year into 3 representative days. Each one of these days is called a representative period. _TulipaEnergyModel.jl_ has the flexibility to consider representative periods of different lengths for the same timeframe (e.g., a year can be represented by a set of 4 days and 2 weeks). To obtain the representative periods, we recommend using [TulipaClustering](https://github.com/TulipaEnergy/TulipaClustering.jl).

A representative period has three fields:

- `weight`: Indicates how many representative periods are contained in the [timeframe](@ref timeframe); this is inferred automatically from `map_periods_to_rp` in the [timeframe](@ref timeframe).
- `timesteps`: The number of timesteps blocks in the representative period.
- `resolution`: The duration in time of each timestep.

The number of timesteps and resolution work together to define the coarseness of the period.
Nothing is defined outside of these timesteps; for instance, if the representative period represents a day and you want to specify a variable or constraint with a coarseness of 30 minutes. You need to define the number of timesteps to 48 and the resolution to `0.5`.

### Solution

The solution object `energy_problem.solution` is a mutable struct with the following fields:

- `assets_investment[a]`: The investment for each asset, indexed on the investable asset `a`.
- `flows_investment[u, v]`: The investment for each flow, indexed on the investable flow `(u, v)`.
- `storage_level_rep_period[a, rp, timesteps_block]`: The storage level for the storage asset `a` within (intra) a representative period `rp` and a time block `timesteps_block`. The list of time blocks is defined by `constraints_partitions`, which was used to create the model.
- `storage_level_over_clustered_year[a, periods_block]`: The storage level for the storage asset `a` between (inter) representative periods in the periods block `periods_block`.
- `flow[(u, v), rp, timesteps_block]`: The flow value for a given flow `(u, v)` at a given representative period `rp`, and time block `timesteps_block`. The list of time blocks is defined by `graph[(u, v)].partitions[rp]`.
- `objective_value`: A Float64 with the objective value at the solution.
- `duals`: A Dictionary containing the dual variables of selected constraints.

Check the [tutorial](@ref solution-tutorial) for tips on manipulating the solution.

### [Time Blocks](@id time-blocks)

A time block is a range for which a variable or constraint is defined.
It is a range of numbers, i.e., all integer numbers inside an interval.
Time blocks are used for the periods in the [timeframe](@ref timeframe) and the timesteps in the [representative period](@ref representative-periods). Time blocks are disjunct (not overlapping), but do not have to be sequential.

### [Group](@id group)

This structure holds all the information of a given group with the following fields:

- `name`: The name of the group.
- `invest_method`: Boolean value to indicate whether or not the group has an investment method.
- `min_investment_limit`: A minimum investment limit in MW is imposed on the total investments of the assets belonging to the group.
- `max_investment_limit`: A maximum investment limit in MW is imposed on the total investments of the assets belonging to the group.

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

## [Speed improvements in the model creation](@id need-for-speed)

If you want to speed-up model creation, consider disabling the naming of variables and constraints. Of course, removing the names will make debugging difficult (or impossible) - so enable/disable naming as needed for your analysis.

```julia
# Disable names while using run_scenario
run_scenario(connection; enable_names = false)

# OR while using create_model!
create_model!(energy_problem; enable_names = false)
```

For more information, see the [JuMP documentation](https://jump.dev/JuMP.jl/stable/tutorials/getting_started/performance_tips/#Disable-string-names).

## Storage specific setups

### [Seasonal and non-seasonal storage](@id seasonal-setup)

Section [Storage Modeling](@ref storage-modeling) explains the main concepts for modeling seasonal and non-seasonal storage in _TulipaEnergyModel.jl_. To define if an asset is one type or the other then consider the following:

- _Seasonal storage_: When the storage capacity of an asset is greater than the total length of representative periods, we recommend using the inter-temporal constraints. To apply these constraints, you must set the input parameter `is_seasonal` to `true` in the [`assets-data.csv`](@ref schemas).
- _Non-seasonal storage_: When the storage capacity of an asset is lower than the total length of representative periods, we recommend using the intra-temporal constraints. To apply these constraints, you must set the input parameter `is_seasonal` to `false` in the [`assets-data.csv`](@ref schemas).

> **Note:**
> If the input data covers only one representative period for the entire year, for example, with 8760-hour timesteps, and you have a monthly hydropower plant, then you should set the `is_seasonal` parameter for that asset to `false`. This is because the length of the representative period is greater than the storage capacity of the storage asset.

### [The energy storage investment method](@id storage-investment-setup)

Energy storage assets have a unique characteristic wherein the investment is based not solely on the capacity to charge and discharge, but also on the energy capacity. Some storage asset types have a fixed duration for a given capacity, which means that there is a predefined ratio between energy and power. For instance, a battery of 10MW/unit and 4h duration implies that the energy capacity is 40MWh. Conversely, other storage asset types don't have a fixed ratio between the investment of capacity and storage capacity. Therefore, the energy capacity can be optimized independently of the capacity investment, such as hydrogen storage in salt caverns. To define if an energy asset is one type or the other then consider the following parameter setting in the file [`assets-data.csv`](@ref schemas):

- _Investment energy method_: To use this method, set the parameter `storage_method_energy` to `true`. In addition, it is necessary to define:

  - `investment_cost_storage_energy`: To establish the cost of investing in the storage capacity (e.g., kEUR/MWh/unit).
  - `fixed_cost_storage_energy`: To establish the fixed cost of energy storage capacity (e.g., kEUR/MWh/unit).
  - `investment_limit_storage_energy`: To define the potential of the energy capacity investment (e.g., MWh). `Missing` values mean that there is no limit.
  - `investment_integer_storage_energy`: To determine whether the investment variables of storage capacity are integers of continuous.

- _Fixed energy-to-power ratio method_: To use this method, set the parameter `storage_method_energy` to `false`. In addition, it is necessary to define the parameter `energy_to_power_ratio` to establish the predefined duration of the storage asset or ratio between energy and power. Note that all the investment costs should be allocated in the parameter `investment_cost`.

In addition, the parameter `capacity_storage_energy` in the [`graph-assets-data.csv`](@ref schemas) defines the energy per unit of storage capacity invested in (e.g., MWh/unit).

For more details on the constraints that apply when selecting one method or the other, please visit the [`mathematical formulation`](@ref formulation) section.

### [Control simultaneous charging and discharging](@id storage-binary-method-setup)

Depending on the configuration of the energy storage assets, it may or may not be possible to charge and discharge them simultaneously. For instance, a single battery cannot charge and discharge at the same time, but some pumped hydro storage technologies have separate components for charging (pump) and discharging (turbine) that can function independently, allowing them to charge and discharge simultaneously. To account for these differences, the model provides users with three options for the `use_binary_storage_method` parameter in the [`assets-data.csv`](@ref schemas) file:

- `binary`: the model adds a binary variable to prevent charging and discharging simultaneously.
- `relaxed_binary`: the model adds a binary variable that allows values between 0 and 1, reducing the likelihood of charging and discharging simultaneously. This option uses a tighter set of constraints close to the convex hull of the full formulation, resulting in fewer instances of simultaneous charging and discharging in the results.
- If no value is set, i.e., `missing` value, the storage asset can charge and discharge simultaneously.

For more details on the constraints that apply when selecting this method, please visit the [`mathematical formulation`](@ref formulation) section.

## [Setting up unit commitment constraints](@id unit-commitment-setup)

The unit commitment constraints are only applied to producer and conversion assets. The `unit_commitment` parameter must be set to `true` to include the constraints in the [`assets-data.csv`](@ref schemas). Additionally, the following parameters should be set in that same file:

- `unit_commitment_method`: It determines which unit commitment method to use. The current version of the code only includes the basic version. Future versions will add more detailed constraints as additional options.
- `units_on_cost`: Objective function coefficient on `units_on` variable. (e.g., no-load cost or idling cost in kEUR/h/unit)
- `unit_commitment_integer`: It determines whether the unit commitment variables are considered as integer or not (`true` or `false`)
- `min_operating_point`: Minimum operating point or minimum stable generation level defined as a portion of the capacity of asset (p.u.)

For more details on the constraints that apply when selecting this method, please visit the [`mathematical formulation`](@ref formulation) section.

## [Setting up ramping constraints](@id ramping-setup)

The ramping constraints are only applied to producer and conversion assets. The `ramping` parameter must be set to `true` to include the constraints in the [`assets-data.csv`](@ref schemas). Additionally, the following parameters should be set in that same file:

- `max_ramp_up`: Maximum ramping up rate as a portion of the capacity of asset (p.u./h)
- `max_ramp_down:`Maximum ramping down rate as a portion of the capacity of asset (p.u./h)

For more details on the constraints that apply when selecting this method, please visit the [`mathematical formulation`](@ref formulation) section.

## [Setting up a maximum or minimum outgoing energy limit](@id max-min-outgoing-energy-setup)

For the model to add constraints for a [maximum or minimum energy limit](@ref inter-temporal-energy-constraints) for an asset throughout the model's timeframe (e.g., a year), we need to establish a couple of parameters:

- `is_seasonal = true` in the [`assets-data.csv`](@ref schemas). This parameter enables the model to use the inter-temporal constraints.
- `max_energy_timeframe_partition` $\neq$ `missing` or `min_energy_timeframe_partition` $\neq$ `missing` in the [`assets-data.csv`](@ref schemas). This value represents the peak energy that will be then multiplied by the profile for each period in the timeframe.
  > **Note:**
  > These parameters are defined per period, and the default values for profiles are 1.0 p.u. per period. If the periods are determined daily, the energy limit for the whole year will be 365 times `max`or `min_energy_timeframe_partition`.
- (optional) `profile_type` and `profile_name` in the [`assets-timeframe-profiles.csv`](@ref schemas) and the profile values in the [`profiles-timeframe.csv`](@ref schemas). If there is no profile defined, then by default it is 1.0 p.u. for all periods in the timeframe.
- (optional) define a period partition in [`assets-timeframe-partitions.csv`](@ref schemas). If there is no partition defined, then by default the constraint is created for each period in the timeframe, otherwise, it will consider the partition definition in the file.

> **Tip:**
> If you want to set a limit on the maximum or minimum outgoing energy for a year with representative days, you can use the partition definition to create a single partition for the entire year to combine the profile.

### Example: Setting Energy Limits

Let's assume we have a year divided into 365 days because we are using days as periods in the representatives from [_TulipaClustering.jl_](https://github.com/TulipaEnergy/TulipaClustering.jl). Also, we define the `max_energy_timeframe_partition = 10 MWh`, meaning the peak energy we want to have is 10MWh for each period or period partition. So depending on the optional information, we can have:

| Profile | Period Partitions | Example                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| ------- | ----------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| None    | None              | The default profile is 1.p.u. for each period and since there are no period partitions, the constraints will be for each period (i.e., daily). So the outgoing energy of the asset for each day must be less than or equal to 10MWh.                                                                                                                                                                                                                                                                                                                                                                                                    |
| Defined | None              | The profile definition and value will be in the [`assets-timeframe-profiles.csv`](@ref schemas) and [`profiles-timeframe.csv`](@ref schemas) files. For example, we define a profile that has the following first four values: 0.6 p.u., 1.0 p.u., 0.8 p.u., and 0.4 p.u. There are no period partitions, so constraints will be for each period (i.e., daily). Therefore the outgoing energy of the asset for the first four days must be less than or equal to 6MWh, 10MWh, 8MWh, and 4MWh.                                                                                                                                           |
| Defined | Defined           | Using the same profile as above, we now define a period partition in the [`assets-timeframe-partitions.csv`](@ref schemas) file as `uniform` with a value of 2. This value means that we will aggregate every two periods (i.e., every two days). So, instead of having 365 constraints, we will have 183 constraints (182 every two days and one last constraint of 1 day). Then the profile is aggregated with the sum of the values inside the periods within the partition. Thus, the outgoing energy of the asset for the first two partitions (i.e., every two days) must be less than or equal to 16MWh and 12MWh, respectively. |

## [Defining a group of assets](@id group-setup)

A group of assets refers to a set of assets that share certain constraints. For example, the investments of a group of assets may be capped at a maximum value, which represents the potential of a specific area that is restricted in terms of the maximum allowable MW due to limitations on building licenses.

In order to define the groups in the model, the following steps are necessary:

1. Create a group in the [`group-asset.csv`](@ref schemas) file by defining the `name` property and its parameters.
2. In the file [`graph-assets-data.csv`](@ref schemas), assign assets to the group by setting the `name` in the `group` parameter/column.

   > **Note:**
   > A missing value in the parameter `group` in the [`graph-assets-data.csv`](@ref schemas) means that the asset does not belong to any group.

Groups are useful to represent several common constraints, the following group constraints are available.

### [Setting up a maximum or minimum investment limit for a group](@id investment-group-setup)

The mathematical formulation of the maximum and minimum investment limit for group constraints is available [here](@ref investment-group-constraints). The parameters to set up these constraints in the model are in the [`group-asset.csv`](@ref schemas) file.

- `invest_method = true`. This parameter enables the model to use the investment group constraints.
- `min_investment_limit` $\neq$ `missing` or `max_investment_limit` $\neq$ `missing`. This value represents the limits that will be imposed on the investment that belongs to the group.

  > **Notes:**
  >
  > 1. A missing value in the parameters `min_investment_limit` and `max_investment_limit` means that there is no investment limit.
  > 2. These constraints are applied to the investments each year. The model does not yet have investment limits to a group's accumulated invested capacity.

### Example: Group of Assets

Let's explore how the groups are set up in the test case called [Norse](https://github.com/TulipaEnergy/TulipaEnergyModel.jl/tree/main/test/inputs/Norse). First, let's take a look at the group-asset.csv file:

```@example display-group-setup
using DataFrames # hide
using CSV # hide
input_asset_file = "../../test/inputs/Norse/group-asset.csv" # hide
assets = CSV.read(input_asset_file, DataFrame, header = 1) # hide
```

In the given data, there are two groups: `renewables` and `ccgt`. Both groups have the `invest_method` parameter set to `true`, indicating that investment group constraints apply to both. For the `renewables` group, the `min_investment_limit` parameter is missing, signifying that there is no minimum limit imposed on the group. However, the `max_investment_limit` parameter is set to 40000 MW, indicating that the total investments of assets in the group must be less than or equal to this value. In contrast, the `ccgt` group has a missing value in the `max_investment_limit` parameter, indicating no maximum limit, while the `min_investment_limit` is set to 10000 MW for the total investments in that group.

Let's now explore which assets are in each group. To do so, we can take a look at the graph-assets-data.csv file:

```@example display-group-setup
input_asset_file = "../../test/inputs/Norse/graph-assets-data.csv" # hide
assets = CSV.read(input_asset_file, DataFrame, header = 1) # hide
assets = assets[.!ismissing.(assets.group), [:name, :type, :group]] # hide
```

Here we can see that the assets `Asgard_Solar` and `Midgard_Wind` belong to the `renewables` group, while the assets `Asgard_CCGT` and `Midgard_CCGT` belong to the `ccgt` group.

> **Note:**
> If the group has a `min_investment_limit`, then assets in the group have to allow investment (`investable = true`) for the model to be feasible. If the assets are not `investable` then they cannot satisfy the minimum constraint.

## [Setting up multi-year investments](@id multi-year-setup)

It is possible to simutaneously model different years, which is especially relevant for modeling multi-year investments. Multi-year investments refer to making investment decisions at different points in time, such that a pathway of investments can be modeled. This is particularly useful when long-term scenarios are modeled, but modeling each year is not practical. Or in a business case, investment decisions are supposed to be made in different years which has an impact on the cash flow.

In order to set up a model with year information, the following steps are necessary.

- Fill in all the years in [`year-data.csv`](@ref schemas) file by defining the `year` property and its parameters.

  Differentiate milestone years and non-milestone years.

  - Milestone years are the years you would like to model, e.g., if you want to model operation and/or investments (it is possibile to not allow investments) in 2030, 2040, and 2050. These 3 years are then milestone years.
  - Non-milestone years are the investment years of existing units. For example, you want to consider a existing wind unit that is invested in 2020, then 2020 is a non-milestone year.
    > **Note:** A year can both be a year that you want to model and that there are existing units invested, then this year is a milestone year.

- Fill in the parameters in [`vintage-assets-data.csv`](@ref schemas) and [`vintage-flows-data.csv`](@ref schemas). Here you need to fill in parameters that are only related to the investment year (`commission_year` in the data) of the asset, i.e., investment costs and fixed costs.

- Fill in the parameters in [`graph-assets-data.csv`](@ref schemas) and [`graph-flows-data.csv`](@ref schemas). These parameters are for the assets across all the years, i.e., not dependent on years. Examples are lifetime (both `technical_lifetime` and `economic_lifetime`) and capacity of a unit.

  You also have to choose a `investment_method` for the asset, between `none`, `simple`, and `compact`. The below tables shows what happens to the activation of the investment and decommission variable for certain investment methods and the `investable` parameter.

  Consider you only want to model operation without investments, then you would need to set `investable_method` to `none`. Neither investment variables and decommission variables are activated. And here the `investable_method` overrules `investable`, because the latter does not matter.

  > **Note:** Although it is called `investment_method`, you can see from the table that, actually, it controls directly the activation of the decommission variable. The investment variable is controlled by `investable`, which is overruled by `investable_method` in case of a conflict (i.e., for the `none` method).

  | investment_method | investable | investment variable | decommission variable |
  | ----------------- | ---------- | ------------------- | --------------------- |
  | none              | true       | false               | false                 |
  | none              | false      | false               | false                 |
  | simple            | true       | true                | true                  |
  | simple            | false      | false               | true                  |
  | compact           | true       | true                | true                  |
  | compact           | false      | false               | true                  |

  For more details on the constraints that apply when selecting these methods, please visit the [`mathematical formulation`](@ref formulation) section.

  > **Note:** `compact` method can only be applied to producer assets and conversion assets. Transport assets and storage assets can only use `simple` method.

  - Fill in the assets and flows information in [`assets-data.csv`](@ref schemas) and [`flows-data.csv`](@ref schemas).

    - In the `year` column, fill in all the milestone years. In the `commission_year` column, fill in the investment years of the existing assets that are still available in this `year`.
      - If the `commission_year` is a non-milestone year, then it means the row is for an existing unit. The `investable` has to be set to `false`, and you put the existing units in the column `initial_units`.
      - If the `commission_year` is a milestone year, then you put the existing units in the column `initial_units`. Depending on whether you want to model investments or not, you put the `investable` to either `true` or `false`.

    Let's explain further using an example. To do so, we can take a look at the assets-data.csv file:

    ```@example multi-year-setup
    using DataFrames # hide
    using CSV # hide
    input_asset_file = "../../test/inputs/Multi-year Investments/assets-data.csv" # hide
    assets_data = CSV.read(input_asset_file, DataFrame, header = 1) # hide
    assets_data = assets_data[1:10, [:name, :year, :commission_year, :investable, :initial_units]] # hide
    ```

    We allow investments of `ocgt`, `ccgt`, `battery`, `wind`, and `solar` in 2030.

    - `ocgt` has no existing units.
    - `ccgt` has 1 existing units, invested in 2028, and still available in 2030.
    - `ccgt` has 0.07 existing units, invested in 2020, and still available in 2030. Another 0.02 existing units, invested in 2030.
    - `wind` has 0.07 existing units, invested in 2020, and still available in 2030. Another 0.02 existing units, invested in 2030.
    - `solar` has no existing units.

    > **Note:** We only consider the existing units which are still available in the milestone years.

- Fill in relevant profiles in [`assets-profiles.csv`](@ref schemas), [`flows-profiles.csv`](@ref schemas), and [`profiles-rep-periods.csv`](@ref schemas). Important to know that you can use different profiles for assets that are invested in different years. You fill in the profile names in `assets-profiles.csv` for relevant years. In `profiles-rep-periods.csv`, you relate the profile names with the modeled years.

  Let's explain further using an example. To do so, we can take a look at the `assets-profiles.csv` file:

  ```@example multi-year-setup
  input_asset_file = "../../test/inputs/Multi-year Investments/assets-profiles.csv" # hide
  assets_profiles = CSV.read(input_asset_file, DataFrame, header = 1) # hide
  assets_profiles = assets_profiles[1:2, :] # hide
  ```

  We have two profiles for `wind` invested in 2020 and 2030. Imagine these are two wind turbines with different efficiencies due to the year of manufacture. These are reflected in the profiles for the model year 2030, which are defined in the `profiles-rep-periods.csv` file.

  ### Economic representation

  For economic representation, the following parameters need to be set up:

  - [optional] `discount year` and `discount rate` in the `model-parameters-example.toml` file: model-wide discount year and rate. By default, the model will use a discount rate of 0, and a discount year of the first milestone year. In other words, the costs will be discounted to the cost of the first milestone year.

  - `discount_rate` in [`graph-assets-data.csv`](@ref schemas) and [`graph-flows-data.csv`](@ref schemas): technology-specific discount rates.

  - `economic_lifetime` in [`graph-assets-data.csv`](@ref schemas) and [`graph-flows-data.csv`](@ref schemas): used for discounting the costs.

  > **Note:** Since the model explicitly discounts, all the inputs for costs should be given in the costs of the relevant year. For example, to model investments in 2030 and 2050, the `investment_cost` should be given in 2030 costs and 2050 costs, respectively.

  For more details on the formulas for economic representation, please visit the [`mathematical formulation`](@ref formulation) section.
