export add_conditional_value_at_risk_variables!

"""
    add_conditional_value_at_risk_variables!(connection, model, variables, model_parameters)

Adds the following variables for the Conditional Value at Risk (CVaR) formulation to the optimization `model`:

    - Value at Risk threshold variable `μ`

The variables are only created in case `risk_aversion_weight_lambda` > 0

The units are the currency of the objective function
"""

function add_conditional_value_at_risk_variables!(connection, model, variables, model_parameters)
    if model_parameters.risk_aversion_weight_lambda > 0
        # Add variable for the Value at Risk threshold mu
        _update_value_at_risk_threshold_mu_variable!(
            connection,
            variables[:value_at_risk_threshold_mu],
        )
        specifications = _get_value_at_risk_threshold_mu_specifications()
        _create_variables_from_specifications!(model, variables, specifications)
    end
    return
end

"""
    _update_value_at_risk_threshold_mu_variable!(connection, variable)

Updates the in-memory TulipaVariable metadata for the Value at Risk threshold variable `μ`.
"""
function _update_value_at_risk_threshold_mu_variable!(connection, variable)
    table_name = variable.table_name
    DBInterface.execute(
        connection,
        """
        INSERT INTO $(table_name) (id, solution)
        SELECT 1, null
        WHERE NOT EXISTS (
            SELECT 1
            FROM $(table_name)
            WHERE id = 1
        )
        """,
    )
    variable.indices = DuckDB.query(connection, "SELECT * FROM $(table_name) ORDER BY id")
    variable.container = JuMP.VariableRef[]

    return nothing
end

"""
    _get_value_at_risk_threshold_mu_specifications()

Returns a dictionary containing specifications for the value at risk threshold mu.
Each specification includes the keys extraction function, bounds functions, and integer constraint function.
"""
function _get_value_at_risk_threshold_mu_specifications()
    return Dict{Symbol,NamedTuple}(
        :value_at_risk_threshold_mu => (
            keys_from_row = row -> row.id,
            lower_bound_from_row = _ -> 0.0,
            upper_bound_from_row = _ -> Inf,
            integer_from_row = _ -> false,
        ),
    )
end
