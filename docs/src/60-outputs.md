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
