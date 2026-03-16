export add_value_at_risk_threshold_mu!

"""
    _get_value_at_risk_threshold_mu_specifications()

Returns a dictionary containing specifications for the value at risk threshold mu.
Each specification includes the keys extraction function, bounds functions, and integer constraint function.
"""
function _get_value_at_risk_threshold_mu_specifications()
    return Dict{Symbol,NamedTuple}(
        :value_at_risk_threshold_mu => (
            keys_from_row = row -> (),
            lower_bound_from_row = _ -> 0.0,
            upper_bound_from_row = _ -> Inf,
            integer_from_row = _ -> false,
        ),
    )
end

"""
    add_value_at_risk_threshold_mu!(model, variables, model_parameters)

Adds the Value at Risk variable `μ` in case `risk_aversion_weight_lambda` > 0
The units are the currency of the objective function
"""

function add_value_at_risk_threshold_mu!(model, variables, model_parameters)
    if model_parameters.risk_aversion_weight_lambda > 0
        specifications = _get_value_at_risk_threshold_mu_specifications()
        _create_variables_from_specifications!(model, variables, specifications)
    end
    return
end
