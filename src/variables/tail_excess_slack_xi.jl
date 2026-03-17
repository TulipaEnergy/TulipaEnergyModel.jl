export add_tail_excess_slack_xi!

"""
    add_tail_excess_slack_xi_specifications()

Adds tail excess slack variable xi for each scenario to the `model` in case of
a risk averse objective (risk_aversion_weight_lambda > 0).
"""
function add_tail_excess_slack_xi!(model, variables, model_parameters)
    if model_parameters.risk_aversion_weight_lambda > 0
        tail_excess_slack_xi_indices = variables[:tail_excess_slack_xi].indices

        variables[:tail_excess_slack_xi].container = [
            @variable(
                model,
                lower_bound = 0.0,
                base_name = "tail_excess_slack_xi[$(row.scenario)]",
            ) for row in tail_excess_slack_xi_indices
        ]
    end

    return
end
