# [Beginner Tutorial #2](@id tutorial-manual)

## Manually running each step

If you need more control, you can create the energy problem first, then the optimization model inside it, and finally ask for it to be solved.

First create the DuckDB connection, populate the data, and create an empty [EnergyProblem](@ref energy-problem):

```julia @example basics
using DuckDB, TulipaIO, TulipaEnergyModel

# You can reuse the data you copied in the first tutorial (or copy it with the commented line below)
# cp(joinpath(pkgdir(TulipaEnergyModel), "test", "inputs", "Tiny"), "example-data") # Create the path to the test folder
input_dir = "example-data"
connection = DBInterface.connect(DuckDB.DB)
read_csv_folder(connection, input_dir; schemas = TulipaEnergyModel.schema_per_table_name)
energy_problem = EnergyProblem(connection)
```

The energy problem does not have a model yet:

```julia @example basics
energy_problem.model === nothing
```

To create the internal model, call the function [`create_model!`](@ref).

```julia @example basics
create_model!(energy_problem)
energy_problem.model
```

Now the internal model has been created and you can see the number of variables and constraints being used.

The model has not been solved yet, which can be verified through the `solved` flag inside the energy problem:

```julia @example basics
energy_problem.solved
```

Finally, you can solve the model:

```julia @example basics
solve_model!(energy_problem)
```

To compute the solution and save it in the DuckDB connection, you can use

```julia @example basics
save_solution!(energy_problem)
```

The solutions will be saved in the variable and constraints tables.
To save the solution to CSV files, you can use [`export_solution_to_csv_files`](@ref)

```julia @example basics
mkdir("output_folder")
export_solution_to_csv_files("output_folder", energy_problem)
```

The objective value and the termination status are also included in the energy problem:

```julia @example basics
energy_problem.objective_value, energy_problem.termination_status
```

## Manually creating all structures without EnergyProblem

The `EnergyProblem` structure holds various internal structures, including the JuMP model and the DuckDB connection.
There is currently no reason to manually create and maintain these structures yourself, so we recommend that you use the previous sections instead.

To avoid having to update this documentation whenever we make changes to the internals of TulipaEnergyModel before the v1.0.0 release, we will keep this section empty until then.
