# [How to Use](@id how-to-use)

```@contents
Pages = ["20-how-to-use.md"]
Depth = [2, 3]
```

This section assumes users have already followed the [Beginner Tutorials](@ref tutorials) and are looking for specific instructions for certain features.

## Running automatic tests

To run the automatic tests on your installation of TulipaEnergyModel:

- Enter package mode (press "]")

```julia-pkg
pkg> test TulipaEnergyModel
# This takes a minute or two...
```

All tests should pass.
(If you have an error in your analysis, it is probably not caused by TulipaEnergyModel.)

!!! warning "Admin rights on your local machine"
    Ensure you have admin rights on the folder where the package is installed; otherwise, an error will appear during the tests.

## Finding an input parameter

!!! tip "Are you looking for an input parameter?"
    Please visit the [Model Parameters](@ref schemas) section for a description and location of all model input parameters.

## Running a Scenario

To run a scenario, use the function:

- [`run_scenario(connection)`](@ref)
- [`run_scenario(connection; output_folder)`](@ref)

The `connection` should have been created and the data loaded into it using [TulipaIO](https://github.com/TulipaEnergy/TulipaIO.jl).
See the [tutorials](@ref tutorials) for a complete guide on how to achieve this.
The `output_folder` is optional if the user wants to export the output.

### [Input](@id input)

Currently, we only accept input from CSV files that follow the [Schemas](@ref schemas).

You can also check the [`test/inputs` folder](https://github.com/TulipaEnergy/TulipaEnergyModel.jl/tree/main/test/inputs) for examples of different predefined energy systems and features. Moreover, Tulipa's Offshore Bidding Zone Case Study can be found in <https://github.com/TulipaEnergy/Tulipa-OBZ-CaseStudy>. It shows how to start from user-friendly files and transform the data into the input files in the [Schemas](@ref schemas) through different functions.

### Writing the output to CSV

To save the solution to CSV files, you can use [`export_solution_to_csv_files`](@ref). See the [tutorials](@ref tutorials) for an example showcasing this function.

## Changing the solver (optimizer) and specifying parameters

By default, the model is solved using the [HiGHS](https://github.com/jump-dev/HiGHS.jl) optimizer (or solver).
To change this, you can give the functions [`run_scenario`](@ref) or [`create_model!`](@ref) a different optimizer.

!!! warning
    HiGHS is the only open source solver that we recommend. GLPK and Cbc are not (fully) tested for Tulipa.

Here is an example running the Tiny case using the [GLPK](https://github.com/jump-dev/GLPK.jl) optimizer:

```julia
using DuckDB, TulipaIO, TulipaEnergyModel, GLPK

input_dir = "../../test/inputs/Tiny" # you path will be different
connection = DBInterface.connect(DuckDB.DB)
read_csv_folder(connection, input_dir; schemas = TulipaEnergyModel.schema_per_table_name)
energy_problem = run_scenario(connection; optimizer = GLPK.Optimizer)
#OR create_model!(energy_problem; optimizer = GLPK.Optimizer)
```

!!! info
    Notice that you need to add the GLPK package and run `using GLPK` before running `GLPK.Optimizer`.

In both cases above, the `GLPK` optimizer uses its default parameters, which you can query using [`default_parameters`](@ref).
To change any optimizer parameters, you can pass a dictionary to the `optimizer_parameters` keyword argument.
The example below changes the maximum allowed runtime for GLPK to 1 second, which will probably cause it to fail to converge in time.

```julia
# change the optimizer parameters
parameter_dict = Dict("tm_lim" => 1) # list optimizer parameters as comma-separated parameter=>value pairs
energy_problem = run_scenario(connection; optimizer = GLPK.Optimizer, optimizer_parameters = parameter_dict)
#OR create_model!(energy_problem; optimizer = GLPK.Optimizer, optimizer_parameters = parameter_dict)
energy_problem.termination_status
```

If `direct_model = false` you can change the optimizer and parameters after creating the model (but before solving it) using the JuMP commands demonstrated below.
For more information on `direct_model`, see [Speed improvements in the model creation](@ref need-for-speed).

```julia @example change-optimizer
# create the model and solve with the default optimizer and optimizer parameters
energy_problem = EnergyProblem(connection)
create_model!(energy_problem)
solve_model(energy_problem)

# change the solver and parameters and resolve:
parameter_dict = Dict("tm_lim" => 1) # list optimizer parameters as comma-separated parameter=>value pairs

JuMP.set_optimizer(energy_problem.model, GLPK.Optimizer) # change the optimizer
for (k, v) in optimizer_parameters
    JuMP.set_attribute(energy_problem.model, k, v) # change the optimizer_parameters
end

solve_model(energy_problem) # solve the model with new optimizer & optimizer_parameters
```

For the complete list of parameters, check your chosen optimizer.

You can also pass these parameters via a file using the [`read_parameters_from_file`](@ref) function.

## [Exploring infeasibility](@id infeasible)

If your model is infeasible, you can try exploring the infeasibility with [JuMP.compute_conflict!](https://jump.dev/JuMP.jl/stable/api/JuMP/#JuMP.compute_conflict!) and [JuMP.copy_conflict](https://jump.dev/JuMP.jl/stable/api/JuMP/#JuMP.copy_conflict).

!!! warning "Check your solver options!"
    Not all solvers support this functionality; please check your specific solver.

Use `energy_problem.model` for the model argument. For instance:

```julia
if energy_problem.termination_status == INFEASIBLE
  compute_conflict!(energy_problem.model)
  iis_model, reference_map = copy_conflict(energy_problem.model)
  print(iis_model)
end
```

## [Speed improvements in the model creation](@id need-for-speed)

### Disable names of variables and constraints

If you want to speed-up model creation, consider disabling the naming of variables and constraints. Of course, removing the names will make debugging difficult (or impossible) - so enable/disable naming as needed for your analysis.

```julia
# Disable names while using run_scenario
run_scenario(connection; enable_names = false)

# OR while using create_model!
create_model!(energy_problem; enable_names = false)
```

For more information, see the JuMP documentation for [Disable string names](https://jump.dev/JuMP.jl/stable/tutorials/getting_started/performance_tips/#Disable-string-names).

### Create a direct model

If you want to reduce memory usage, consider using `direct_model = true`. This restricts certain actions after model creation, such as changing the optimizer.

```julia
# Create direct model with run_scenario
run_scenario(connection; direct_model = true)

# OR while using create_model!
create_model!(energy_problem; direct_model = true)
```

For more information, see the JuMP documentation for [`direct_model`](https://jump.dev/JuMP.jl/stable/api/JuMP/#direct_model).

## Storage specific setups

### [Seasonal and non-seasonal storage](@id seasonal-setup)

Section [Storage Modeling](@ref storage-modeling) explains the main concepts for modeling seasonal and non-seasonal storage in _TulipaEnergyModel.jl_. To define if an asset is one type or the other then consider the following:

- _Seasonal storage_: When the storage capacity of an asset is greater than the total length of representative periods, we recommend using the over-clustered-year constraints. To apply these constraints, you must set the input parameter `is_seasonal` to `true`.
- _Non-seasonal storage_: When the storage capacity of an asset is lower than the total length of representative periods, we recommend using the rep-period constraints. To apply these constraints, you must set the input parameter `is_seasonal` to `false`.

!!! info
    If the input data covers only one representative period for the entire year, for example, with 8760-hour timesteps, and you have a monthly hydropower plant, then you should set the `is_seasonal` parameter for that asset to `false`. This is because the length of the representative period is greater than the storage capacity of the storage asset.

### [The energy storage investment method](@id storage-investment-setup)

Energy storage assets have a unique characteristic wherein the investment is based not solely on the capacity to charge and discharge, but also on the energy capacity. Some storage asset types have a fixed duration for a given capacity, which means that there is a predefined ratio between energy and power. For instance, a battery of 10MW/unit and 4h duration implies that the energy capacity is 40MWh. Conversely, other storage asset types don't have a fixed ratio between the investment of capacity and storage capacity. Therefore, the energy capacity can be optimized independently of the capacity investment, such as hydrogen storage in salt caverns. To define if an energy asset is one type or the other then consider the following parameters:

- _Investment energy method_: To use this method, set the parameter `storage_method_energy` to `true`. In addition, it is necessary to define:

  - `investment_cost_storage_energy`: To establish the cost of investing in the storage capacity (e.g., kEUR/MWh/unit).
  - `fixed_cost_storage_energy`: To establish the fixed cost of energy storage capacity (e.g., kEUR/MWh/unit).
  - `investment_limit_storage_energy`: To define the potential of the energy capacity investment (e.g., MWh). `Missing` values mean that there is no limit.
  - `investment_integer_storage_energy`: To determine whether the investment variables of storage capacity are integers of continuous.

- _Fixed energy-to-power ratio method_: To use this method, set the parameter `storage_method_energy` to `false`. In addition, it is necessary to define the parameter `energy_to_power_ratio` to establish the predefined duration of the storage asset or ratio between energy and power. Note that all the investment costs should be allocated in the parameter `investment_cost`.

In addition, the parameter `capacity_storage_energy` defines the energy per unit of storage capacity invested in (e.g., MWh/unit).

For more details on the constraints that apply when selecting one method or the other, please visit the [`mathematical formulation`](@ref formulation) section.

### [Control simultaneous charging and discharging](@id storage-binary-method-setup)

Depending on the configuration of the energy storage assets, it may or may not be possible to charge and discharge them simultaneously. For instance, a single battery cannot charge and discharge at the same time, but some pumped hydro storage technologies have separate components for charging (pump) and discharging (turbine) that can function independently, allowing them to charge and discharge simultaneously. To account for these differences, the model provides users with three options for the `use_binary_storage_method` parameter:

- `binary`: the model adds a binary variable to prevent charging and discharging simultaneously.
- `relaxed_binary`: the model adds a binary variable that allows values between 0 and 1, reducing the likelihood of charging and discharging simultaneously. This option uses a tighter set of constraints close to the convex hull of the full formulation, resulting in fewer instances of simultaneous charging and discharging in the results.
- If no value is set, i.e., `missing` value, the storage asset can charge and discharge simultaneously.

For more details on the constraints that apply when selecting this method, please visit the [`mathematical formulation`](@ref formulation) section.

## [Setting up unit commitment constraints](@id unit-commitment-setup)

The unit commitment constraints are only applied to producer and conversion assets. The `unit_commitment` parameter must be set to `true` to include the constraints. Additionally, the following parameters should be set in that same file:

- `unit_commitment_method`: It determines which unit commitment method to use. The current version of the code only includes the basic version. Future versions will add more detailed constraints as additional options.
- `units_on_cost`: Objective function coefficient on `units_on` variable. (e.g., no-load cost or idling cost in kEUR/h/unit)
- `unit_commitment_integer`: It determines whether the unit commitment variables are considered as integer or not (`true` or `false`)
- `min_operating_point`: Minimum operating point or minimum stable generation level defined as a portion of the capacity of asset (p.u.)

For more details on the constraints that apply when selecting this method, please visit the [`mathematical formulation`](@ref formulation) section.

## [Setting up ramping constraints](@id ramping-setup)

The ramping constraints are only applied to producer and conversion assets. The `ramping` parameter must be set to `true` to include the constraints. Additionally, the following parameters should be set in that same file:

- `max_ramp_up`: Maximum ramping up rate as a portion of the capacity of asset (p.u./h)
- `max_ramp_down:`Maximum ramping down rate as a portion of the capacity of asset (p.u./h)

For more details on the constraints that apply when selecting this method, please visit the [`mathematical formulation`](@ref formulation) section.

## [Setting up a maximum or minimum outgoing energy limit](@id max-min-outgoing-energy-setup)

For the model to add constraints for a [maximum or minimum energy limit](@ref over-clustered-year-energy-constraints) for an asset throughout the model's timeframe (e.g., a year), we need to establish a couple of parameters:

- `is_seasonal = true`. This parameter enables the model to use the over-clustered-year constraints.
- `max_energy_timeframe_partition` $\neq$ `missing` or `min_energy_timeframe_partition` $\neq$ `missing`. This value represents the peak energy that will be then multiplied by the profile for each period in the timeframe.

!!! info
    These parameters are defined per period, and the default values for profiles are 1.0 p.u. per period. If the periods are determined daily, the energy limit for the whole year will be 365 times `max`or `min_energy_timeframe_partition`.

- (optional) `profile_type` and `profile_name` in the timeframe files. If there is no profile defined, then by default it is 1.0 p.u. for all periods in the timeframe.
- (optional) define a period partition in timeframe partition files. If there is no partition defined, then by default the constraint is created for each period in the timeframe, otherwise, it will consider the partition definition in the file.

!!! tip "Tip"
    If you want to set a limit on the maximum or minimum outgoing energy for a year with representative days, you can use the partition definition to create a single partition for the entire year to combine the profile.

### Example: Setting Energy Limits

Let's assume we have a year divided into 365 days because we are using days as periods in the representatives from [_TulipaClustering.jl_](https://github.com/TulipaEnergy/TulipaClustering.jl). Also, we define the `max_energy_timeframe_partition = 10 MWh`, meaning the peak energy we want to have is 10MWh for each period or period partition. So depending on the optional information, we can have:

| Profile | Period Partitions | Example                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    |
| ------- | ----------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| None    | None              | The default profile is 1.p.u. for each period and since there are no period partitions, the constraints will be for each period (i.e., daily). So the outgoing energy of the asset for each day must be less than or equal to 10MWh.                                                                                                                                                                                                                                                                                                                                                                       |
| Defined | None              | The profile definition and value will be in the timeframe profiles files. For example, we define a profile that has the following first four values: 0.6 p.u., 1.0 p.u., 0.8 p.u., and 0.4 p.u. There are no period partitions, so constraints will be for each period (i.e., daily). Therefore the outgoing energy of the asset for the first four days must be less than or equal to 6MWh, 10MWh, 8MWh, and 4MWh.                                                                                                                                                                                        |
| Defined | Defined           | Using the same profile as above, we now define a period partition in the timeframe partitions file as `uniform` with a value of 2. This value means that we will aggregate every two periods (i.e., every two days). So, instead of having 365 constraints, we will have 183 constraints (182 every two days and one last constraint of 1 day). Then the profile is aggregated with the sum of the values inside the periods within the partition. Thus, the outgoing energy of the asset for the first two partitions (i.e., every two days) must be less than or equal to 16MWh and 12MWh, respectively. |

## [Defining a group of assets](@id group-setup)

A group of assets refers to a set of assets that share certain constraints. For example, the investments of a group of assets may be capped at a maximum value, which represents the potential of a specific area that is restricted in terms of the maximum allowable MW due to limitations on building licenses.

In order to define the groups in the model, the following steps are necessary:

1. Create a group file by defining the `name` property and its parameters in the `group_asset` table (or CSV file).
2. Assign assets to the group by setting the `name` in the `group` parameter/column of the asset file.

!!! info
    A missing value in the parameter `group` means that the asset does not belong to any group.

Groups are useful to represent several common constraints, the following group constraints are available.

### [Setting up a maximum or minimum investment limit for a group](@id investment-group-setup)

The mathematical formulation of the maximum and minimum investment limit for group constraints is available [here](@ref investment-group-constraints).

- `invest_method = true`. This parameter enables the model to use the investment group constraints.
- `min_investment_limit` $\neq$ `missing` or `max_investment_limit` $\neq$ `missing`. This value represents the limits that will be imposed on the investment that belongs to the group.

!!! info
    1. A missing value in the parameters `min_investment_limit` and `max_investment_limit` means that there is no investment limit.
    2. These constraints are applied to the investments each year. The model does not yet have investment limits to a group's available invested capacity.

### Example: Group of Assets

Let's explore how the groups are set up in the test case called [Norse](https://github.com/TulipaEnergy/TulipaEnergyModel.jl/tree/main/test/inputs/Norse). First, let's take a look at the `group-asset.csv` file:

```@example display-group-setup
using DataFrames # hide
using CSV # hide
input_asset_file = "../../test/inputs/Norse/group-asset.csv" # hide
assets = CSV.read(input_asset_file, DataFrame, header = 1) # hide
```

In the given data, there are two groups: `renewables` and `ccgt`. Both groups have the `invest_method` parameter set to `true`, indicating that investment group constraints apply to both. For the `renewables` group, the `min_investment_limit` parameter is missing, signifying that there is no minimum limit imposed on the group. However, the `max_investment_limit` parameter is set to 40000 MW, indicating that the total investments of assets in the group must be less than or equal to this value. In contrast, the `ccgt` group has a missing value in the `max_investment_limit` parameter, indicating no maximum limit, while the `min_investment_limit` is set to 10000 MW for the total investments in that group.

Let's now explore which assets are in each group. To do so, we can take a look at the `asset.csv` file:

```@example display-group-setup
input_asset_file = "../../test/inputs/Norse/asset.csv" # hide
assets = CSV.read(input_asset_file, DataFrame) # hide
assets = assets[.!ismissing.(assets.group), [:asset, :type, :group]] # hide
```

Here we can see that the assets `Asgard_Solar` and `Midgard_Wind` belong to the `renewables` group, while the assets `Asgard_CCGT` and `Midgard_CCGT` belong to the `ccgt` group.

!!! info
    If the group has a `min_investment_limit`, then assets in the group have to allow investment (`investable = true`) for the model to be feasible. If the assets are not `investable` then they cannot satisfy the minimum constraint.

## [Setting up multi-year investments](@id multi-year-setup)

!!! warning "The workflow of feature is under construction"
    This section describes the existing workflow but we are working to make it more user friendly.

It is possible to simutaneously model different years, which is especially relevant for modeling multi-year investments. Multi-year investments refer to making investment decisions at different points in time, such that a pathway of investments can be modeled. This is particularly useful when long-term scenarios are modeled, but modeling each year is not practical. Or in a business case, investment decisions are supposed to be made in different years which has an impact on the cash flow.

### Filling the input data

In order to set up a model with year information, the following steps are necessary. The below illustrative example uses assets, but flows follow the same idea.

#### Year data

Fill in all the years in [`year-data.csv`](@ref schemas) file by defining the `year` property and its parameters. Differentiate milestone years and non-milestone years.

- Milestone years are the years you would like to model. For example, if you want to model operation and/or investments in 2030, 2040, and 2050. These 3 years are then milestone years.
- Non-milestone years are the commission years of existing units. For example, you want to consider a existing wind unit that has been commissioned in 2020, then 2020 is a non-milestone year.

!!! info
    A year can both be a year that you want to model and that there are existing units invested, then this year is a milestone year.

#### Asset basic data

Fill in the parameters in the `asset.csv` file. These parameters are for the assets across all the years, i.e., not dependent on years. Examples are lifetime (both `technical_lifetime` and `economic_lifetime`) and capacity of a unit.

You need to choose a `investment_method` for the asset, between `none`, `simple`, and `compact`. In addition, you also have to make it explicit on which assets you would like to invest in, by setting the `investable` parameter in `asset-milestone.csv`, and which assets you would like to decommission, by setting the `decommissionable` parameter in `asset-both.csv`. More information on `investable` and `decommissionable` are given in the next sections.

Below is an overview of the important set-ups regarding the investment methods.

- Operation mode: choose `none`. Set `investable` and `decommissionable` to `false` to make sure neither investments nor decommissioning occur.
- Simple investment method: choose `simple`. Set `investable` and `decommissionable` manually. Make sure `milestone_year = commission_year` in `asset-both.csv`. Any missing or redundant rows will throw an error.
- Compact investment method: choose `compact`. Set `investable` and `decommissionable` manually. Make sure to have more than one commission year for a milestone year in `asset-both.csv`, and the matching profiles. Otherwise the compact method will work the same as the simple method.

!!! info "More about the investment methods"
    1. The `compact` method can only be applied to producer assets and conversion assets. Transport assets and storage assets can only use `simple` or `none` method.
    2. For more details on the constraints that apply when selecting these methods, please visit the [`mathematical formulation`](@ref formulation) section.

#### Asset milestone year data

Fill in the parameters related to the milestone year. Whether the model allows investment at a milestone year for an asset is set by the `investable` parameter in `asset-milestone.csv`. You can only invest in milestone years.

#### Asset commission year data

Fill in the parameters related to the commission year, e.g., investment costs and fixed costs.

#### Existing capacities and decommissioning

Existing capacities and decommissioning are taken care of in `asset-both.csv`

- In the `milestone_year` column, fill in all the milestone years. In the `commission_year` column, fill in the commission years of the existing assets that are still available in this `milestone_year` and put the existing units in the column `initial_units`.
- Whether the model allows decommissioning at a `milestone_year` for an asset that has been commissioned in a `commission_year` is set by the parameter `decommissionable`.

Let's explain further using an example. To do so, we take a look at the `asset-both.csv` file:

```@example multi-year-setup
using DataFrames # hide
using CSV # hide
input_asset_file = "../../test/inputs/Multi-year Investments/asset-both.csv" # hide
assets_data = CSV.read(input_asset_file, DataFrame) # hide
assets_data = assets_data[:, [:asset, :milestone_year, :commission_year, :decommissionable, :initial_units]] # hide
```

- `battery` has 1.09 existing units in 2030 and 2.02 existing units in 2050. Both units can be decommissioned.
- `ccgt` has 1 existing units in 2030 and 2050. Neither can be decommissioned.
- `demand` is a consumer, so is has no initial units and you only have data where `milestone_year = commission_year`.
- `ens` has 1 existing units in 2030 and 2050. Neither can be decommissioned.
- `ocgt` has no existing units.
- `solar` has no existing units.
- `wind` has 0.07 existing units, commissioned in 2020, and still available in 2030 but not in 2050. Another 0.02 existing units, commissioned in 2030, available in 2030 and 2050. There are no initial units commissioned in 2050.

!!! info
    We only consider the existing units which are still available in the milestone years.

#### Profiles information

Important to know that you can use different profiles for assets that are commissioned in different years, which is the power of the `compact` method. You fill in the profile names in `assets-profiles.csv` for relevant years. In `profiles-rep-periods.csv`, you relate the profile names with the modeled years.

Let's explain further using an example. To do so, we can take a look at the `assets-profiles.csv` file:

```@example multi-year-setup
input_asset_file = "../../test/inputs/Multi-year Investments/assets-profiles.csv" # hide
assets_profiles = CSV.read(input_asset_file, DataFrame, header = 1) # hide
assets_profiles = assets_profiles[:, :] # hide
```

We have 3 profiles for `wind` commissioned in 2020, 2030, and 2050, respectively. Imagine these are 3 wind turbines with different efficiencies due to the year of manufacture.

### Economic representation

For economic representation, the following parameters need to be set up:

- [optional] `discount year` and `discount rate` in the `model-parameters-example.toml` file: model-wide discount year and rate. By default, the model will use a discount rate of 0, and a discount year of the first milestone year. In other words, the costs will be discounted to the cost of the first milestone year.
- `discount_rate`: technology-specific discount rates.
- `economic_lifetime`: used for discounting the costs.

!!! info
    1. Since the model explicitly discounts, all the inputs for costs should be given in the costs of the relevant year. For example, to model investments in 2030 and 2050, the `investment_cost` should be given in 2030 costs and 2050 costs, respectively.
    2. For more details on the formulas for economic representation, please visit the [`mathematical formulation`](@ref formulation) section.

## [Using the coefficient for flows in the capacity constraints](@id coefficient-for-capacity-constraints)

Capacity constraints apply to all the outputs and inputs to assets according to the equations in the [`capacity constraints`](@ref cap-constraints) section of the mathematical formulation. The coefficient $p^{\text{capacity coefficient}}_{f,y}$ in the capacity constraints can be set to model situations or processes where the flows in the capacity constraint are multiplied by a constant factor.

For instance, a hydro reservoir (i.e., storage asset) with two outputs, one for electricity production and another for water spillage. The electricity output flow must be in the capacity constraints. However, the water spillage is an output that can be excluded from the capacity constraint. In that case, the coefficient for the capacity constraint of the water output can be zero and therefore not included in that constraint.

Another situation comes from industrial processes where the sum of both outputs must be below the capacity, but one of the outputs can be above the capacity if only produced in that flow. For example,

$\text{flow process A} + 0.8 \cdot \text{flow process B} \leq \text{C}$

In that case the sum must be always below the total capacity $\text{C}$, but if you only produce flow through B then you can produce $1.25 \cdot \text{C}$ and still satisfy this constraint.

To set up this parameter you need to fill in the information for the `flow_coefficient_in_capacity_constraint` in the `flow_commission` table, see more in the [model parameters](@ref schemas) section.
