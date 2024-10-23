export add_unit_commitment_variables!

"""
    add_unit_commitment_variables!(model, ...)

Adds unit commitment variables to the optimization `model` based on the `:units_on` indices.
Additionally, variables are constrained to be integers based on the `sets` structure.

"""
function add_unit_commitment_variables!(model, sets, variables)
    units_on_indices = variables[:units_on].indices

    variables[:units_on].container = [
        @variable(
            model,
            lower_bound = 0.0,
            base_name = "units_on[$(row.asset),$(row.year),$(row.rep_period),$(row.timesteps_block)]"
        ) for row in eachrow(units_on_indices)
    ]

    ### Integer Unit Commitment Variables
    integer_units_on_indices = filter(
        row ->
            (row.year in keys(sets.Auc_integer)) && (row.asset in sets.Auc_integer[row.year]),
        units_on_indices,
    )
    for row in eachrow(integer_units_on_indices)
        JuMP.set_integer(variables[:units_on].container[row.index])
    end

    return
end
