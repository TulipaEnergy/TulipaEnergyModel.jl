# Assets and Flows

Tulipa uses [Assets and Flows](@ref concepts) as generalized components to build energy systems.

## 1. Set up the data

We will reuse the project we created in the [Basics Tutorial](@ref basic-example).

1. **Move the folder** `my-awesome-energy-system-lesson-2` into your VS Code project.\
!!! tip
    To find the folder where you created your project, right click on any file in VS code (e.g. 'my_workflow.jl') and click "Reveal in File Explorer"*

1. Explore the files :eyeglasses:\
**TODO: Add notes about what they should see in the files**

## 2. Run the workflow

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
input_dir = "my-awesome-energy-system-lesson-2" # Change this from lesson-1 to lesson-2
output_dir = "my-awesome-energy-system-results"

# Create the connection and read the input files
connection = DBInterface.connect(DuckDB.DB)
TIO.read_csv_folder(connection, input_dir)

# Add the defaults
TEM.populate_with_defaults!(connection)

# Run the model
energy_problem =
    TEM.run_scenario(connection; output_folder=output_dir)
```

## 3. Explore the results

1. Explore the flow that goes from the hub to the e_demand:

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

1. Explore the congestion using the duals in the results:

    ```julia
    transport = TIO.get_table(connection, "cons_transport_flow_limit_simple_method")

    names(transport)

    filter(
        row ->
            row.dual_max_transport_flow_limit_simple_method != 0.0,
        transport,
    )
    ```

!!! Test Your Knowledge
    Can you explain the values you get from the column `dual_max_transport_flow_limit_simple_method`?

## Add a Battery (storage asset)

Add a battery that can **only charge** from the solar PV and discharges to the `e_demand` consumer.
