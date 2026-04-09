
export add_scenario_tail_excess_constraints!

"""
    add_scenario_tail_excess_constraints!(
        connection,
        model,
        variables,
        expressions,
        constraints,
    )

Adds the scenario tail excess constraints to the model for the
    conditional value at risk feature.
"""
function add_scenario_tail_excess_constraints!(
    connection,
    model,
    variables,
    expressions,
    constraints,
)
    let table_name = :scenario_tail_excess, cons = constraints[table_name]
        indices = _append_scenario_tail_excess_data_to_indices(connection, table_name)
        if isempty(variables[:tail_excess_slack_xi].container)
            return nothing
        end
        var_tail_excess_slack_xi = variables[:tail_excess_slack_xi].container
        total_cost_per_scenario =
            expressions[:scenario_tail_excess].expressions[:total_cost_per_scenario]
        var_value_at_risk_threshold_mu = variables[:value_at_risk_threshold_mu].container[1]
        attach_constraint!(
            model,
            cons,
            table_name,
            [
                @constraint(
                    model,
                    var_tail_excess_slack_xi[row.id::Int64] >=
                    total_cost_per_scenario[row.id::Int64] - var_value_at_risk_threshold_mu,
                    base_name = "$table_name[$(row.scenario)]"
                ) for row in indices
            ],
        )
    end

    return nothing
end

function _append_scenario_tail_excess_data_to_indices(connection, table_name)
    return DuckDB.query(
        connection,
        """
        SELECT
            cons.id,
            cons.scenario,
        FROM cons_$table_name AS cons
        ORDER BY cons.id
        """,
    )
end
