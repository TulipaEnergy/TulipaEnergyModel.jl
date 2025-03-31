# [Tutorials](@id tutorials)

Here are some tutorials on how to use Tulipa.

```@contents
Pages = ["10-tutorials.md"]
Depth = 3
```

## [Beginner Tutorial #1](@id basic-example)

For our first analysis, let's use a tiny existing dataset.
Inside the code for this package, you can find the folder [`test/inputs/Tiny`](https://github.com/TulipaEnergy/TulipaEnergyModel.jl/tree/main/test/inputs/Tiny), which includes all the files necessary to create a model and solve it.

The files inside the "Tiny" folder define the assets and flows data, their profiles, and their time resolution, as well as define the representative periods and which periods in the full problem formulation they represent.

For more details about these files, see [Input](@ref input).

### Starting Julia

Choose one:

- In VSCode: Press `CTRL`+`Shift`+`P` and then `Enter` to start a Julia REPL.
- In the terminal: Type `julia` and press `Enter`

### Run a tiny scenario

In Julia:

```julia @example bt-1
using DuckDB, TulipaIO, TulipaEnergyModel

# Set the input directory to the Tiny folder
input_dir = "../../test/inputs/Tiny" # Something like "test/inputs/Tiny" or "test\\inputs\\Tiny"
readdir(input_dir) # Check the input directory is correct - this should show the names of the files in the folder

# Create a DuckDB database connection
connection = DBInterface.connect(DuckDB.DB)

# Read the files into DuckDB tables - luckily the files are already formatted to fit the Model Schema
read_csv_folder(connection, input_dir; schemas = TulipaEnergyModel.schema_per_table_name)

# Run the scenario and save the result to the energy_problem
energy_problem = run_scenario(connection)
```

Congratulations - you just solved your first scenario! 🌷

Now let's look at some of the results:

```julia @example bt-1
# Check

# Export the results to CSV

```

## [Beginner Tutorial #2](@id bt-2)

### Manually running each step

If we need more control, we can create the energy problem first, then the optimization model inside it, and finally ask for it to be solved.

```@example manual-energy-problem
using DuckDB, TulipaIO, TulipaEnergyModel

input_dir = "../../test/inputs/Tiny" # hide
# input_dir should be the path to Tiny as a string (something like "test/inputs/Tiny")
connection = DBInterface.connect(DuckDB.DB)
read_csv_folder(connection, input_dir; schemas = TulipaEnergyModel.schema_per_table_name)
energy_problem = EnergyProblem(connection)
```

The energy problem does not have a model yet:

```@example manual-energy-problem
energy_problem.model === nothing
```

To create the internal model, we call the function [`create_model!`](@ref).

```@example manual-energy-problem
create_model!(energy_problem)
energy_problem.model
```

The model has not been solved yet, which can be verified through the `solved` flag inside the energy problem:

```@example manual-energy-problem
energy_problem.solved
```

Finally, we can solve the model:

```@example manual-energy-problem
solve_model!(energy_problem)
```

The compute the solution and save it in the DuckDB connection, we can use

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

## Change optimizer and specify parameters

By default, the model is solved using the [HiGHS](https://github.com/jump-dev/HiGHS.jl) optimizer (or solver).
To change this, we can give the functions `run_scenario` or `solve_model!` a
different optimizer.

!!! warning
HiGHS is the only open source solver that we recommend. GLPK and Cbc are not (fully) tested for Tulipa.

For instance, let's run the Tiny example using the [GLPK](https://github.com/jump-dev/GLPK.jl) optimizer:

```@example
using DuckDB, TulipaIO, TulipaEnergyModel, GLPK

input_dir = "../../test/inputs/Tiny" # hide
# input_dir should be the path to Tiny as a string (something like "test/inputs/Tiny")
connection = DBInterface.connect(DuckDB.DB)
read_csv_folder(connection, input_dir; schemas = TulipaEnergyModel.schema_per_table_name)
energy_problem = run_scenario(connection, optimizer = GLPK.Optimizer)
```

or

```@example manual-energy-problem
using GLPK

solution = solve_model!(energy_problem, GLPK.Optimizer)
```

!!! info
Notice that, in any of these cases, we need to explicitly add the GLPK package ourselves and add `using GLPK` before using `GLPK.Optimizer`.

In any of these cases, default parameters for the `GLPK` optimizer are used,
which you can query using [`default_parameters`](@ref).
You can pass a dictionary using the keyword argument `parameters` to change the defaults.
For instance, in the example below, we change the maximum allowed runtime for
GLPK to be 1 seconds, which will most likely cause it to fail to converge in time.

```@example
using DuckDB, TulipaIO, TulipaEnergyModel, GLPK

input_dir = "../../test/inputs/Tiny" # hide
parameters = Dict("tm_lim" => 1)
connection = DBInterface.connect(DuckDB.DB)
read_csv_folder(connection, input_dir; schemas = TulipaEnergyModel.schema_per_table_name)
energy_problem = run_scenario(connection, optimizer = GLPK.Optimizer, parameters = parameters)
energy_problem.termination_status
```

For the complete list of parameters, check your chosen optimizer.

These parameters can also be passed via a file. See the
[`read_parameters_from_file`](@ref) function for more details.
