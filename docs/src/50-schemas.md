# [Data pipeline/workflow](@id data)

---
TODO:

- diagrams
- Replace
  > To create these tables we currently use CSV files that follow this same schema and then convert them into tables using TulipaIO, as shown in the basic example of the [Tutorials](@ref basic-example) section.
- Review below

---

Tulipa uses a DuckDB database to store the input data, the representation of variables, constraints, and other internal tables, as well as the output.
This database is informed through the `connection` argument in various parts of the API. Most notably, for [`run_scenario`](@ref) and [`EnergyProblem`](@ref).

## [Minimum data and using defaults](@id minimum_data)

Since `TulipaEnergyModel` is at a late stage in the workflow, its input data requirements are stricter.
Therefore, the input data required by the Tulipa model must follow the schema in the follow section.

Dealing with defaults is hard. A missing value might represent two different things to different people. That is why we require the tables to be complete.
However, we also understand that it is not reasonable to expect people to fill a lot of things that they don't need for their models.
Therefore, we have created the function [`populate_with_defaults!`](@ref) to fill the remaining columns of your tables with default values.

To know the defaults, check the table [Schemas](@ref schemas) below.

!!! warning "Beware implicit assumptions"
    When data is missing and you automatically fill it with defaults, beware of your assumptions on what that means.
    Check what are the default values and decide if you want to use them or not.
    If you think a default does not make sense, open an issue, or a discussion thread.

### Example of using `populate_with_defaults!`

```@example
using TulipaEnergyModel, TulipaIO, DuckDB
```

## Namespaces

After creating a `connection` and loading data in a way that follows the schema (see the previous section on [minimum data](@ref minimum_data)), then Tulipa will create tables to handle the model data and various internal tables.
To differentiate between these tables, we use a prefix. This should also help differentiate between the data you might want to create yourself.
Here are the different namespaces:

- `input_`: Tables expected by `TulipaEnergyModel`.
- `var_`: Variable indices.
- `cons_`: Constraints indices.
- `expr_`: Expressions indices.
- `resolution_`: Unrolled partition blocks of assets and flows.
- `t_*`: Temporary tables.

## [Schemas](@id schemas)

The optimization model parameters with the input data must follow the schema below for each table.

The schemas can be found in the `input-schemas.json`. For more advanced users, they can also access the schemas at any time after loading the package by typing `TulipaEnergyModel.schema_per_table_name` in the Julia console. Here is the complete list of model parameters in the schemas per table (or CSV file):

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
  •  Unit of measure: a value or "No unit"
  •  Constraints: a table or "No constraints"
"""

using Markdown, JSON
using OrderedCollections: OrderedDict

input_schemas = JSON.parsefile("../../src/input-schemas.json"; dicttype = OrderedDict)

let buffer = IOBuffer()
    for (i,(table_name, fields)) in enumerate(input_schemas)
        write(buffer, "## Table $i : `$table_name`\n\n")
        for (field_name, field_info) in fields
            _description = get(field_info, "description", "No description provided")
            _type = get(field_info, "type", "Unknown type")
            _unit = get(field_info, "unit_of_measure", "No unit")
            _default = get(field_info, "default", "No default")
            _constraints_values = get(field_info, "constraints", nothing)

            write(buffer, "**`$field_name`**\n\n")
            write(buffer, "- Description: $_description\n\n")
            write(buffer, "- Type: `$_type`\n")
            write(buffer, "- Unit of measure: `$_unit` \n")
            write(buffer, "- Default: `$_default`\n")

            if _constraints_values === nothing
                write(buffer, "- Constraints: No constraints\n")
            elseif isa(_constraints_values, OrderedDict)
                write(buffer, "| Constraints | Value |\n| --- | --- |\n")
                for (key, value) in _constraints_values
                    write(buffer, "| $key | `$value` |\n")
                end
                write(buffer, "\n")
            else
                write(buffer, "- Constraints: `$(string(_constraints_values))`\n")
            end
        end
    end
    Markdown.parse(String(take!(buffer)))
end

```
