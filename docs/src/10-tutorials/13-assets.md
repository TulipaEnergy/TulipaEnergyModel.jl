# Gereralized Assets and Flows

Tulipa uses [Assets and Flows](@ref concepts) as generalized components to build energy systems.

## Explore the files

Take a look at the files in the `my-awesome-energy-system/tutorial-2` folder.

Do you notice any changes compared to the files you worked with in tutorial 1?

## Run the workflow

In `my_workflow.jl` you can simply change the name of your input directory and run your code.\
From the Basics Tutorial, it should look something like this:

!!! tip
    Remember to activate the environment in the current directory using the following code in your Julia REPL:
    ```julia
    using Pkg: Pkg
    Pkg.activate(".")
    ```

```@example assets
# Load the packages
import TulipaIO as TIO
import TulipaEnergyModel as TEM
using DuckDB
using DataFrames
using Plots

# Define the directories - notice we now select tutorial 2 for both the input and output directory
input_dir = joinpath(@__DIR__, "my-awesome-energy-system/tutorial-2")
output_dir = tempdir() # point here to your results folder if you want to save the results in a specific location

# Create the connection and read the input files
connection = DBInterface.connect(DuckDB.DB)
TIO.read_csv_folder(connection, input_dir)

# Add the defaults
TEM.populate_with_defaults!(connection)

# Run the model
energy_problem =
    TEM.run_scenario(connection; output_folder=output_dir)
```

!!! warning
    Since the output directory does not exist yet, we need to create the 'results' folder inside our tutorial folder, otherwise it will error.

## Explore the results

Explore the flow that goes from the `hub` to the `e_demand`:

```@example assets
flows = TIO.get_table(connection, "var_flow")

from_asset = "hub"
to_asset = "e_demand"
year = 2030
rep_period = 1

filtered_flow = filter(
    row ->
        row.from_asset == from_asset &&
            row.to_asset == to_asset &&
            row.milestone_year == year &&
            row.rep_period == rep_period,
    flows,
)

plot(
    filtered_flow.time_block_start,
    filtered_flow.solution;
    label=string(from_asset, " -> ", to_asset),
    xlabel="Hour",
    ylabel="[MWh]",
    #dpi=600, # uncomment this line to save the plot in high resolution
)
```

Explore the congestion using the duals in the results:

```@example assets
transport = TIO.get_table(connection, "cons_transport_flow_limit_aggregated_vintage_method")

names(transport)

filter(
    row ->
        row.dual_max_transport_flow_limit_aggregated_vintage_method != 0.0,
    transport,
)
```

!!! info "Test Your Knowledge"
    Can you explain the values you get from the column `dual_max_transport_flow_limit_aggregated_vintage_method`?
    Hint: consider what is currently defining the capacity to transport the flow between the assets you see in the table.

## Challenge: Add a Battery

Try adding a battery (a short-term storage asset) that can **only charge** from the solar PV and discharges to the `e_demand` consumer.
