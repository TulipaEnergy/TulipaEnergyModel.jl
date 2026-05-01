"""
    add_scenario_tail_excess_expressions!(connection, model, variables, expressions)

Add scenario tail excess expressions to the model for the conditional value at risk feature.
"""
function add_scenario_tail_excess_expressions!(connection, model, variables, expressions)
    # both the expression and the constraints for the conditional value at risk feature
    # depend on the var_tail_excess_slack_xi variable creation
    DuckDB.query(
        connection,
        """
        CREATE OR REPLACE TABLE expr_scenario_tail_excess AS
        SELECT
            *
        FROM var_tail_excess_slack_xi
        ORDER BY id
        """,
    )

    expressions[:scenario_tail_excess] = TulipaExpression(connection, "expr_scenario_tail_excess")

    if isempty(variables[:tail_excess_slack_xi].container)
        attach_expression!(
            expressions[:scenario_tail_excess],
            :total_cost_per_scenario,
            JuMP.AffExpr[],
        )
        return nothing
    end

    let table_name = :scenario_tail_excess, expr = expressions[table_name]
        n = expr.num_rows

        # Costs that do not depend on scenario (from src/objectives/*.jl)
        base_cost = JuMP.AffExpr(0.0)
        for objective_name in (
            :assets_investment_cost,
            :assets_fixed_cost_compact_method,
            :assets_fixed_cost_simple_method,
            :storage_assets_energy_investment_cost,
            :storage_assets_energy_fixed_cost,
            :flows_investment_cost,
            :flows_fixed_cost,
        )
            if haskey(model, objective_name)
                JuMP.add_to_expression!(base_cost, model[objective_name])
            end
        end

        # Costs that depend on scenario (from src/objectives/*.jl)
        flows_operational_cost_per_scenario =
            expressions[:flows_operational_cost_per_scenario].expressions[:cost]
        vintage_flows_operational_cost_per_scenario =
            expressions[:vintage_flows_operational_cost_per_scenario].expressions[:cost]
        units_on_operational_cost_per_scenario =
            expressions[:units_on_operational_cost_per_scenario].expressions[:cost]

        # Construct the total cost per scenario expression for each scenario
        total_cost_per_scenario = Vector{JuMP.AffExpr}(undef, expr.num_rows)
        for i in 1:expr.num_rows
            scenario_cost = JuMP.AffExpr(0.0)
            JuMP.add_to_expression!(scenario_cost, base_cost)
            JuMP.add_to_expression!(scenario_cost, flows_operational_cost_per_scenario[i])
            JuMP.add_to_expression!(scenario_cost, vintage_flows_operational_cost_per_scenario[i])
            JuMP.add_to_expression!(scenario_cost, units_on_operational_cost_per_scenario[i])
            total_cost_per_scenario[i] = scenario_cost
        end

        attach_expression!(expr, :total_cost_per_scenario, total_cost_per_scenario)
    end

    return nothing
end
