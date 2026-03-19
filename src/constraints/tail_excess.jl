#=
Tail excess constraint:

xi_s >= c^inv + AF * c_s^op - mu \forall s \in S
and
xi_s >= 0 \forall s \in S

CAN I TAKE C^INV AND OP FROM OBJECTIVE OBJECTS?

Only create it if lambda > 0: IS THIS SQL LOGIC?

=#
export add_tail_excess_constraints!

indices = DuckDB.query(
    connection,
    "SELECT
        var.id,
        var.scenario,
        scn.probability
    FROM var_tail_excess_slack_xi AS var
    LEFT JOIN stochastic_scenario AS scn
        ON var.scenario = scn.scenario
    ORDER BY var.id
    ",
)

flows_operational_cost = model[:flows_operational_cost]
vintage_flows_operational_cost = model[:vintage_flows_operational_cost]
units_on_cost = model[:units_on_cost]

operational_costs_by_scenario = @expression(
    model,
    row.flows_operational_cost + row.vintage_flows_operational_cost + row.units_on_cost
) for row in zip(indices)

indices = DuckDB.query(
    connection,
    "SELECT
        var.id,
        obj.weight_for_asset_investment_discount
            * obj.investment_cost_storage_energy
            * obj.capacity_storage_energy
            AS cost,
    FROM var_assets_investment_energy AS var
    LEFT JOIN t_objective_assets as obj
        ON var.asset = obj.asset
        AND var.milestone_year = obj.milestone_year
    ORDER BY var.id
    ",
)

#how to deal with the indices for the other investment costs?

assets_investment_cost = model[:assets_investment_cost]
assets_fixed_cost_compact_method = model[:assets_fixed_cost_compact_method]
assets_fixed_cost_simple_method = model[:assets_fixed_cost_simple_method]
storage_assets_energy_investment_cost = model[:storage_assets_energy_investment_cost]
storage_assets_energy_fixed_cost = model[:storage_assets_energy_fixed_cost]
flows_investment_cost = model[:flows_investment_cost]
flows_fixed_cost = model[:flows_fixed_cost]

investment_cost_total = @expression(
    model,
    row.assets_investment_cost +
    row.assets_fixed_cost_compact_method +
    row.assets_fixed_cost_simple_method +
    row.storage_assets_energy_investment_cost +
    row.storage_assets_energy_fixed_cost +
    row.flows_investment_cost +
    row.flows_fixed_cost
) for row in zip(indices)

function add_tail_excess_constraints!(
    connection,
    model,
    variables,
    constraints,
    model_parameters,
    expressions,
)
    if model_parameters.risk_aversion_weight_lambda > 0 #will return nothing for default lambda = 0?
        cons = constraints[:tail_excess]
        table = _create_excess_table(connection)
        xi = variables[:tail_excess_slack_xi].container
        mu = variables[:value_at_risk_threshold_mu].container
        attach_constraint!(
            model,
            cons,
            :tail_excess,
            [
                begin
                    if model_parameters.risk_aversion_weight_lambda > 0
                        @constraint(
                            model,
                            xi >=
                            investment_cost_total + annualized_cost * op_costs_by_scenario - mu,
                            base_name = "tail_excess[$(row.scenario)]"
                        )
                    end
                end,
            ],
        )
    end
    return
end

# create expressions for c inv and c op (scenario dependent), find whre annualized cost is stored (as parameter?)
function _create_excess_table(connection)
    return DuckDB.query(
        connection,
        "SELECT
            var.id,
            var.scenario
        FROM var_tail_excess_slack_xi AS var
        ORDER BY var.id
        ",
    )
end
