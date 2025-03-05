# [Model Parameters](@id schemas)

The optimization model parameters with the input data must follow the schema below for each table. To create these tables we currently use CSV files that follow this same schema and then convert them into tables using TulipaIO, as shown in the basic example of the [Tutorials](@ref basic-example) section.

The schemas can be accessed at any time after loading the package by typing `TulipaEnergyModel.schema_per_table_name` in the Julia console. Here is the complete list of model parameters in the schemas per table (or CSV file):

!!! info "Optional tables/files and their defaults"
    The following tables/files are allowed to be missing: "assets\_rep\_periods\_partitions", "assets\_timeframe\_partitions", "assets\_timeframe\_profiles", "flows\_rep\_periods\_partitions", "group\_asset", "profiles\_timeframe".
    - For the partitions tables/files, the default value are `specification = uniform` and `partition = 1` for each asset/flow and year
    - For the profiles tables/files, the default value is a flat profile of value 1.0 p.u.
    - If no group table/file is available there will be no group constraints in the model

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
