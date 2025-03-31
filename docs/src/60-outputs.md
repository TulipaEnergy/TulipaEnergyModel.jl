# [Model Output](@id outputs)

```@contents
Pages = ["60-output-variables.md"]
Depth = [2, 3]
```

Tulipa's user workflow is a work-in-progress. For now, you can export the complete raw solution to CSV files using [`TulipaEnergyModel.export_solution_to_csv_files`](@ref).
Below is a description of the exported data. Files may be missing if the associated features were not included in the analysis.

There are two types of outputs:

1. **Variables:** All tables/files starting with `var_`show the values of variables in the optimal solution, with leading columns specifying the indices of each `solution` value.

1. **Duals:** All tables/files starting with `cons_` show the dual value in the optimal solution for each constraint, with leading columns specifying the indices of each `dual` value. Remember that the dual represents *the incremental change in the optimal solution per unit increase in the right-hand-side (bound) of the constraint* - which in a minimal cost optimisation corresponds to an increase in cost.

!!! note "Units"
    TulipaEnergyModel is inherently unitless, meaning the units are directly taken from the input data. For example, if all costs are given in thousands of euros, then the objective function is also in thousands of euros. So a "change in the objective function" would mean a €1k increase/decrease.

```@eval
"""
The output of the following code is a Markdown text with the following structure:

TABLE_NAME
=========

TABLE_NAME

  •  index columns: [list]
  •  model parameters: [list]
  •  solution or dual_constraint_name: Description

"""

using Markdown, JSON
using OrderedCollections: OrderedDict

input_schemas = JSON.parsefile("outputs.json"; dicttype = OrderedDict)

let buffer = IOBuffer()
  for (i, (table_name, fields)) in enumerate(input_schemas)
      write(buffer, "**`$table_name`**\n\n")

      for (field_name, field_value) in fields
        if field_name == "index columns" || field_name == "model parameters"
              write(buffer, "- $field_name:  ")
              write(buffer, "`$field_value`\n\n")
        else
              write(buffer, "- `$field_name`:  ")
              write(buffer, "$field_value\n\n")
        end
      end
  end
  Markdown.parse(String(take!(buffer)))
end
```
