"""
    add_demand_response_variables!(connection, model, variables)

Adds demand-response-related variables to the optimization `model` for consumer
assets using the `shifting_with_recovery` method. Two non-negative deviation
variables are created per demand response time block: the upward deviation
(`dr_demand_increase`) and the downward deviation (`dr_demand_decrease`). Both
are defined on the consumer asset's own time resolution.
"""
function add_demand_response_variables!(connection, model, variables)
    dr_demand_increase_indices = variables[:dr_demand_increase].indices
    dr_demand_decrease_indices = variables[:dr_demand_decrease].indices

    variables[:dr_demand_increase].container = [
        @variable(
            model,
            lower_bound = 0.0,
            base_name = "dr_demand_increase[$(row.asset),$(row.milestone_year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]"
        ) for row in dr_demand_increase_indices
    ]

    variables[:dr_demand_decrease].container = [
        @variable(
            model,
            lower_bound = 0.0,
            base_name = "dr_demand_decrease[$(row.asset),$(row.milestone_year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]"
        ) for row in dr_demand_decrease_indices
    ]

    return
end
