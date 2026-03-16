# Tutorial 6: Multi-year investments

Let's explore the multi-year investments in Tulipa. We will talk about discount approaches and different investment methods. The latter is an example for different levels of detail in Tulipa.

## 1. Set up

1. Paste the code below that add the packages and instantiate your enviroment (if you don't have it already)

```julia
using Pkg: Pkg       # Julia package manager (like pip for Python)
Pkg.activate(".")    # Creates and activates the project in the new folder - notice it creates Project.toml and
# Or enter package mode (type ']') and run 'pkg> activate .'
# Manifest.toml in your folder for reproducibility
Pkg.add("TulipaEnergyModel")
Pkg.add("TulipaIO")
Pkg.add("DuckDB")
Pkg.add("DataFrames")
Pkg.add("Plots")
Pkg.instantiate()
```

1. Paste the code below that loads the packages in the file

```julia
import TulipaIO as TIO
import TulipaEnergyModel as TEM
using DuckDB
using DataFrames
using Plots
```

## 2. The problem & explore the files

We are modeling two milestone years 2030 and 2050. The system has some initial wind capacity built in 2020, the model can choose to invest in wind in both milestone years.

There are two pairs of input-output files, we start with the *simple* one.

## 3. Discount parameters

Run TEM

```julia
connection = DBInterface.connect(DuckDB.DB)
input_dir = "docs/src/10-tutorials/my-awesome-energy-system/tutorial-6-simple-method"
output_dir = "docs/src/10-tutorials/my-awesome-energy-system/tutorial-6-simple-method/results"
TIO.read_csv_folder(connection, input_dir)
TEM.populate_with_defaults!(connection)
energy_problem = TEM.run_scenario(
        connection;
        model_parameters_file = joinpath(@__DIR__, input_dir, "model-parameters-example.toml"),
        output_folder = output_dir,
)
```

There is a new file *model-parameters-example.toml*. It contains model-wide parameters, in this case:

```julia
discount_rate = energy_problem.model_parameters.discount_rate
discount_year = energy_problem.model_parameters.discount_year
```

Check discounting parameters calculated internally by TEM.

```julia
df_objective = filter(:asset => ==("wind"), TIO.get_table(connection, "t_objective_assets"))[:,
    [:asset, :milestone_year, :investment_cost, :annualized_cost, :salvage_value,
     :investment_year_discount, :weight_for_asset_investment_discount, :weight_for_operation_discounts]]

df_asset = filter(:asset => ==("wind"), TIO.get_table(connection, "asset"))[:,
    [:asset, :technical_lifetime, :economic_lifetime]]

df = leftjoin(df_objective, df_asset, on = :asset)
```

## 4. Different levels of details: simple method vs compact method

Remember that we have wind built in 2020 - does it have the same profiles as 2030?
Let's check it out.

```julia
plot()
wind_profiles = filter(row -> occursin("wind", row.profile_name) && row.year == 2030,
    TIO.get_table(connection, "profiles_rep_periods"))

for pname in unique(wind_profiles.profile_name)
    subdf = wind_profiles[wind_profiles.profile_name .== pname, :]
    plot!(subdf.value, label="$(pname), year 2030")
end
xlabel!("Time")
ylabel!("Capacity factor")
```

![wind_profiles](https://hackmd.io/_uploads/SkeWG4DGll.png)

So...the wind built in 2020 has a worse profile. How does it play a role in the investment methods?

### Simple method

Let's try the simple method first.

```julia!
connection = DBInterface.connect(DuckDB.DB)
input_dir = "docs/src/10-tutorials/my-awesome-energy-system/tutorial-6-simple-method"
output_dir = "docs/src/10-tutorials/my-awesome-energy-system/tutorial-6-simple-method/results"
TIO.read_csv_folder(connection, input_dir)
TEM.populate_with_defaults!(connection)
energy_problem = TEM.run_scenario(
        connection;
        model_parameters_file = joinpath(@__DIR__, input_dir, "model-parameters-example.toml"),
        output_folder = output_dir,
    )
```

Check initial capacity - under the simple method, we will not be able to differentiate units built in other years (than milestone years), they will *simply* be considered the same as the units built in the milestone year, which means that we will not use the 2020 profile.

```julia
filter(row -> row.asset=="wind" && row.milestone_year == 2030, TIO.get_table(connection, "asset_both"))
```

Check the objective value and investments.

```julia
energy_problem.objective_value
filter(row -> row.asset=="wind", TIO.get_table(connection, "var_assets_investment"))
```

### Compact method

Now try the compact method.

```julia!
connection = DBInterface.connect(DuckDB.DB)
input_dir = "docs/src/10-tutorials/my-awesome-energy-system/tutorial-6-compact-method"
output_dir = "docs/src/10-tutorials/my-awesome-energy-system/tutorial-6-compact-method/results"
TIO.read_csv_folder(connection, input_dir)
TEM.populate_with_defaults!(connection)
energy_problem = TEM.run_scenario(
        connection;
        model_parameters_file = joinpath(@__DIR__, input_dir, "model-parameters-example.toml"),
        output_folder = output_dir,
    )
```

Check initial capacity - units built in different years are explicitly listed, meaning that their corresponding profiles are also considered.

```julia
filter(row -> row.asset=="wind" && row.milestone_year == 2030, TIO.get_table(connection, "asset_both"))
```

Check the objective value and investments.

```julia
energy_problem.objective_value
filter(row -> row.asset=="wind", TIO.get_table(connection, "var_assets_investment"))
```

We use the worse but correct profile for wind built in 2020, leading to more required investments and hence higher costs.
