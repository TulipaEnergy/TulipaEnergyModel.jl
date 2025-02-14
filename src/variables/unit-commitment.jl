export add_unit_commitment_variables!

"""
    add_unit_commitment_variables!(model, ...)

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
        ) for row in eachrow(units_on_indices)
    ]

    return
end
