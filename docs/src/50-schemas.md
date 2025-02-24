# [Input Schemas](@id schemas)

## User Schema

## Model Schema

The optimization model parameters with the input data must follow the schema below for each table. To create these tables we currently use CSV files that follow this same schema and then convert them into tables using TulipaIO, as shown in the basic example of the [Tutorials](@ref basic-example) section.

The schemas can be accessed at any time after loading the package by typing `TulipaEnergyModel.schema_per_table_name` in the Julia console. Here is the complete list of model parameters in the schemas per table (or CSV file):

!!! info "Optional tables/files and their defaults"
The following tables/files are allowed to be missing: - "assets_rep_periods_partitions", - "assets_timeframe_partitions", "assets_timeframe_profiles", "flows_rep_periods_partitions", "group_asset", "profiles_timeframe". - For the partitions tables/files, the default value are `specification = uniform` and `partition = 1` for each asset/flow and year - For the profiles tables/files, the default value is a flat profile of value 1.0 p.u. - If no group table/file is available there will be no group constraints in the model

```@eval
using Markdown, TulipaEnergyModel

Markdown.parse(
    join(["- **`$filename`**\n" *
        join(
            ["  - `$f: $t`" for (f, t) in schema],
            "\n",
        ) for (filename, schema) in TulipaEnergyModel.schema_per_table_name
    ] |> sort, "\n")
)
```
