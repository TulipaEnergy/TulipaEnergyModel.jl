# [Input Table Schemas](@id table-schemas)

The input data must follow the table schemas below to correctly build a system in Tulipa.

The schemas below are in [`input-schemas.json`](https://github.com/TulipaEnergy/TulipaEnergyModel.jl/blob/main/src/input-schemas.json). You can also view the schemas after loading the package by typing `TulipaEnergyModel.schema` in the Julia console.

!!! info "Optional tables/files and their defaults"
    The table below summarizes the optional tables/files and their default values. If a table/file is missing, the default value will be used.

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
using TulipaEnergyModel

input_schemas = JSON.parsefile("../../../src/input-schemas.json"; dicttype = OrderedDict)

let buffer = IOBuffer()
    optional_tables = Set(TulipaEnergyModel.tables_allowed_to_be_missing)

    mandatory_columns_per_table = [
        (
            table_name = table_name,
            mandatory_columns = [
                field_name for (field_name, field_info) in fields if !haskey(field_info, "default")
            ],
            is_optional = table_name in optional_tables,
        ) for (table_name, fields) in input_schemas
    ]

    summary_table_header = (
        "Table",
        "Optional (allowed to be missing)",
        "Mandatory columns (no defaults)",
    )
    summary_table_rows = [
        (
            "`$table_name`",
            is_optional ? "True" : "False",
            join(["`$field_name`" for field_name in mandatory_columns], ", "),
        ) for (;
            table_name,
            mandatory_columns,
            is_optional,
        ) in mandatory_columns_per_table
    ]
    col_1_width = maximum(length.([summary_table_header[1]; [row[1] for row in summary_table_rows]]))
    col_2_width = maximum(length.([summary_table_header[2]; [row[2] for row in summary_table_rows]]))
    col_3_width = maximum(length.([summary_table_header[3]; [row[3] for row in summary_table_rows]]))

    write(buffer, "## Mandatory columns by table\n\n")
    write(
        buffer,
        "| $(rpad(summary_table_header[1], col_1_width)) | $(rpad(summary_table_header[2], col_2_width)) | $(rpad(summary_table_header[3], col_3_width)) |\n",
    )
    write(
        buffer,
        "| $(repeat("-", col_1_width)) | $(repeat("-", col_2_width)) | $(repeat("-", col_3_width)) |\n",
    )
    for (table_name, optional_status, mandatory_columns) in summary_table_rows
        write(
            buffer,
            "| $(rpad(table_name, col_1_width)) | $(rpad(optional_status, col_2_width)) | $(rpad(mandatory_columns, col_3_width)) |\n",
        )
    end
    write(buffer, "\n")

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
