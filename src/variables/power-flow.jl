export add_power_flow_variables!

"""
    add_power_flow_variables!(model, variables)

Adds power flow variables to the optimization `model` based on the `:electricity_angle` indices.

"""
function add_power_flow_variables!(model, variables)
    electricity_angle_indices = variables[:electricity_angle].indices

    variables[:electricity_angle].container = [
        @variable(
            model,
            base_name = "electricity_angle[$(row.asset),$(row.year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]",
        ) for row in electricity_angle_indices
    ]

    return
end
