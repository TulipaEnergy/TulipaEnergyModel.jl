function _add_conditional_value_at_risk_term!(
    connection,
    model,
    variables,
    objective_expr,
    lambda,
    alpha,
)

    # get the number of scenarios to determine if we need to add the CVaR term
    n_scenarios = get_single_element_from_query_and_ensure_its_only_one(
        DuckDB.query(
            connection,
            """
            SELECT COUNT(*) FROM stochastic_scenario
            """,
        ),
    )

    if lambda <= 0.0 || n_scenarios <= 1
        return nothing
    end

    value_at_risk_threshold_mu = variables[:value_at_risk_threshold_mu].container[1]
    tail_excess_slack_xi = variables[:tail_excess_slack_xi].container
    indices = variables[:tail_excess_slack_xi].indices

    @expression(
        model,
        conditional_value_at_risk_term,
        value_at_risk_threshold_mu +
        (1 / (1 - alpha)) * sum(row.probability * tail_excess_slack_xi[row.id] for row in indices)
    )
    _add_to_objective!(
        connection,
        objective_expr,
        "conditional_value_at_risk_term",
        lambda * conditional_value_at_risk_term,
    )
    return
end
