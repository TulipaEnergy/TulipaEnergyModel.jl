# [Output Variables](@id outputs)

Tulipa's user workflow is a work-in-progress. For now, you can export the complete raw solution to CSV files using [`TulipaEnergyModel.export_solution_to_csv_files`](@ref).
Below is a description of the exported data. Files may be missing if the associated features were not included in the analysis.

```@contents
Pages = ["55-outputs.md"]
Depth = [2, 3]
```

## Output Tables Format

There are two types of outputs:

1. **Variables:** All tables/files starting with `var_`show the values of variables in the optimal solution, with leading columns specifying the indices of each `solution` value.

1. **Duals:** All tables/files starting with `cons_` show the dual value in the optimal solution for each constraint, with leading columns specifying the indices of each `dual` value. Remember that the dual represents *the incremental change in the optimal solution per unit increase in the right-hand-side (bound) of the constraint* - which in a minimal cost optimisation corresponds to an increase in cost.

!!! note "Units"
    TulipaEnergyModel is inherently unitless, meaning the units are directly taken from the input data. For example, if all costs are given in thousands of euros, then the objective function is also in thousands of euros. So a "change in the objective function" would mean a €1k increase/decrease.

Each output table has three types of columns:

1. Indices: Parameters on which the output variable or dual is indexed, including:
   - `asset`: Unique name of the asset.
   - `from_asset`: For a flow, the origin asset.
   - `to_asset`: For a flow, the terminal asset.
   - `year`: Equivalent to `milestone_year`. (Will be fixed in future release.)
   - `milestone_year`: Year of investment and operation decisions.
   - `commission_year`: Commissioning year of an asset (used for unique asset identification).
   - `rep_period`: Number of the representative period.
   - `time_block_start`: Start of the time block of the representative period.
   - `time_block_end`: End of the time block of the representative period.
   - `period_block_start`: Start of the time block of the timeframe (mostly relevant for seasonal storage).
   - `period_block_end`: Start of the time block of the timeframe (mostly relevant for seasonal storage).
2. Associated [input parameters](@ref schemas): Listed per table below
3. `Solution` or `dual_constraint_name`: Value of the variable or dual in the solution, described below.

## Variable Tables

### `var_assets_decommission_energy`

For a storage asset that has `storage_method_energy` commissioned in `commission_year`, the optimal decommissioning (decrease) of asset energy capacity in `milestone_year`, expressed in the same units as `capacity_storage_energy` of asset.

Associated input parameters: `investment_integer_storage_energy`, `capacity_storage_energy`

### `var_assets_decommission`

For an asset commissioned in `commission_year`, the optimal decommissioning (decrease) of asset capacity in `milestone_year`, expressed in the same units as `capacity` of asset.

Associated input parameters: `decommissionable`, `initial_units`, `investment_integer`, `capacity`

### `var_assets_investment_energy`

For a storage asset that has `storage_method_energy`, the optimal investment (increase) in asset energy capacity in `milestone_year`, expressed in the same units as `capacity_storage_energy` of asset.

Associated input parameters: `investable`, `investment_integer_storage_energy`, `capacity_storage_energy`, `investment_limit_storage_energy`

### `var_assets_investment`

For an asset, the optimal investment (increase) in asset capacity in `milestone_year`, expressed in the same units as `capacity` of asset.

Associated input parameters: `investable`, `investment_integer`, `capacity`, `investment_limit`

### `var_flow`

For a flow, the optimal flow (of energy) during a particular `rep_period` between `time_block_start` and `time_block_end`, expressed in the same units as `capacity` of flow.

Associated input parameter: `efficiency`

### `var_flows_decommission`

For a transport flow commissioned in `commission_year`, the optimal decommissioning (decrease) of flow capacity in `milestone_year`, expressed in the same units as `capacity` of flow.

Associated input parameter: `decommissionable`, `investment_integer`, `capacity`

### `var_flows_investment`

For a transport flow, the optimal investment (increase) in flow capacity in `milestone_year`, expressed in the same units as `capacity` of flow.

Associated input parameters: `investable`, `investment_integer`, `capacity`, `investment_limit`

### `var_storage_level_over_clustered_year`

For a storage asset in a specific `year` and between `period_start` and `period_end`, the optimal storage level BETWEEN representative periods, expressed in the same units as `capacity_storage_energy` of asset.

### `var_storage_level_rep_period`

For a storage asset in a specific `year` and between `period_start` and `period_end`, the optimal storage level WITHIN representative periods, expressed in the same units as `capacity_storage_energy` of asset.

### `var_units_on`

For an asset, the optimal dispatch (operation) during a particular `rep_period` between `time_block_start` and `time_block_end`, expressed in the same units as `capacity` of asset.

Associated input parameter: `unit_commitment_integer`

## Constraint Dual Tables

### `cons_balance_hub`

