# [Tutorial 8: Workflow OBZ Case Study](@id workflow-tutorial)

Tutorial for the Offshore Bidding Zones (OBZ) case study as an example of the full workflow of Tulipa.

!!! warning "Not tested for multi-year"
    Although we use years in the tutorial below, we haven't tried it on a
    multi-year case study. Your experience may vary.

We are basing ourselves on the Tulipa [data pipeline/workflow](@ref data).
To help us navigate this workflow, we'll reproduce the diagram from the link above here.
For more details on the steps of the workflow, check the original link, or follow the tutorial.

![Tulipa Workflow. Textual explanation below.](../figs/tulipa-workflow.jpg)

## Install packages

To follow this tutorial, you need to install some packages:

1. Open `julia` in the folder that you will be working
1. In the `julia` terminal, press `]`. You should see `pkg>`
1. Activate you local environment using `activate .`
1. Install packages with `add <Package1>,<Package2>`, etc. You shouldn't need
   to specify the versions, if this tutorial is up-to-date.

These are the installed packages and their versions:

```@example obz
using Pkg
Pkg.status()
```

## External source

For this tutorial, we'll use the OBZ data. Download it from the [GitHub repo](https://github.com/TulipaEnergy/TulipaEnergyModel.jl/tree/main/docs/src/data/obz) and store it in a folder.

Check <https://github.com/TulipaEnergy/Tulipa-OBZ-CaseStudy> for more information.

These are the files that we are working with:

```@setup obz
# This setup step is hidden from the user. It simply sets the location of the data.
user_input_dir = joinpath(@__DIR__, "..", "data", "obz")
```

```@example obz
# user_input_dir should point to the folder where the data was downloaded and extracted
readdir(user_input_dir)
```

For the Tulipa workflow, we will need to transform some of this data into a specific format.
This can be done externally in whatever tools you are already comfortable with, or through Julia via DuckDB and TulipaIO's convenience functions.

## Create connection

First create a DuckDB connection.

You can create a connection storing the DB locally, or keep everything in-memory only.
Let's assume you want to store the DB, otherwise you can just remove the argument `"obz.db"`.

```@example obz
using DuckDB: DBInterface, DuckDB

# We are staring from a fresh `obz.db` file
rm("obz.db", force=true) # hide
connection = DBInterface.connect(DuckDB.DB, "obz.db")
```

You will be performing various queries with DuckDB. To format them nicely, you can wrap the results in a `DataFrame`:

```@example obz
using DataFrames: DataFrame

nice_query(str) = DataFrame(DuckDB.query(connection, str))
```

## Load data

Once you are done manipulating the data externally, it is time to load it into the DuckDB connection.

This doesn't have to be in Tulipa Format.
It can be whatever data you prefer to manipulate via Julia/DuckDB, instead of externally.

You can load data manually with `DuckDB`, but there is also a convenience function:

```@example obz
using TulipaIO: TulipaIO

TulipaIO.read_csv_folder(
    connection,
    user_input_dir,
    replace_if_exists = true,
)

# The first 5 tables
nice_query("SELECT table_name FROM duckdb_tables() LIMIT 5")
```

## Data processing for instance data with DuckDB/TulipaIO

As we mentioned before, you can process your data externally and then load it.
But you can also use Julia and DuckDB to process the data.

This step is required to prepare the data for TulipaClustering for the
clustering of the profile data.

We need a single profiles table with 4 columns:

- `profile_name`
- `year`
- `timestep`
- `value`

Instead, we have the profiles data in the `profiles` table, which looks something like the following, but with many more columns:

```@example obz
nice_query("SELECT year, timestep, * LIKE 'NL_%' FROM profiles LIMIT 5")
```

The total number of columns in the `profiles` table:

```@example obz
nice_query("SELECT COUNT(*) FROM duckdb_columns() WHERE table_name = 'profiles'")
```

Notice that these are all hourly profiles for the whole year:

```@example obz
nice_query("SELECT year, MAX(timestep) FROM profiles GROUP BY year")
```

So we will transform both this table to long format:

