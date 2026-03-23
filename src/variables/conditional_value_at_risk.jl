export add_conditional_value_at_risk_variables!

"""
    add_conditional_value_at_risk_variables!(model, variables)

Adds the following variables for the Conditional Value at Risk (CVaR) formulation to the optimization `model`:

    - Value at Risk threshold variable `μ`
    - Tail excess slack variable `ξ` for each scenario

The variables are only created in case `risk_aversion_weight_lambda` > 0 and
the number of scenarios is greater than 1.
Check the SQL query in `src/sql/create-variables.sql` for the details.

The units are the currency of the objective function
"""

function add_conditional_value_at_risk_variables!(model, variables)
    # Add variable for the Value at Risk threshold mu
    value_at_risk_threshold_mu_indices = variables[:value_at_risk_threshold_mu].indices
    variables[:value_at_risk_threshold_mu].container = [
        @variable(model, lower_bound = 0.0, base_name = "value_at_risk_threshold_mu",) for
        row in value_at_risk_threshold_mu_indices
    ]

    # Add variable for the tail excess slack xi for each scenario
    tail_excess_slack_xi_indices = variables[:tail_excess_slack_xi].indices
    variables[:tail_excess_slack_xi].container = [
        @variable(model, lower_bound = 0.0, base_name = "tail_excess_slack_xi[$(row.scenario)]",) for row in tail_excess_slack_xi_indices
    ]
    return
end