- `dual_balance_hub`: Dual of the constraint ["balance constraint for hubs"](https://tulipaenergy.github.io/TulipaEnergyModel.jl/stable/40-formulation/#Balance-Constraint-for-Hubs).

### `cons_balance_consumer`

- `dual_balance_consumer`: Dual of the constraint ["balance constraint for consumers"](https://tulipaenergy.github.io/TulipaEnergyModel.jl/stable/40-formulation/#Balance-Constraint-for-Consumers).

### `cons_balance_conversion`

- `dual_balance_conversion`: Dual of the constraint ["balance constraint for conversion assets"](https://tulipaenergy.github.io/TulipaEnergyModel.jl/stable/40-formulation/#Balance-Constraint-for-Conversion-Assets).

### `cons_balance_storage_over_clustered_year`

- `dual_balance_storage_over_clustered_year`: Dual of the constraint ["over-clustered-year constraint for storage balance"](https://tulipaenergy.github.io/TulipaEnergyModel.jl/stable/40-formulation/#over-clustered-year-storage-balance).
- `dual_max_storage_level_over_clustered_year_limit`: Dual of the constraint ["over-clustered-year constraint for maximum storage level limit"](https://tulipaenergy.github.io/TulipaEnergyModel.jl/stable/40-formulation/#Over-clustered-year-Constraint-for-Maximum-Storage-Level-Limit)
- `dual_min_storage_level_over_clustered_year_limit`: Dual of the constraint ["over-clustered-year constraint for minimum storage level limit"](https://tulipaenergy.github.io/TulipaEnergyModel.jl/stable/40-formulation/#Over-clustered-year-Constraint-for-Minimum-Storage-Level-Limit)

### `cons_balance_storage_rep_period`

- `dual_balance_storage_rep_period`: Dual of the constraint ["rep-period constraint for storage balance"](https://tulipaenergy.github.io/TulipaEnergyModel.jl/stable/40-formulation/#rep-period-storage-balance).
- `dual_max_storage_level_rep_period_limit`: Dual of the constraint ["rep-period constraint for maximimum storage level limit"](https://tulipaenergy.github.io/TulipaEnergyModel.jl/stable/40-formulation/#Rep-period-Constraint-for-Maximum-Storage-Level-Limit)
- `dual_min_storage_level_rep_period_limit`: Dual of the constraint ["rep-period constraint for minimum storage level limit"](https://tulipaenergy.github.io/TulipaEnergyModel.jl/stable/40-formulation/#Rep-period-Constraint-for-Minimum-Storage-Level-Limit)

### `cons_capacity_incoming`

- `dual_max_input_flows_limit`: Dual of the constraint ["maximum input flows limit"](https://tulipaenergy.github.io/TulipaEnergyModel.jl/stable/40-formulation/#Maximum-Input-Flows-Limit).

### `cons_capacity_outgoing`

- `dual_max_output_flows_limit`: Dual of the constraint ["maximum output flows limit"](https://tulipaenergy.github.io/TulipaEnergyModel.jl/stable/40-formulation/#Maximum-Output-Flows-Limit).

### `cons_limit_units_on`

- `dual_limit_units_on`: Dual of the constraint ["limit to the units on variable"](https://tulipaenergy.github.io/TulipaEnergyModel.jl/stable/40-formulation/#Limit-to-the-units-on-variable).

Associated input parameter: `unit_commitment_integer`

### `cons_max_output_flow_with_basic_unit_commitment`

- `dual_max_output_flow_with_basic_unit_commitment`: Dual of the constraint ["maximum output flow above the minimum operating point"](https://tulipaenergy.github.io/TulipaEnergyModel.jl/stable/40-formulation/#Maximum-output-flow-above-the-minimum-operating-point).

### `cons_max_ramp_with_unit_commitment`

- `dual_max_ramp_up_with_unit_commitment`: Dual of the constraint ["maximum ramp-up rate limit WITH unit commitment"](https://tulipaenergy.github.io/TulipaEnergyModel.jl/stable/40-formulation/#Maximum-Ramp-Up-Rate-Limit-WITH-Unit-Commitment-Method).
- `dual_max_ramp_down_with_unit_commitment`: Dual of the constraint ["maximum ramp-down rate limit with unit commitment"](https://tulipaenergy.github.io/TulipaEnergyModel.jl/stable/40-formulation/#Maximum-Ramp-Down-Rate-Limit-WITH-Unit-Commmitment-Method).

### `cons_min_output_flow_with_unit_commitment`

- `dual_min_output_flow_with_unit_commitment`: Dual of the constraint ["minimum output flow above the minimum operating point"](https://tulipaenergy.github.io/TulipaEnergyModel.jl/stable/40-formulation/#Minimum-output-flow-above-the-minimum-operating-point).

### `cons_transport_flow_limit`

- `dual_max_transport_flow_limit`: Dual of the constraint ["maximum transport flow limit"](https://tulipaenergy.github.io/TulipaEnergyModel.jl/stable/40-formulation/#Maximum-Transport-Flow-Limit).
- `dual_min_transport_flow_limit`: Dual of the constraint ["minimum transport flow limit"](https://tulipaenergy.github.io/TulipaEnergyModel.jl/stable/40-formulation/#Minimum-Transport-Flow-Limit).

Associated parameter: `var_flow_id`: Unique flow ID used internally by TulipaEnergyModel.
