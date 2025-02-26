# [Model Parameters](@id schemas)

The optimization model parameters with the input data must follow the schema below for each table. To create these tables we currently use CSV files that follow this same schema and then convert them into tables using TulipaIO, as shown in the basic example of the [Tutorials](@ref basic-example) section.

The schemas can be found in the `input-schemas.json` or can be accessed at any time after loading the package by typing `TulipaEnergyModel.schema_per_table_name` in the Julia console. Here is the complete list of model parameters in the schemas per table (or CSV file):

!!! info "Optional tables/files and their defaults"
    The following tables/files are allowed to be missing: "assets\_rep\_periods\_partitions", "assets\_timeframe\_partitions", "assets\_timeframe\_profiles", "flows\_rep\_periods\_partitions", "group\_asset", "profiles\_timeframe".
    - For the partitions tables/files, the default value are `specification = uniform` and `partition = 1` for each asset/flow and year
    - For the profiles tables/files, the default value is a flat profile of value 1.0 p.u.
    - If no group table/file is available there will be no group constraints in the model

```@eval
"""
The output of the following code is a Markdown text with the following structure:

TABLE_NAME
=========

PARAMETER_NAME

  •  Description: Lorem ipsum
  •  Type: SQL type of the parameter
  •  Default: a value or "No default"
  •  Unit of measure: a value or "-"
  •  Constraints: a table or "No constraints"
"""

using Markdown, JSON
using OrderedCollections: OrderedDict

input_schemas = JSON.parsefile("../../src/input-schemas.json"; dicttype = OrderedDict)

let buffer = IOBuffer()
    for (i,(table_name, fields)) in enumerate(input_schemas)
        write(buffer, "## Table $i : `$table_name`\n\n")
        for (field_name, field_info) in fields
            desc = get(field_info, "description", "No description provided")
            typ = get(field_info, "type", "Unknown type")
            unit = get(field_info, "UoM", "-")
            default = get(field_info, "default", "No default")
            constraints_val = get(field_info, "constraints", nothing)

            write(buffer, "**`$field_name`**\n\n")
            write(buffer, "- Description: $desc\n\n")
            write(buffer, "- Type: `$typ`\n")
            write(buffer, "- Unit of measure: `$unit` \n")
            write(buffer, "- Default: `$default`\n")

            if constraints_val === nothing
                write(buffer, "- Constraints: No constraints\n")
            elseif isa(constraints_val, OrderedDict)
                write(buffer, "| Constraints | Value |\n| --- | --- |\n")
                for (key, value) in constraints_val
                    write(buffer, "| $key | `$value` |\n")
                end
                write(buffer, "\n")
            else
                write(buffer, "- Constraints: `$(string(constraints_val))`\n")
            end
        end
    end
    Markdown.parse(String(take!(buffer)))
end

```
