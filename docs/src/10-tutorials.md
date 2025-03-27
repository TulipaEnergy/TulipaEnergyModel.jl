# [Tutorials](@id tutorials)

Here are some tutorials on how to use Tulipa.

```@contents
Pages = ["10-tutorials.md"]
Depth = [2, 3]
```

## [Beginner Tutorial #1](@id basic-example)

For our first analysis, let's use a tiny existing dataset.
Inside the code for this package, you can find the folder [`test/inputs/Tiny`](https://github.com/TulipaEnergy/TulipaEnergyModel.jl/tree/main/test/inputs/Tiny), which includes all the files necessary to create a model and solve it.

The files inside the "Tiny" folder define the assets and flows data, their profiles, and their time resolution, as well as the representative periods and which periods in the full problem formulation they represent.

You can read more about the [Input](@ref input) later - for now just know that it's a minimal problem with producers connected to consumers.
The optimisation will solve:

1. Optimal (minimum cost) investment in production and flow capacities to satisfy future demand
1. Optimal (minimum cost) operation (dispatch) of the new system

Now you have everything you need!

### Starting Julia

Choose one:

- In VSCode: Press `CTRL`+`Shift`+`P` and then `Enter` to start a Julia REPL.
- In the terminal: Type `julia` and press `Enter`
- Enter package mode and activate the project: `]` then `pkg> activate .` (including the dot!)
- Make sure your package are up to date: `pkg> up`

### Run a tiny scenario

In Julia run:

```julia @example bt-1
using DuckDB, TulipaIO, TulipaEnergyModel

# Set the input directory to the Tiny folder (which is in the test folder of the package)
cp(joinpath(pkgdir(TulipaEnergyModel), "test", "inputs", "Tiny"), "example-data") # Create the path to the test folder
input_dir = "example-data"
readdir(input_dir) # Check the input directory is correct - this should show the names of the files in the folder

# Create a DuckDB database connection
connection = DBInterface.connect(DuckDB.DB)

# Read the files into DuckDB tables - luckily the files are already formatted to fit the Model Schema
read_csv_folder(connection, input_dir; schemas = TulipaEnergyModel.schema_per_table_name)

# Run the scenario and save the result to the energy_problem
energy_problem = run_scenario(connection)
```

Congratulations - you just solved your first scenario! 🌷

<!-- TODO : Add looking at results -->

## [Beginner Tutorial #2](@id tutorial-manual)

### Manually running each step

If you need more control, you can create the energy problem first, then the optimization model inside it, and finally ask for it to be solved.

First create the DuckDB connection, populate the data, and create an empty [EnergyProblem](@ref energy-problem):

```@example manual-energy-problem
using DuckDB, TulipaIO, TulipaEnergyModel

# input_dir = "../../test/inputs/Tiny" # hide
# input_dir should be the path to Tiny as a string (something like "test/inputs/Tiny")
# Set the input directory to the Tiny folder (which is in the test folder of the package)
cp(joinpath(pkgdir(TulipaEnergyModel), "test", "inputs", "Tiny"), "example-data") # Create the path to the test folder
input_dir = "example-data"
connection = DBInterface.connect(DuckDB.DB)
read_csv_folder(connection, input_dir; schemas = TulipaEnergyModel.schema_per_table_name)
energy_problem = EnergyProblem(connection)
```

The energy problem does not have a model yet:

```@example manual-energy-problem
energy_problem.model === nothing
```

To create the internal model, call the function [`create_model!`](@ref).

```@example manual-energy-problem
create_model!(energy_problem)
energy_problem.model
```
Now the internal model has been created and you can see the number of variables and constraints being used.

The model has not been solved yet, which can be verified through the `solved` flag inside the energy problem:

```@example manual-energy-problem
energy_problem.solved
```

Finally, you can solve the model:

```@example manual-energy-problem
solve_model!(energy_problem)
```

To compute the solution and save it in the DuckDB connection, you can use

```@example manual-energy-problem
save_solution!(energy_problem)
```

The solutions will be saved in the variable and constraints tables.
To save the solution to CSV files, you can use [`export_solution_to_csv_files`](@ref)

```@example manual-energy-problem
mkdir("output_folder")
export_solution_to_csv_files("output_folder", energy_problem)
```

The objective value and the termination status are also included in the energy problem:

```@example manual-energy-problem
energy_problem.objective_value, energy_problem.termination_status
```

### Manually creating all structures without EnergyProblem

The `EnergyProblem` structure holds various internal structures, including the JuMP model and the DuckDB connection.
There is currently no reason to manually create and maintain these structures yourself, so we recommend that you use the previous sections instead.

To avoid having to update this documentation whenever we make changes to the internals of TulipaEnergyModel before the v1.0.0 release, we will keep this section empty until then.
