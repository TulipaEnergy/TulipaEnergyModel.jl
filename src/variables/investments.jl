export add_investment_variables!

"""
    _get_investment_variable_specifications()

Returns a dictionary containing specifications for all investment variables.
Each specification includes the keys extraction function, bounds functions, and integer constraint function.
"""
function _get_investment_variable_specifications()
    return Dict{Symbol,NamedTuple}(
        :flows_investment => (
            keys_from_row = row -> (row.milestone_year, (row.from_asset, row.to_asset)),
            lower_bound_from_row = _ -> 0.0,
            upper_bound_from_row = row -> _find_var_upper_bound(
                row.investment_limit,
                row.capacity,
                row.investment_integer,
            ),
            integer_from_row = row -> row.investment_integer,
        ),
        :assets_investment => (
            keys_from_row = row -> (row.milestone_year, row.asset),
            lower_bound_from_row = _ -> 0.0,
            upper_bound_from_row = row -> _find_var_upper_bound(
                row.investment_limit,
                row.capacity,
                row.investment_integer,
            ),
            integer_from_row = row -> row.investment_integer,
        ),
        :assets_investment_energy => (
            keys_from_row = row -> (row.milestone_year, row.asset),
            lower_bound_from_row = _ -> 0.0,
            upper_bound_from_row = row -> _find_var_upper_bound(
                row.investment_limit_storage_energy,
                row.capacity_storage_energy,
                row.investment_integer_storage_energy,
            ),
            integer_from_row = row -> row.investment_integer_storage_energy,
        ),
    )
end

"""
    add_investment_variables!(model, variables)

Adds investment variables to the optimization `model`,
and sets bounds on selected variables based on the input data.
"""
function add_investment_variables!(model, variables)
    specifications = _get_investment_variable_specifications()
    _create_variables_from_specifications!(model, variables, specifications)
    return
end

function _find_var_upper_bound(limit, capacity, integer)
    if capacity <= 0 || ismissing(limit)
        return Inf
    end
    bound_value = limit / capacity
    if integer
        bound_value = floor(bound_value)
    end
    return bound_value
end
