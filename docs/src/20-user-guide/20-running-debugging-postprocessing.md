# [Running, Debugging, and Posting-processing](@id running-debugging-postprocessing)

```@contents
Pages = ["20-running-debugging-postprocessing.md"]
Depth = [2, 3]
```

This section assumes users have already followed the basic Tutorials and are looking for specific instructions for certain features.

## Running a Scenario

To run a scenario, use the function:

- [`run_scenario(connection)`](@ref)
- [`run_scenario(connection; output_folder)`](@ref)

The `connection` should have been created and the data loaded into it using [TulipaIO](https://github.com/TulipaEnergy/TulipaIO.jl).
See the [Workflow Tutorial](@ref workflow-tutorial) for a complete guide on how to achieve this.
The `output_folder` is optional if the user wants to export the output.

## Finding an input parameter

!!! tip "Are you looking for an input parameter?"
    Please visit the [Model Parameters](@ref table-schemas) section for a description and location of all model input parameters.

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

## [Input and Output](@id input)

Tulipa runs from tables in DuckDB, which can be loaded from many formats (CSV, Parquet, etc).
See the workflow tutorial for more information on inputting data.

### Input

Tulipa runs from strictly defined files that follow the [Schemas](@ref table-schemas).
See the workflow section for more information on how to work with the schema.

You can check the [`test/inputs` folder](https://github.com/TulipaEnergy/TulipaEnergyModel.jl/tree/main/test/inputs) for examples of different predefined energy systems and features. Moreover, Tulipa's Offshore Bidding Zone Case Study can be found in <https://github.com/TulipaEnergy/Tulipa-OBZ-CaseStudy>. It shows how to start from user-friendly files and transform the data into the input files in the [Schemas](@ref table-schemas) through different functions.

### Output

Outputs are sent from Tulipa to DuckDB and can be exported to various file formats.

To save the solution to CSV files, you can use [`export_solution_to_csv_files`](@ref). See the [Workflow Tutorial](@ref step-export) for an example showcasing this function.

## [Cost breakdown in post-processing](@id cost-breakdown)

After solving the model, you can compute a detailed cost breakdown per asset or per flow directly from the solved variable and expression values. This does not modify the optimization model — it is purely a post-processing step.

The total objective is composed of several cost components (investment costs, fixed O&M costs, operational costs, etc.). Each component is stored as an aggregated value in the `obj_breakdown` table. The examples below show how to disaggregate these components by asset or by flow.

The general approach to construct these breakdowns is:

1. **Identify the source**: Look at the corresponding objective function in `src/objectives/` to understand what variables, expressions, and cost coefficients are involved.
2. **Get the solved values**: Variable solutions are stored in the `solution` column of `var_*` tables. Expression values (like available units) must be evaluated via `JuMP.value()` on the in-memory expressions.
3. **Get the cost coefficients**: Join with the same tables the objective uses (`t_objective_assets`, `t_objective_flows`, `asset_commission`, etc.) to obtain discounted cost coefficients.
4. **Combine**: Multiply solved values by cost coefficients, applying the `(1 - lambda)` risk aversion weight when necessary.

!!! info
    The tables `t_objective_assets` and `t_objective_flows` are temporary tables created during model construction. They contain pre-computed discount factors and annualized costs. They remain available in the DuckDB connection after solving.

!!! tip "Verifying correctness"
    You can verify that your per-asset or per-flow breakdown is consistent with the aggregated objective by comparing the sum of your breakdown with the corresponding row in `obj_breakdown`:
    ```julia
    DuckDB.query(connection, "SELECT * FROM obj_breakdown")
    ```

To save any result as a CSV file, register it as a DuckDB table and use `COPY`:

```julia
DuckDB.register_table(connection, result, "my_table_name")
output_file = joinpath(output_folder, "my_table_name.csv")
DuckDB.execute(connection, "COPY my_table_name TO '$output_file' (HEADER, DELIMITER ',')")
```

### Investment cost (CAPEX) per asset

```julia
obj_assets_investment_cost = DuckDB.query(
    connection,
    "SELECT
        var.asset,
        var.milestone_year,
        obj.weight_for_asset_investment_discount
            * obj.investment_cost
            * obj.capacity
            AS cost_per_unit_invested,
        var.solution AS units_invested,
        (1 - mp.risk_aversion_weight_lambda)
            * cost_per_unit_invested
            * var.solution
            AS investment_cost,
    FROM var_assets_investment AS var
    LEFT JOIN t_objective_assets AS obj
        ON var.asset = obj.asset
        AND var.milestone_year = obj.milestone_year
    CROSS JOIN model_parameters AS mp
    ORDER BY var.asset, var.milestone_year
    ",
)

DuckDB.register_table(connection, obj_assets_investment_cost, "obj_assets_investment_cost")
output_file = joinpath(output_folder, "obj_assets_investment_cost.csv")
DuckDB.execute(connection, "COPY obj_assets_investment_cost TO '$output_file' (HEADER, DELIMITER ',')")
```

### Fixed O&M cost per asset

```julia
using JuMP: value

# Evaluate the available units expressions (one value per row in the expr table)
expr_agg = energy_problem.expressions[:available_asset_units_aggregated_vintage_method]
avail_units = value.(expr_agg.expressions[:assets])

# Get cost coefficients from DuckDB (same query the objective uses, plus key columns)
cost_data = DuckDB.query(
    connection,
    "SELECT
        expr.id,
        expr.asset,
        expr.milestone_year,
        expr.commission_year,
        obj.weight_for_operation_discounts
            * asset_commission.fixed_cost
            * obj.capacity
            AS cost_coefficient,
    FROM expr_available_asset_units_aggregated_vintage_method AS expr
    LEFT JOIN asset_commission
        ON expr.asset = asset_commission.asset
        AND expr.commission_year = asset_commission.commission_year
    LEFT JOIN t_objective_assets AS obj
        ON expr.asset = obj.asset
        AND expr.milestone_year = obj.milestone_year
    ORDER BY expr.id
    ",
)

# Combine and build the result table
lambda = first(
    DuckDB.query(connection, "SELECT risk_aversion_weight_lambda FROM model_parameters"),
).risk_aversion_weight_lambda

obj_assets_fixed_cost = [
    (
        asset = row.asset,
        milestone_year = row.milestone_year,
        commission_year = row.commission_year,
        available_units = avail_units[row.id],
        cost_coefficient = row.cost_coefficient,
        fixed_cost = (1 - lambda) * avail_units[row.id] * row.cost_coefficient,
    ) for row in cost_data
]

# Register and export
DuckDB.register_table(connection, obj_assets_fixed_cost, "obj_assets_fixed_cost")
output_file = joinpath(output_folder, "obj_assets_fixed_cost.csv")
DuckDB.execute(connection, "COPY obj_assets_fixed_cost TO '$output_file' (HEADER, DELIMITER ',')")
```

!!! tip
    The same pattern applies to the compact vintage method — replace `aggregated` with `compact` and use `expressions[:available_asset_units_compact_vintage_method]`. For models that use both methods (different assets use different methods), you can run both queries and concatenate the results.

### Flows operational cost per flow

```julia
table_name = "obj_flows_operational_cost"
DuckDB.execute(
    connection,
    "CREATE OR REPLACE TABLE $table_name AS
    SELECT
        var.from_asset,
        var.to_asset,
        var.milestone_year,
        (1 - mp.risk_aversion_weight_lambda) * SUM(
            ss.probability
            * obj.weight_for_operation_discounts
            * rp_weight.total_weight_per_scenario
            * rp_res.resolution
            * obj.total_variable_cost
            * (var.time_block_end - var.time_block_start + 1)
            * var.solution
        ) AS operational_cost,
    FROM var_flow AS var
    LEFT JOIN t_objective_flows AS obj
        ON var.from_asset = obj.from_asset
        AND var.to_asset = obj.to_asset
        AND var.milestone_year = obj.milestone_year
    LEFT JOIN (
        SELECT milestone_year, rep_period, scenario,
               SUM(weight) AS total_weight_per_scenario
        FROM rep_periods_mapping
        GROUP BY milestone_year, rep_period, scenario
    ) AS rp_weight
        ON var.milestone_year = rp_weight.milestone_year
        AND var.rep_period = rp_weight.rep_period
    LEFT JOIN (
        SELECT milestone_year, rep_period, ANY_VALUE(resolution) AS resolution
        FROM rep_periods_data
        GROUP BY milestone_year, rep_period
    ) AS rp_res
        ON var.milestone_year = rp_res.milestone_year
        AND var.rep_period = rp_res.rep_period
    LEFT JOIN stochastic_scenario AS ss
        ON rp_weight.scenario = ss.scenario
    LEFT JOIN asset
        ON asset.asset = var.from_asset
    CROSS JOIN model_parameters AS mp
    WHERE asset.vintage_method != 'compact_efficiencies'
    GROUP BY var.from_asset, var.to_asset, var.milestone_year, mp.risk_aversion_weight_lambda
    ORDER BY var.from_asset, var.to_asset, var.milestone_year
    ",
)
```

!!! warning
    This query uses the constant `total_variable_cost` from `t_objective_flows`. If your model uses **commodity price profiles**, it needs modifications.

!!! info
    Flows from assets using `vintage_method = 'compact_efficiencies'` are excluded here — their costs are in a separate `vintage_flows_operational_cost` component. The same query pattern applies with `var_vintage_flow` and `t_objective_vintage_flows` instead.

!!! tip "Splitting into energy cost and variable O&M"
    The `total_variable_cost` in `t_objective_flows` is the sum of two components: `commodity_price / producer_efficiency` (the fuel/energy cost) and `operational_cost` (the variable O&M cost). To get a finer breakdown, replace `obj.total_variable_cost` in the query above with either:
    - `(obj.commodity_price / obj.producer_efficiency)` for the **energy cost** only (fuel/commodity cost adjusted for efficiency), or
    - `obj.operational_cost` for the **variable O&M cost** only.
    The sum of both sub-components equals the `operational_cost` column from the full query.

## Setting the solver and its parameters

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
import MathOptInterface as MOI
using JuMP

if JuMP.termination_status(energy_problem.model) == MOI.INFEASIBLE
    JuMP.compute_conflict!(energy_problem.model)
    iis_model, reference_map = JuMP.copy_conflict(energy_problem.model)
    print(iis_model)
end
```

## [Speeding up model creation](@id need-for-speed)

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
