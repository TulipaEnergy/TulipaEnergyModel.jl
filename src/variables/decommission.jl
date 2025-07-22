export add_decommission_variables!

"""
    _get_decommission_variable_specifications()

Returns a dictionary containing specifications for all decommission variables.
Each specification includes the keys extraction function, bounds functions, and integer constraint function.
"""
function _get_decommission_variable_specifications()
    return Dict{Symbol,NamedTuple}(
        :assets_decommission => (
            keys_from_row = row -> (row.asset, row.milestone_year, row.commission_year),
            lower_bound_from_row = _ -> 0.0,
            upper_bound_from_row = _ -> Inf,
            integer_from_row = row -> row.investment_integer,
        ),
        :flows_decommission => (
            keys_from_row = row ->
                ((row.from_asset, row.to_asset), row.milestone_year, row.commission_year),
            lower_bound_from_row = _ -> 0.0,
            upper_bound_from_row = _ -> Inf,
            integer_from_row = row -> row.investment_integer,
        ),
        :assets_decommission_energy => (
            keys_from_row = row -> (row.asset, row.milestone_year, row.commission_year),
            lower_bound_from_row = _ -> 0.0,
            upper_bound_from_row = _ -> Inf,
            integer_from_row = row -> row.investment_integer_storage_energy,
        ),
    )
end

"""
    add_decommission_variables!(model, variables)

Adds decommission variables to the optimization `model`,
and sets bounds on selected variables based on the input data.
"""
function add_decommission_variables!(model, variables)
    specifications = _get_decommission_variable_specifications()
    _create_variables_from_specifications!(model, variables, specifications)
    return
end
