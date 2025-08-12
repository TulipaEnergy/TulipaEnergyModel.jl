export add_unit_commitment_variables!
export add_start_up_and_shut_down_variables!

"""
    add_unit_commitment_variables!(model, variables)

Adds unit commitment variables to the optimization `model` based on the `:units_on` indices.
Additionally, variables are constrained to be integers based on the `unit_commitment_integer` property.

"""
function add_unit_commitment_variables!(model, variables)
    units_on_indices = variables[:units_on].indices

    variables[:units_on].container = [
        @variable(
            model,
            lower_bound = 0.0,
            integer = row.unit_commitment_integer,
            base_name = "units_on[$(row.asset),$(row.year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]",
        ) for row in units_on_indices
    ]

    return
end

"""
    add_start_up_and_shut_down_variables!(model, variables)

Adds 3bin UC variables to the optimization `model` based on the `:start_up` and `:shut_down` indices.
Additionally, variables are constrained to be integers based on the `unit_commitment_integer` property.

"""
function add_start_up_and_shut_down_variables!(model, variables)
    start_up_indices = variables[:start_up].indices
    variables[:start_up].container = [
        @variable(
            model,
            lower_bound = 0.0,
            integer = row.unit_commitment_integer,
            base_name = "start_up[$(row.asset),$(row.year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]",
        ) for row in start_up_indices
    ]

    shut_down_indices = variables[:shut_down].indices
    variables[:shut_down].container = [
        @variable(
            model,
            lower_bound = 0.0,
            integer = row.unit_commitment_integer,
            base_name = "shut_down[$(row.asset),$(row.year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]",
        ) for row in shut_down_indices
    ]

    return
end
