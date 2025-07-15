# Assets and Flows

Tulipa uses [Assets and Flows](@ref concepts) as generalized components to build energy systems.

## Set up the data

We will start from the [Basics Tutorial](@ref basic-example).\
If you have not followed that tutorial, follow these sections before starting this tutorial:

1. [Create a VS Code Project](@ref vscode-project)
1. [Set up data and folders](@ref tutorial-data-folders)

## Explore the files

Take a look at the files in the `assets-tutorial` folder.

## Run the workflow

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
input_dir = "assets-tutorial"
output_dir = "my-awesome-results"

# Create the connection and read the input files
connection = DBInterface.connect(DuckDB.DB)
TIO.read_csv_folder(connection, input_dir)

# Add the defaults
TEM.populate_with_defaults!(connection)

# Run the model
energy_problem =
    TEM.run_scenario(connection; output_folder=output_dir)
```

## Explore the results

Explore the flow that goes from the hub to the e_demand:

```julia
flows = TIO.get_table(connection, "var_flow")

from_asset = "hub"
to_asset = "e_demand"
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
    dpi=600,
)
```

Explore the congestion using the duals in the results:

```julia
transport = TIO.get_table(connection, "cons_transport_flow_limit_simple_method")

names(transport)

filter(
    row ->
        row.dual_max_transport_flow_limit_simple_method != 0.0,
    transport,
)
```

!!! info "Test Your Knowledge"
    Can you explain the values you get from the column `dual_max_transport_flow_limit_simple_method`?

## Challenge: Add a Battery

Try adding a battery (a short-term storage asset) that can **only charge** from the solar PV and discharges to the `e_demand` consumer.
