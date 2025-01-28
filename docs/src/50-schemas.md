# [Model Parameters](@id schemas)

The optimization model parameters with the input data must follow the schema below for each table. To create these tables we currently use CSV files that follow this same schema and then convert them into tables using TulipaIO, as shown in the basic example of the [Tutorials](@ref basic-example) section.

The schemas can be accessed at any time after loading the package by typing `TulipaEnergyModel.schema_per_table_name` in the Julia console. Here is the complete list of model parameters in the schemas per table (or CSV file):

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
