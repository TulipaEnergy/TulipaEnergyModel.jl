# [Tutorial 1: The Basics](@id basic-example)

Welcome to the first tutorial, here you will learn the basics of how to run TulipaEnergyModel. Good luck! 🌷

## Load data and run Tulipa

If you have not done so already, please follow the steps in the pre-tutorial first.
You should have a VS Code project set up before starting this tutorial.

Ensure you are using the necessary packages by running the lines below:

```julia
import TulipaIO as TIO
import TulipaEnergyModel as TEM
using DuckDB
using DataFrames
using Plots
```

!!! tip
    Follow along in this section, copy-pasting into your my_workflow.jl file.\
    In VS Code, you can highlight each section and press (SHIFT+ENTER) to run the code.\
    Or paste everything and press the run arrow (top right in VS Code) to run the entire file.

We need to create a connection to DuckDB and point to the input and output folders:

```julia
connection = DBInterface.connect(DuckDB.DB)
input_dir = "my-awesome-energy-system/tutorial-1"
output_dir = "my-awesome-energy-system/tutorial-1/results"
```

Let's use TulipaIO to read the files and list them:

```julia
TIO.read_csv_folder(connection, input_dir)

TIO.show_tables(connection)  # View all the table names in the DuckDB connection
# If your output window isn't large enough, it'll be cut-off
# Just expand the window and rerun the line
```

Now try viewing a specific table:

```julia
TIO.get_table(connection, "asset") # Or any other table name
```

Add any missing columns and fill them with defaults:

```julia
TEM.populate_with_defaults!(connection)

# Explore the tables in DuckDB (again)
TIO.get_table(connection, "asset")
# Notice there are now a lot of new columns filled with default values
```

Run, baby run!

```julia
energy_problem =
    TEM.run_scenario(connection; output_folder=output_dir)
```

## Explore the results

*Which files were created in the output folder?*\
Take a minute to explore them.

Because we specified an output folder to run_scenario, it automatically exported the CSVs.\
But instead of exporting, you can also explore results in Julia!

### Basic Plots in Julia

Take a look at the electricity production from the "wind" asset that flows to the "e_demand" asset:

```julia
using DataFrames
using Plots

flows = TIO.get_table(connection, "var_flow") # Put the "var_flow" table from DuckDB into a Julia dataframe called "flows"

from_asset = "wind"
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

For the prices, work with the dual of the constraint.

```julia
balance = TIO.get_table(connection, "cons_balance_consumer")

asset = "e_demand"
year = 2030
rep_period = 1

filtered_asset = filter(
    row ->
        row.asset == asset &&
            row.year == year &&
            row.rep_period == rep_period,
    balance,
)

plot(
    filtered_asset.time_block_start,
    filtered_asset.dual_balance_consumer;
    #label=string(from_asset, " -> ", to_asset),
    xlabel="Hour",
    ylabel="[MWh]",
    ylims=(0,200),
    #xlims=(0, 168),
    dpi=600,
)
```

!!! info "Test Your Knowledge"
    Inspect the prices in the plot. Notice how the prices mostly match the operational costs of the dispatchable assets. However, there is an outlier. Can you explain the prices of 153.8462€/MWh in the e_demand? Hint: consider the interlinkage between hydrogen and electricity demand

Another important aspect to consider is that we are currently not allowing the model to invest in any of the technologies. It has to solve the energy problem with the currently allocated capacities. There is a column in the `asset-milestone.csv` file that requires true or false values for whether an asset is investable or not. Try changing the value in this column for the wind asset to true and run the model again. What differences do you see?
