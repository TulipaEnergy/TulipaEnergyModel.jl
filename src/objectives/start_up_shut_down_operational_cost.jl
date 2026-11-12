function _add_uc_transition_operational_cost!(
    connection,
    model,
    expressions,
    objective_expr,
    lambda,
    uc_transition,
)
    scenario_costs = expressions[Symbol("$(uc_transition)_operational_cost_per_scenario")]
    objective_name = Symbol("$(uc_transition)_operational_cost")
    uc_transition_cost = @expression(
        model,
        sum(
            row.probability * scenario_costs.expressions[:cost][row.id::Int64] for
            row in scenario_costs.indices
        ),
    )
    model[objective_name] = uc_transition_cost
    _add_to_objective!(
        connection,
        objective_expr,
        string(objective_name),
        (1 - lambda) * uc_transition_cost,
    )

    return nothing
end
