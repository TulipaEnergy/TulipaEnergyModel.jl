# [Model Output](@id outputs)

Tulipa's user workflow is a work-in-progress. For now, you can export the complete raw solution to CSV files using [`TulipaEnergyModel.export_solution_to_csv_files`](@ref).
Below is a description of the exported data. Files may be missing if the associated features were not included in the analysis.

There are two types of outputs:

1. **Variables:** All tables/files starting with `var_`show the values of variables in the optimal solution, with leading columns specifying the indices of each `solution` value.

1. **Duals:** All tables/files starting with `cons_` show the dual value in the optimal solution for each constraint, with leading columns specifying the indices of each `dual` value. Remember that the dual represents *the incremental change in the optimal solution per unit increase in the right-hand-side (bound) of the constraint* - which in a minimal cost optimisation corresponds to an increase in cost.

!!! note "Units"
    TulipaEnergyModel is inherently unitless, meaning the units are directly taken from the input data. For example, if all costs are given in thousands of euros, then the objective function is also in thousands of euros. So a "change in the objective function" would mean a €1k increase/decrease.

## Output Tables Format

Each output table has three types of columns:

1. Indices: Parameters on which the output variable or dual is indexed, including:
   - `asset`: Unique name of the asset.
   - `from_asset`: For a flow, the origin asset.
   - `to_asset`: For a flow, the terminal asset.
   - `year`: ??? Sometimes `milestone_year` sometimes "unique identifier, (currently, the year itself)"
   - `milestone_year`: Year of investment and operation decisions.
   - `commission_year`: Commissioning year of an asset (used for unique asset identification).
   - `rep_period`: Number of the representative period.
   - `time_block_start`:
   - `time_block_end`:
   - `period_block_start`:
   - `period_block_end`:
2. Associated [input parameters](@ref schemas): Listed per table below
3. `Solution` or `dual_constraint_name`: Value of the variable or dual in the solution, described below.

```@contents
Pages = ["60-outputs.md"]
Depth = [2, 3]
```

## Variable Tables

### `var_assets_decommission_energy`

For a storage asset commissioned in `commission_year`, the optimal decommissioning (decrease) of asset capacity in `milestone_year`, expressed in the same units as `capacity_storage_energy` of asset.

Associated input parameters: `investment_integer_storage_energy`

### `var_assets_decommission`

For a production asset commissioned in `commission_year`, the optimal decommissioning (decrease) of asset capacity in `milestone_year`, expressed in the same units as `capacity` of asset.

Associated input parameters: `decommissionable`, `initial_units`, `investment_integer`

### `var_assets_investment_energy`

For a storage asset, the optimal investment (increase) in asset capacity in `milestone_year`, expressed in the same units as `capacity_storage_energy` of asset.

Associated input parameters: `investment_integer_storage_energy`, `capacity_storage_energy`, `investment_limit_storage_energy`

### `var_assets_investment`

For a production asset, the optimal investment (increase) in asset capacity in `milestone_year`, expressed in the same units as `capacity` of asset.

Associated input parameters: `investment_integer`, `capacity`, `investment_limit`

### `var_flow`

For a flow, the optimal flow (of energy) during a particular `rep_period` between `time_block_start` and `time_block_end`, expressed in the same units as `capacity` of flow.

Associated input parameters: `efficiency`

### `var_flows_decommission`

For a flow commissioned in `commission_year`, the optimal decommissioning (decrease) of flow capacity in `milestone_year`, expressed in the same units as `capacity` of flow.

Associated input parameters: `investment_integer`

### `var_flows_investment`

For a flow, the optimal investment (increase) in flow capacity in `milestone_year`, expressed in the same units as `capacity` of flow.

Associated input parameters: `investment_integer`, `capacity`, `investment_limit`

### `var_storage_level_over_clustered_year`

For a storage asset in a specific `year` and between `period_start` and `period_end`, the optimal storage level BETWEEN representative periods, expressed in the same units as `capacity_storage_energy` of asset.

### `var_storage_level_rep_period`

For a storage asset in a specific `year` and between `period_start` and `period_end`, the optimal storage level WITHIN representative periods, expressed in the same units as `capacity_storage_energy` of asset.

### `var_units_on`

For an asset, the optimal dispatch (operation) during a particular `rep_period` between `time_block_start` and `time_block_end`, expressed in the same units as `capacity` of asset.

Associated input parameters: `unit_commitment_integer`

## Constraint Dual Tables

### `cons_balance_hub`

- `dual_balance_hub`: Dual of balance constraint of hub asset.

### `cons_balance_consumer`

- `dual_balance_consumer`:

### `cons_balance_conversion`

- `dual_balance_conversion`:

### `cons_balance_storage_over_clustered_year`

- `dual_balance_storage_over_clustered_year`: ``
- `dual_max_storage_level_over_clustered_year_limit`: ``
- `dual_min_storage_level_over_clustered_year_limit`: ``

### `cons_balance_storage_rep_period`

- `dual_balance_storage_rep_period`: ``
- `dual_max_storage_level_rep_period_limit`: ``
- `dual_min_storage_level_rep_period_limit`: ``

### `cons_capacity_incoming`

- `dual_max_input_flows_limit`: ``

### `cons_capacity_outgoing`

- `dual_max_output_flows_limit`: ``

### `cons_limit_units_on`

- `dual_limit_units_on`: ``

Associated input parameters: `unit_commitment_integer`

### `cons_max_output_flow_with_basic_unit_commitment`

- `dual_max_output_flow_with_basic_unit_commitment`: ``

### `cons_max_ramp_with_unit_commitment`

- `dual_max_ramp_up_with_unit_commitment`: ``
- `dual_max_ramp_down_with_unit_commitment`: ``

### `cons_min_output_flow_with_unit_commitment`

- `dual_min_output_flow_with_unit_commitment`: ``

### `cons_transport_flow_limit`

- `var_flow_id`: Unique ID used internally by TulipaEnergyModel
- `dual_max_transport_flow_limit`: ``
- `dual_min_transport_flow_limit`: ``