```@example obz
using TulipaClustering: TulipaClustering

TulipaClustering.transform_wide_to_long!(connection, "profiles", "pivot_profiles")

DuckDB.query(
    connection,
    "CREATE OR REPLACE TABLE profiles AS
    FROM pivot_profiles
    ORDER BY profile_name, year, timestep
    "
)

nice_query("SELECT COUNT(*) FROM profiles")
```

Just to showcase this, let's plot all `NL_*` profiles in the first 72 hours of the year:

```@example obz
using Plots

subtable = DuckDB.query(
    connection,
    "SELECT
        timestep,
        value,
        profile_name,
    FROM profiles
    WHERE
        profile_name LIKE 'NL_%'
        AND year=2050
        AND timestep <= 72 -- Just 72 hours
    ORDER BY timestep
    ",
)
df = DataFrame(subtable)
plot(df.timestep, df.value, group=df.profile_name)
```

## Cluster into representative periods using TulipaClustering

Instead of working with the full time horizon of 8760 hours, we will cluster the profiles using [TulipaClustering](https://github.com/TulipaEnergy/TulipaClustering.jl).

You can tweak around the number of representative periods and period duration (and naturally other parameters).
This is the configuration that we'll use:

```@example obz
using Distances: SqEuclidean

## Data for clustering
clustering_params = (
    num_rep_periods = 3,    # number of representative periods
    period_duration = 24,   # hours of the representative period
    method = :k_means,
    distance = SqEuclidean(),
    ## Data for weight fitting
    weight_type = :convex,
    tol = 1e-2,
)
```

PS. We chose to define our `clustering_params` as a `NamedTuple` in Julia, but that is completely optional and you can use whatever structure suits your case.

```@example obz
using Random: Random
Random.seed!(123)
TulipaClustering.cluster!(
    connection,
    clustering_params.period_duration,  # Required
    clustering_params.num_rep_periods;  # Required
    clustering_params.method,           # Optional
    clustering_params.distance,         # Optional
    clustering_params.weight_type,      # Optional
    clustering_params.tol,              # Optional
);
```

These are the tables created by TulipaClustering:

- `rep_periods_data`
- `rep_periods_mapping`
- `profiles_rep_periods`
- `timeframe_data`

## Prepare data for TulipaEnergyModel's format

Now the fun part starts. We need to create specific tables for Tulipa using our current tables.
Again, we remind you that you can create most of these files externally, i.e., you don't have to use DuckDB to join them here.
However, defining the workflow in a programmatic way makes it easier to reproduce it in the future.

We have to define a minimum set of columns for each table, and then the remaining columns will be filled with defaults.
Some columns cannot contain missing values (such as the `asset` or `year` columns in most tables).
For other columns, missing values will be filled with the columns' default.

!!! warning "Populating with defaults is an explicit step"
    As we'll see in the end of this section, populating the remaining columns with default values is an explicit step and can only be skipped if your data is already correct.

### Year data

This data is already correct in the case study and contains a single year.

```@example obz
nice_query("FROM year_data")
```

### Assets

First, let's join all assets' basic data.
This table goes directly into the `asset` table for Tulipa.

```@example obz
DuckDB.query(
    connection,
    "CREATE TABLE asset AS
    SELECT
        name AS asset,
        type,
        capacity,
        capacity_storage_energy,
        is_seasonal,
    FROM (
        FROM assets_consumer_basic_data
        UNION BY NAME
        FROM assets_conversion_basic_data
        UNION BY NAME
        FROM assets_hub_basic_data
        UNION BY NAME
        FROM assets_producer_basic_data
        UNION BY NAME
        FROM assets_storage_basic_data
    )
    ORDER BY asset
    ",
)

nice_query("FROM asset ORDER BY random() LIMIT 5")
```

Similarly, we join the assets' yearly data:

```@example obz
DuckDB.query(
    connection,
    "CREATE TABLE t_asset_yearly AS
    FROM (
        FROM assets_consumer_yearly_data
        UNION BY NAME
        FROM assets_conversion_yearly_data
        UNION BY NAME
        FROM assets_hub_yearly_data
        UNION BY NAME
        FROM assets_producer_yearly_data
        UNION BY NAME
        FROM assets_storage_yearly_data
    )
    ",
)

nice_query("FROM t_asset_yearly ORDER BY random() LIMIT 5")
```

Then, the `t_asset_yearly` table is used to create the three other asset tables that Tulipa requires:

```@example obz
DuckDB.query(
    connection,
    "CREATE TABLE asset_commission AS
    SELECT
        name AS asset,
        year AS commission_year,
    FROM t_asset_yearly
    ORDER by asset
    "
)

DuckDB.query(
    connection,
    "CREATE TABLE asset_milestone AS
    SELECT
        name AS asset,
        year AS milestone_year,
        peak_demand,
        initial_storage_level,
        storage_inflows,
    FROM t_asset_yearly
    ORDER by asset
    "
)

DuckDB.query(
    connection,
    "CREATE TABLE asset_both AS
    SELECT
        name AS asset,
        year AS milestone_year,
        year AS commission_year, -- Yes, it is the same year twice with different names because it's not a multi-year problem
        initial_units,
        initial_storage_units,
    FROM t_asset_yearly
    ORDER by asset
    "
)
```

Here is an example of one of these tables:

```@example obz
nice_query("FROM asset_both WHERE initial_storage_units > 0 LIMIT 5")
```

### Flows

We repeat the steps above for flows:

```@example obz
DuckDB.query(
    connection,
    "CREATE TABLE flow AS
    SELECT
        from_asset,
        to_asset,
        carrier,
        capacity,
        is_transport,
    FROM (
        FROM flows_assets_connections_basic_data
        UNION BY NAME
        FROM flows_transport_assets_basic_data
    )
    ORDER BY from_asset, to_asset
    ",
)

DuckDB.query(
    connection,
    "CREATE TABLE t_flow_yearly AS
    FROM (
        FROM flows_assets_connections_yearly_data
        UNION BY NAME
        FROM flows_transport_assets_yearly_data
    )
    ",
)

DuckDB.query(
    connection,
    "CREATE TABLE flow_commission AS
    SELECT
        from_asset,
        to_asset,
        year AS commission_year,
        efficiency AS producer_efficiency,
    FROM t_flow_yearly
    ORDER by from_asset, to_asset
    "
)

DuckDB.query(
    connection,
    "CREATE TABLE flow_milestone AS
    SELECT
        from_asset,
        to_asset,
        year AS milestone_year,
        variable_cost AS operational_cost,
    FROM t_flow_yearly
    ORDER by from_asset, to_asset
    "
)

DuckDB.query(
    connection,
    "CREATE TABLE flow_both AS
    SELECT
        t_flow_yearly.from_asset,
        t_flow_yearly.to_asset,
        t_flow_yearly.year AS milestone_year,
        t_flow_yearly.year AS commission_year,
        t_flow_yearly.initial_export_units,
        t_flow_yearly.initial_import_units,
    FROM t_flow_yearly
    LEFT JOIN flow
      ON flow.from_asset = t_flow_yearly.from_asset
      AND flow.to_asset = t_flow_yearly.to_asset
    WHERE flow.is_transport = TRUE -- flow_both must only contain transport flows
    ORDER by t_flow_yearly.from_asset, t_flow_yearly.to_asset
    "
)
```

### Assets profiles

The `assets_profiles` table already exists, so we only need to create `assets_timeframe_profiles`.
Since all the data is already in `assets_storage_min_max_reservoir_level_profiles`, we just copy it over.

```@example obz
DuckDB.query(
    connection,
      "CREATE TABLE assets_timeframe_profiles AS
      SELECT
        asset,
        commission_year AS year,
        profile_type,
        profile_name
      FROM assets_storage_min_max_reservoir_level_profiles
      ORDER BY asset, year, profile_name
      ",
)
```

### Partitions

The OBZ table uses only uniform time partitions, which makes it easy to create the necessary tables.

For the `assets_rep_periods_partitions`, we simply have to copy the `partition` given by the assets' yearly data for each representative period given `rep_periods_data.rep_period` and attach a `specification = 'uniform'` to that table.

```@example obz
DuckDB.query(
    connection,
    "CREATE TABLE assets_rep_periods_partitions AS
    SELECT
        t.name AS asset,
        t.year,
        t.partition AS partition,
        rep_periods_data.rep_period,
        'uniform' AS specification,
    FROM t_asset_yearly AS t
    LEFT JOIN rep_periods_data
        ON t.year = rep_periods_data.year
    ORDER BY asset, t.year, rep_period
    ",
)
```

For the `flows_rep_periods_partitions`, we need to also compute the expected `partition` value, which will follow a simple formula.
Given a flow `(from_asset, to_asset)`, we look at the partition of both `from_asset` and `to_asset`.
If the flow is a transport flow, we use the **maximum** between the partitions of `from_asset` and `to_asset`.
Otherwise, we use the **minimum** between these two.

```@example obz
DuckDB.query(
    connection,
    "CREATE TABLE flows_rep_periods_partitions AS
    SELECT
        flow.from_asset,
        flow.to_asset,
        t_from.year,
        t_from.rep_period,
        'uniform' AS specification,
        IF(
            flow.is_transport,
            greatest(t_from.partition::int, t_to.partition::int),
            least(t_from.partition::int, t_to.partition::int)
        ) AS partition,
    FROM flow
    LEFT JOIN assets_rep_periods_partitions AS t_from
        ON flow.from_asset = t_from.asset
    LEFT JOIN assets_rep_periods_partitions AS t_to
        ON flow.to_asset = t_to.asset
        AND t_from.year = t_to.year
        AND t_from.rep_period = t_to.rep_period
    ",
)
```

### Timeframe profiles

For the `timeframe` profiles, we'll use the other profiles table that we haven't touched yet: `min_max_reservoir_levels`.
As with the other profiles, we will first pivot that table to have it in long format.
However, we do not cluster these profiles, since the representative periods are already computed.
Instead, we will create a temporary table (`cte_split_profiles`) that converts the `timestep` that goes from 1 to 8760 into two columns:
`period`, from to 1 to 365 (days) and `timestep`, from 1 to 24 (hours).

Finally, the `timeframe` profiles are computed with the average over `period`, i.e., each value of a given timeframe profile in a `period` is the average of 24 hours of the original profile.

```@example obz
TulipaClustering.transform_wide_to_long!(
    connection,
    "min_max_reservoir_levels",
    "pivot_min_max_reservoir_levels",
)

period_duration = clustering_params.period_duration

DuckDB.query(
    connection,
    "
    CREATE TABLE profiles_timeframe AS
    WITH cte_split_profiles AS (
        SELECT
            profile_name,
            year,
            1 + (timestep - 1) // $period_duration  AS period,
            1 + (timestep - 1)  % $period_duration AS timestep,
            value,
        FROM pivot_min_max_reservoir_levels
    )
    SELECT
        cte_split_profiles.profile_name,
        cte_split_profiles.year,
        cte_split_profiles.period,
        AVG(cte_split_profiles.value) AS value, -- Computing the average aggregation
    FROM cte_split_profiles
    GROUP BY
        cte_split_profiles.profile_name,
        cte_split_profiles.year,
        cte_split_profiles.period
    ORDER BY
        cte_split_profiles.profile_name,
        cte_split_profiles.year,
        cte_split_profiles.period
    ",
)
```

### [Populate with defaults](@id obz-populate-with-defaults)

Finally, in many cases, you will need to complete the missing columns with additional information.
To simplify this process, we created the `populate_with_defaults!` function.
Please read TulipaEnergyModel's [populate with default section](@ref minimum-data) for a complete picture.

Here is the before of one of the tables:

```@example obz
nice_query("FROM asset_both LIMIT 5")
```

```@example obz
using TulipaEnergyModel: TulipaEnergyModel as TEM

TEM.populate_with_defaults!(connection)
```

```@example obz
nice_query("FROM asset_both LIMIT 5")
```

## Create internal tables for the model indices

!!! warning "If you skipped ahead"
    If you skipped ahead and have errors here, check out some of the previous steps.
    Notably, [populating with defaults](@ref obz-populate-with-defaults) helps solve many issues with missing data and wrong types in the columns.

!!! info "More general option: run_scenario"
    We split the TulipaEnergyModel part in a few parts, however all these things could be achieved using [`run_scenario`](@ref) directly instead.
    We leave the details out of this tutorial to keep it more instructional.

```@example obz
energy_problem = TEM.EnergyProblem(connection)
```

Purely out of curiosity, here is the total number of tables that we have:

```@example obz
nice_query("SELECT COUNT(*) as num_tables, FROM duckdb_tables()")
```

## Create model

Finally, we get to actually use the model.

```@example obz
model_file_name = joinpath(@__DIR__, "..", "..", "new-model.lp") # hide
optimizer_parameters = Dict(
    "output_flag" => true,
    "mip_rel_gap" => 0.0,
    "mip_feasibility_tolerance" => 1e-5,
)
TEM.create_model!(energy_problem; model_file_name, optimizer_parameters)
```

## Solve model

Last, but not least important, we solve the model:

```@example obz
TEM.solve_model!(energy_problem)
```

## Store primal and dual solution

The primal and dual solutions are computed when saving the solution with `save_solution!`, as long as we don't change the default value of `compute_duals`.
Here it is, explicitly:

```@example obz
TEM.save_solution!(energy_problem; compute_duals = true)
```

Now every variable indices table has a column `solution`, and every constraint has additional columns `dual_*`, depending on the constraints name.

### Examples checking the primal and dual solutions

Select all variables of storage level at representative periods with value greater than 0 at the solution (show only first 5):

```@example obz
nice_query("SELECT *
    FROM var_storage_level_rep_period
    WHERE solution > 0
    LIMIT 5
")
```

Select all indices related to the balance storage at representative periods when both `min_storage_level_rep_period_limit` and `max_storage_level_rep_period_limit` have duals equal to 0.

```@example obz
nice_query("SELECT *
    FROM cons_balance_storage_rep_period
    WHERE dual_max_storage_level_rep_period_limit = 0
        AND dual_min_storage_level_rep_period_limit = 0
    LIMIT 5
")
```

## Data processing for plots and dashboard

This part of the workflow is open for you to do whatever you need.
In principle, you can skip this step and go straight to [exporting the solution](@ref step-export), and then perform your analysis of the solution outside of the DuckDB/Julia environment.

Here is an example of data processing using DuckDB and Julia.

The table

```@example obz
nice_query("
CREATE TEMP TABLE analysis_inter_storage_levels AS
SELECT
    var.id,
    var.asset,
    var.period_block_start as period,
    asset.capacity_storage_energy,
    var.solution / (
        IF(asset.capacity_storage_energy > 0, asset.capacity_storage_energy, 1)
    ) AS SoC,
FROM var_storage_level_over_clustered_year AS var
LEFT JOIN asset
    ON var.asset = asset.asset
")
nice_query("FROM analysis_inter_storage_levels LIMIT 5")
```

## Create plots

Now, using the analysis tables from above, we can create plots in Julia:

```@example obz
using Plots

p = plot()
assets = ["ES_Hydro_Reservoir", "NO_Hydro_Reservoir", "FR_Hydro_Reservoir"]

df = nice_query("SELECT asset, period, SoC
    FROM analysis_inter_storage_levels
    WHERE asset in ('ES_Hydro_Reservoir', 'NO_Hydro_Reservoir', 'FR_Hydro_Reservoir')
")

plot!(
    df.period,          # x-axis
    df.SoC,             # y-axis
    group = df.asset,   # each asset is a different plot
    xlabel = "Period",
    ylabel = "Storage level [p.u.]",
    linewidth = 3,
    dpi = 600,
)
```

## [Export solution](@id step-export)

Finally, we can export the solution to CSV files using the convenience function below:

```@example obz
if !isdir("obz-outputs") # hide
mkdir("obz-outputs")
TEM.export_solution_to_csv_files("obz-outputs", energy_problem)
end # hide
readdir("obz-outputs")
```

Using DuckDB directly it is also possible to export to other formats, such as Parquet.

Finally, we close the connection. It should also be closed automatically if the `connection` variable goes out of scope.

```@example obz
close(connection)
```
