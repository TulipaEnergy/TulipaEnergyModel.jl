# [Basics Tutorial](@id basic-example)

In this tutorial, you will learn (a bit) about:

1. Connecting example data with DuckDB
1. Populating default inputs
1. Running the model
1. Exploring and graphing results in Julia

*Let's get started!*

## 1. Create a VS Code project

Make sure you have Julia installed, as well as the Julia extension in VS Code.

1. Open VS Code and create a new project
    - File > Open Folder > Create a new folder > Select
1. Open a Julia REPL (CTRL + SHIFT + P > ENTER)
1. Run the code below in your Julia REPL to create a new environment and add the necessary packages (only necessary when creating a new project environment):

    ```julia
    using Pkg: Pkg       # Julia package manager (like pip for Python)
    Pkg.activate(".")    # Creates and activates the project in the new folder - notice it creates Project.toml and Manifest.toml in your folder for reproducibility
    Pkg.add("TulipaEnergyModel")
    Pkg.add("TulipaIO")
    Pkg.add("DuckDB")
    Pkg.add("DataFrames")
    Pkg.add("Plots")
    Pkg.instantiate()
    ```

1. Create a Julia file called `my_workflow.jl`
1. Paste this code in the file. Running it will load the necessary packages:

    ```julia
    import TulipaIO as TIO
    import TulipaEnergyModel as TEM
    using DuckDB
    using DataFrames
    using Plots
    ```

## 2. Set up data and folders

1. **Download the files** from this link: [case studies files](https://github.com/datejada/Tulipa101-hands-on/tree/main)\
*Click the green button Code > Download ZIP*

1. **Move the folder** `my-awesome-energy-system-lesson-1` into your VS Code project.\
!!! tip
    To find the folder where you created your project, right click on any file in VS code (e.g. 'my_workflow.jl') and click "Reveal in File Explorer"*

1. **Create a new folder** to store results called "my-awesome-energy-system-results".\
*In VS Code in the left navigation panel: Right click > New Folder*

Let's explore the files!

!!! What parameters can I use?
    Check out the docs: [TulipaEnergyModel Inputs](https://tulipaenergy.github.io/TulipaEnergyModel.jl/stable/20-user-guide/50-schemas/) and the [input-schemas.json](https://github.com/TulipaEnergy/TulipaEnergyModel.jl/blob/main/src/input-schemas.json) file.

## 3. Load data and run Tulipa

*Follow along in this section, copy-pasting into your my_workflow.jl file.\
In VS Code, you can highlight each section and press (SHIFT+ENTER) to run the code.\
Or paste everything and press the run arrow (top right in VS Code) to run the entire file.*

1. We need to create a connection to DuckDB and point to the input and output folders:

    ```julia
    connection = DBInterface.connect(DuckDB.DB)
    input_dir = "my-awesome-energy-system-lesson-1"
    output_dir = "my-awesome-energy-system-results"
    ```

1. Let's use TulipaIO to read the files and list them:

    ```julia
    TIO.read_csv_folder(connection, input_dir)

    TIO.show_tables(connection)  # View all the table names in the DuckDB connection
    # If your output window isn't large enough, it'll be cut-off
    # Just expand the window and rerun the line
    ```

1. Now try viewing a specific table:

    ```julia
    TIO.get_table(connection, "asset") # Or any other table name
    ```

1. Add any missing columns and fill them with defaults:

    ```julia
    TEM.populate_with_defaults!(connection)

    # Explore the tables in DuckDB (again)
    TIO.get_table(connection, "asset")
    # Notice there are now a lot of new columns filled with default values
    ```

1. Run, baby run!

    ```julia
    energy_problem =
        TEM.run_scenario(connection; output_folder=output_dir)
    ```

## 4. Explore the results

*Which files were created in the output folder?*\
Take a minute to explore them.

Because we specified an output folder to run_scenario, it automatically exported the CSVs.\
But instead of exporting, you can also explore results in Julia!

### Basic Plots in Julia

1. Take a look at the electricity production from the "wind" asset that flows to the "e_demand" asset:

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

1. For the prices, work with the dual of the constraint.

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
        #xlims=(0, 168),
        dpi=600,
    )
    ```

!!! Test Your Knowledge
    Can you explain the prices of 56€/MWh in the e_demand?
