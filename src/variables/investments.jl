"""
    add_investment_variables!(model, variables)

Adds investment variables to the optimization `model`,
and sets bounds on selected variables based on the input data.
"""
function add_investment_variables!(model, variables)
    _create_variables_from_indices!(
        model,
        variables,
        :flows_investment,
        row -> (row.milestone_year, (row.from_asset, row.to_asset));
        lower_bound_from_row = row ->
            _find_var_lower_bound(row.investment_min_limit, row.capacity, row.investment_integer),
        upper_bound_from_row = row ->
            _find_var_upper_bound(row.investment_max_limit, row.capacity, row.investment_integer),
        integer_from_row = row -> row.investment_integer,
    )
    _create_variables_from_indices!(
        model,
        variables,
        :assets_investment,
        row -> (row.milestone_year, row.asset);
        lower_bound_from_row = row ->
            _find_var_lower_bound(row.investment_min_limit, row.capacity, row.investment_integer),
        upper_bound_from_row = row ->
            _find_var_upper_bound(row.investment_max_limit, row.capacity, row.investment_integer),
        integer_from_row = row -> row.investment_integer,
    )
    _create_variables_from_indices!(
        model,
        variables,
        :assets_investment_energy,
        row -> (row.milestone_year, row.asset);
        lower_bound_from_row = row -> _find_var_lower_bound(
            row.investment_min_limit_storage_energy,
            row.capacity_storage_energy,
            row.investment_integer_storage_energy,
        ),
        upper_bound_from_row = row -> _find_var_upper_bound(
            row.investment_max_limit_storage_energy,
            row.capacity_storage_energy,
            row.investment_integer_storage_energy,
        ),
        integer_from_row = row -> row.investment_integer_storage_energy,
    )
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

function _find_var_lower_bound(limit, capacity, integer)
    if capacity <= 0 || ismissing(limit)
        return 0.0
    end
    bound_value = limit / capacity
    if integer
        bound_value = ceil(bound_value)
    end
    return bound_value
end
