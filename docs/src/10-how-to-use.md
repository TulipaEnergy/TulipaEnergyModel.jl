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

It is nice to check that tests are passing to make sure your environment is working, this takes a minute or two.

- Enter package mode (press "]")

```julia-pkg
pkg> test TulipaEnergyModel
```

All tests should pass.

!!! warning "Admin rights in your local machine"
    Ensure you have admin rights on the folder where the package is installed; otherwise, an error will appear during the tests.

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

## [Exploring infeasibility](@id infeasible)

If your model is infeasible, you can try exploring the infeasibility with [JuMP.compute_conflict!](https://jump.dev/JuMP.jl/stable/api/JuMP/#JuMP.compute_conflict!) and [JuMP.copy_conflict](https://jump.dev/JuMP.jl/stable/api/JuMP/#JuMP.copy_conflict).

!!! warning "Check your solver options!"
    Not all solvers support this functionality; please check depending on each case.

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

## Finding an input parameter

!!! tip "Are you looking for a input parameter?"
    Please visit the [Model Parameters](@ref schemas) section for a description and location of the input parameters mentioned in this section.

## Storage specific setups

### [Seasonal and non-seasonal storage](@id seasonal-setup)

Section [Storage Modeling](@ref storage-modeling) explains the main concepts for modeling seasonal and non-seasonal storage in _TulipaEnergyModel.jl_. To define if an asset is one type or the other then consider the following:

- _Seasonal storage_: When the storage capacity of an asset is greater than the total length of representative periods, we recommend using the inter-temporal constraints. To apply these constraints, you must set the input parameter `is_seasonal` to `true`.
- _Non-seasonal storage_: When the storage capacity of an asset is lower than the total length of representative periods, we recommend using the intra-temporal constraints. To apply these constraints, you must set the input parameter `is_seasonal` to `false`.

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

For the model to add constraints for a [maximum or minimum energy limit](@ref inter-temporal-energy-constraints) for an asset throughout the model's timeframe (e.g., a year), we need to establish a couple of parameters:

- `is_seasonal = true`. This parameter enables the model to use the inter-temporal constraints.
- `max_energy_timeframe_partition` $\neq$ `missing` or `min_energy_timeframe_partition` $\neq$ `missing`. This value represents the peak energy that will be then multiplied by the profile for each period in the timeframe.

!!! info
    These parameters are defined per period, and the default values for profiles are 1.0 p.u. per period. If the periods are determined daily, the energy limit for the whole year will be 365 times `max`or `min_energy_timeframe_partition`.

- (optional) `profile_type` and `profile_name` in the timeframe files. If there is no profile defined, then by default it is 1.0 p.u. for all periods in the timeframe.
- (optional) define a period partition in timeframe partition files. If there is no partition defined, then by default the constraint is created for each period in the timeframe, otherwise, it will consider the partition definition in the file.

!!! tip "Tip"
    If you want to set a limit on the maximum or minimum outgoing energy for a year with representative days, you can use the partition definition to create a single partition for the entire year to combine the profile.

### Example: Setting Energy Limits

Let's assume we have a year divided into 365 days because we are using days as periods in the representatives from [_TulipaClustering.jl_](https://github.com/TulipaEnergy/TulipaClustering.jl). Also, we define the `max_energy_timeframe_partition = 10 MWh`, meaning the peak energy we want to have is 10MWh for each period or period partition. So depending on the optional information, we can have:

| Profile | Period Partitions | Example                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| ------- | ----------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| None    | None              | The default profile is 1.p.u. for each period and since there are no period partitions, the constraints will be for each period (i.e., daily). So the outgoing energy of the asset for each day must be less than or equal to 10MWh.                                                                                                                                                                                                                                                                                                                                                                                                    |
| Defined | None              | The profile definition and value will be in the  timeframe profiles files. For example, we define a profile that has the following first four values: 0.6 p.u., 1.0 p.u., 0.8 p.u., and 0.4 p.u. There are no period partitions, so constraints will be for each period (i.e., daily). Therefore the outgoing energy of the asset for the first four days must be less than or equal to 6MWh, 10MWh, 8MWh, and 4MWh.                                                                                                                                           |
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

!!! warning "This feature is under a major refactor"
    This section might have out-of-date information. The update of these docs is tracked in <https://github.com/TulipaEnergy/TulipaEnergyModel.jl/issues/983>

It is possible to simutaneously model different years, which is especially relevant for modeling multi-year investments. Multi-year investments refer to making investment decisions at different points in time, such that a pathway of investments can be modeled. This is particularly useful when long-term scenarios are modeled, but modeling each year is not practical. Or in a business case, investment decisions are supposed to be made in different years which has an impact on the cash flow.

### Filling the input data

In order to set up a model with year information, the following steps are necessary.

#### Year data

Fill in all the years in [`year-data.csv`](@ref schemas) file by defining the `year` property and its parameters. Differentiate milestone years and non-milestone years.

- Milestone years are the years you would like to model, e.g., if you want to model operation and/or investments (it is possibile to not allow investments) in 2030, 2040, and 2050. These 3 years are then milestone years.
- Non-milestone years are the investment years of existing units. For example, you want to consider a existing wind unit that is invested in 2020, then 2020 is a non-milestone year.

!!! info
    A year can both be a year that you want to model and that there are existing units invested, then this year is a milestone year.

#### Commission year data

Fill in the parameters related to the investment year (`commission_year` in the data) of the asset, i.e., investment costs and fixed costs.

#### Assets investment data

Fill in the parameters in the asset file. These parameters are for the assets across all the years, i.e., not dependent on years. Examples are lifetime (both `technical_lifetime` and `economic_lifetime`) and capacity of a unit.

You also have to choose a `investment_method` for the asset, between `none`, `simple`, and `compact`. The below tables shows what happens to the activation of the investment and decommission variable for certain investment methods and the `investable` parameter.

Consider you only want to model operation without investments, then you would need to set `investable_method` to `none`. Neither investment variables and decommission variables are activated. And here the `investable_method` overrules `investable`, because the latter does not matter.

!!! info
    Although it is called `investment_method`, you can see from the table that, actually, it controls directly the activation of the decommission variable. The investment variable is controlled by `investable`, which is overruled by `investable_method` in case of a conflict (i.e., for the `none` method).

| investment_method | investable | investment variable | decommission variable |
| ----------------- | ---------- | ------------------- | --------------------- |
| none              | true       | false               | false                 |
| none              | false      | false               | false                 |
| simple            | true       | true                | true                  |
| simple            | false      | false               | true                  |
| compact           | true       | true                | true                  |
| compact           | false      | false               | true                  |

For more details on the constraints that apply when selecting these methods, please visit the [`mathematical formulation`](@ref formulation) section.

!!! info
    The `compact` method can only be applied to producer assets and conversion assets. Transport assets and storage assets can only use `simple` method.

#### Assets and flows information

Fill in the assets and flows information.

- In the `year` column, fill in all the milestone years. In the `commission_year` column, fill in the investment years of the existing assets that are still available in this `year`.
  - If the `commission_year` is a non-milestone year, then it means the row is for an existing unit. The `investable` has to be set to `false`, and you put the existing units in the column `initial_units`.
  - If the `commission_year` is a milestone year, then you put the existing units in the column `initial_units`. Depending on whether you want to model investments or not, you put the `investable` to either `true` or `false`.

Let's explain further using an example. To do so, we can take a look at the `asset-both.csv` file:

```@example multi-year-setup
using DataFrames # hide
using CSV # hide
input_asset_file = "../../test/inputs/Multi-year Investments/asset-both.csv" # hide
assets_data = CSV.read(input_asset_file, DataFrame) # hide
assets_data = assets_data[1:10, [:asset, :milestone_year, :commission_year, :initial_units]] # hide
```

We allow investments of `ocgt`, `ccgt`, `battery`, `wind`, and `solar` in 2030.

- `ocgt` has no existing units.
- `ccgt` has 1 existing units, invested in 2028, and still available in 2030.
- `ccgt` has 0.07 existing units, invested in 2020, and still available in 2030. Another 0.02 existing units, invested in 2030.
- `wind` has 0.07 existing units, invested in 2020, and still available in 2030. Another 0.02 existing units, invested in 2030.
- `solar` has no existing units.

!!! info
    We only consider the existing units which are still available in the milestone years.

#### Profiles information

Fill in relevant profiles in the files. Important to know that you can use different profiles for assets that are invested in different years. You fill in the profile names in `assets-profiles.csv` for relevant years. In `profiles-rep-periods.csv`, you relate the profile names with the modeled years.

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
- `discount_rate`: technology-specific discount rates.
- `economic_lifetime`: used for discounting the costs.

!!! info
    Since the model explicitly discounts, all the inputs for costs should be given in the costs of the relevant year. For example, to model investments in 2030 and 2050, the `investment_cost` should be given in 2030 costs and 2050 costs, respectively.

For more details on the formulas for economic representation, please visit the [`mathematical formulation`](@ref formulation) section.

## [Using the coefficient for flows in the capacity constraints](@id coefficient-for-capacity-constraints)

Capacity constraints apply to all the outputs and inputs to assets according to the equations in the [`capacity constraints`](@ref cap-constraints) section of the mathematical formulation. The coeficient $p^{\text{capacity coefficient}}_{f,y}$ in the capacity constraints can be set model situations or process where the flows in the capacity constraint are multiplied by a constant factor.

For instance, a hydro reservoir (i.e., storage asset) with two outputs, one for electricity production and another for water spillage. The electricity output flow must me in the capacity constraints. However, the water spillage is an output that can be excluded from teh capacity constraint. In that case, the coefficient for the capacity constraint of the water output can be zero and therefore not included in that constraint.

Other situations come from industrial processes where the sum of both outputs must be below the capacity, but one of the outputs can be above the capacity if only produces in that flow. For example,

$\text{flow process A} + 0.8 \cdot \text{flow process B} \leq \text{C}$

In that case the sum must be always below the total capacity $\text{C}$, but if you only produce flow to B then you can get $1.25 \cdot \text{C}$.

To set up this parameter you need to fill in the information for the `capacity_constraint_coefficient` in the `flow_commission` table, see more in the [model parameters](@ref schemas) section.
