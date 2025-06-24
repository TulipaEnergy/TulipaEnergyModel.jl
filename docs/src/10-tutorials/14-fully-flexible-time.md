# Fully-Flexible Temporal Resolution Tutorial

The main concepts are explained in the docs section [Flexible Time Resolution](@ref flex-time-res).

For more nitty gritty nerdy details, you can read this reference. :wink:\
*Gao, Zhi and Gazzani, Matteo and Tejada-Arango, Diego A. and Siqueira, Abel and Wang, Ni and Gibescu, Madeleine and Morales-España, G., Fully Flexible Temporal Resolution for Energy System Optimization.*\
Available at SSRN: https://ssrn.com/abstract=5214263 or http://dx.doi.org/10.2139/ssrn.5214263

## 1. Set up the data

We will reuse the project we created in the [Basics Tutorial](@ref basic-example).

1. **Move the folder** `my-awesome-energy-system-lesson-3` into your VS Code project.\
!!! tip
    To find the folder where you created your project, right click on any file in VS code (e.g. 'my_workflow.jl') and click "Reveal in File Explorer"*

### Hydrogen sector on 6 hour resolution

The flexible temporal resolution for assets and flows is defined in the files: 'assets_rep_periods_partitions' and 'flows_rep_periods_partitions'

*Note*: The schemas of the files is described in the [input parameters](https://tulipaenergy.github.io/TulipaEnergyModel.jl/dev/50-schemas/) of the docs.

- 'assets_rep_periods_partitions' file:

```txt
asset,partition,rep_period,specification,year
electrolizer,6,1,uniform,2030
```

- 'flows_rep_periods_partitions' file:

```txt
from_asset,to_asset,partition,rep_period,specification,year
electrolizer,h2_demand,6,1,uniform,2030
```

*Note*: If no partition/resolution is defined for and asset or flow, then the default values are `uniform` and `1`.

Let's add the compatibility of TulipaEnergyModel in the Julia REPL:

### Project TOML of the project

Some of you have encountered some problems, so first try to add

```julia
# ]
pkg> compat TulipaEnergyModel 0.15.0
pkg> add TulipaEnergyModel@0.15.0
```

If still you have problems, then please edit the **Project.toml** file with the following information:

```toml
[deps]
DataFrames = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
DuckDB = "d2f5444f-75bc-4fdf-ac35-56f514c445e1"
Plots = "91a5bcdd-55d7-5caf-9e0b-520d859cae80"
TulipaEnergyModel = "5d7bd171-d18e-45a5-9111-f1f11ac5d04d"
TulipaIO = "7b3808b7-0819-42d4-885c-978ba173db11"

[compat]
TulipaEnergyModel = "0.15.0"
```

After updating your **Project.toml** please instantiate your enviroment by typing the following command in the Julia REPL:

```julia
# guaranteed to be run in the current directory
using Pkg: Pkg
Pkg.activate(".")
Pkg.instantiate()
```

## 2. Run the case study

In `my_workflow.jl` you can simply change the name of your input directory and run your code.\
From the Basics Tutorial, it should look something like this:

```julia
# Guarantee to run in the current directory
using Pkg: Pkg
Pkg.activate(".")

# Load the packages
import TulipaIO as TIO
import TulipaEnergyModel as TEM
using DuckDB
using DataFrames
using Plots

# Define the directories
input_dir = "my-awesome-energy-system-lesson-3"
output_dir = "my-awesome-energy-system-results"

# Temporary fix!!: pass the schema of the partition files
schema_partition_files = Dict(
    table_name => TEM.schema_per_table_name[table_name]
    for table_name in ["assets_rep_periods_partitions", "flows_rep_periods_partitions"]
)

# Create the connection and read the case study files
connection = DBInterface.connect(DuckDB.DB)
TIO.read_csv_folder(connection, input_dir; schemas=schema_partition_files)

# Add the defaults
TEM.populate_with_defaults!(connection)

# Optimize the model
energy_problem =
    TEM.run_scenario(connection; output_folder=output_dir)

```

**From the statistics at the end, what are the number of constraints, variables, and objective function?**

```log
  - Model created!
    - Number of variables: 80300
    - Number of constraints for variable bounds: 71540
    - Number of structural constraints: 99280
  - Model solved!
    - Termination status: OPTIMAL
    - Objective value: 1.6945648344572577e8
```

## 3. Explore the results

Explore the flow that goes from the electrolizer to the h2_demand:

*Note*: There are 1460 values (8760h/6h)

```julia

flows = TIO.get_table(connection, "var_flow")

from_asset = "electrolizer"
to_asset = "h2_demand"
year = 2030
rep_period = 1

filtered_flow = filter(
    row ->
        row.from_asset == from_asset &&
            row.to_asset == to_asset &&
            row.year == year &&
            row.rep_period == rep_period,
    flows,
)

plot(
    filtered_flow.time_block_start,
    filtered_flow.solution;
    label=string(from_asset, " -> ", to_asset),
    xlabel="Hour",
    ylabel="[MWh]",
    marker=:circle,
    markersize=2,
    linetype=:steppost, # try: stepmid, steppost, or steppre
    xlims=(1, 168 * 4),
    dpi=600,
)

```

Explore the h2_balance duals in the results:

```julia
balance = TIO.get_table(connection, "cons_balance_consumer")

asset = "h2_demand"
year = 2030
rep_period = 1

filtered_asset = filter(
    row ->
        row.asset == asset &&
            row.year == year &&
            row.rep_period == rep_period,
    balance,
)
```

**What do you notice?**

**How is the resolution of the Consumer Balance Constraint defined?**

Update the 'flows_rep_periods_partitions' file:

```txt
from_asset,to_asset,partition,rep_period,specification,year
electrolizer,h2_demand,6,1,uniform,2030
smr_ccs,h2_demand,6,1,uniform,2030
```

Run again and explore the results once more :wink:

### Changing the specification

The parameter `specification` allows three values: `uniform`,`math`,`explicit`

see some examples on how to set it up here: https://tulipaenergy.github.io/TulipaEnergyModel.jl/v0.10/95-reference/#TulipaEnergyModel._parse_rp_partition

What is the equialent of a partition of 6 in a `uniform` specification in a `math` specification?

### Compare with the hourly (case study from lesson 2)

If you want to compare results of two models, you can create a new connection, a new energy problem and compare results. For example:

```julia
conn_hourly = DBInterface.connect(DuckDB.DB)
input_dir = "my-awesome-energy-system-lesson-2"
TIO.read_csv_folder(conn_hourly, input_dir)
TEM.populate_with_defaults!(conn_hourly)
hourly_energy_problem = TEM.run_scenario(conn_hourly)
```

Notice that we change the name of the connection and the name of the energy problem (also, we are not exporting the results, but it can be done in a new folder, if needed).

**Compare the number of constraints, variables, and objective function between the two problems**

```log
EnergyProblem:
  - Model created!
    - Number of variables: 87600
    - Number of constraints for variable bounds: 78840
    - Number of structural constraints: 113880
  - Model solved!
    - Termination status: OPTIMAL
    - Objective value: 1.7065763441643083e8
```

What do you notice? Is it what you where expecting?

Let's plot the flows togother:

```julia
flows = TIO.get_table(connection, "var_flow")
from_asset = "electrolizer"
to_asset = "h2_demand"
year = 2030
rep_period = 1

filtered_flow = filter(
    row ->
        row.from_asset == from_asset &&
            row.to_asset == to_asset &&
            row.year == year &&
            row.rep_period == rep_period,
    flows,
)

plot(
    filtered_flow.time_block_start,
    filtered_flow.solution;
    label=string(from_asset, " -> ", to_asset),
    xlabel="Hour",
    ylabel="[MWh]",
    marker=:circle,
    markersize=2,
    linetype=:steppost, # try: stepmid, steppost, or steppre
    xlims=(400, 600),
    dpi=600,
)

hourly_flows = TIO.get_table(conn_hourly, "var_flow")

hourly_filtered_flow = filter(
    row ->
        row.from_asset == from_asset &&
            row.to_asset == to_asset &&
            row.year == year &&
            row.rep_period == rep_period,
    hourly_flows,
)

plot!(
    hourly_filtered_flow.time_block_start,
    hourly_filtered_flow.solution;
    label=string(from_asset, " -> ", to_asset, " (hourly)"),
)
```

![comparison](https://hackmd.io/_uploads/r12Vvcyexl.svg)

## Final files

You can get the final files of the tutorial from this link: [case studies github repo](https://github.com/datejada/Tulipa101-hands-on/tree/main)
