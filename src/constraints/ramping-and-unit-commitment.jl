export add_ramping_constraints!

"""
add_ramping_constraints!(graph, )

Adds the ramping constraints for producer and conversion assets where unit_commitment = true in assets_data
"""
function add_ramping_constraints!(model, graph, df_flows, flow, Auc, Auc_basic, units_on, Ai)
    ## Expressions used by the ramping and unit commitment constraints

    # ** Consider combining into one big IF/LOOP instead of each expression/constraint separately
    # ** Consider using cases for yes/no ramping/UC combos (4 total)
    # ** Consider temp/expression for "availability * capacity * units_on" since it's used by expression and 3 constraints

    # - Flow that is above the minimum operating point of the asset
    flow_above_min_oper_point =
        model[:flow_above_min_oper_point] = [
            if row.from ∈ Auc
                @expression(
                    model,
                    flow[row.index] -
                    profile_aggregation(
                        Statistics.mean,
                        graph[row.from].rep_periods_profiles,
                        ("availability", row.rep_period),
                        row.timesteps_block,
                        1.0,
                    ) *
                    graph[row.from].capacity *
                    graph[row.from].min_oper_point *
                    units_on[row.from]
                )
                # ** MISSING ELSE - Do something if asset does not have unit commitment?
            end for row in eachrow(df_flows)
        ]

    ## Unit Commitment Constraints (basic implementation - more advanced will be added in 2025)

    # ** Should this apply to all assets to avoid glitches for assets without UC?
    # Limit to the units on (i.e. commitment) variable
    model[:limit_units_on] = [
        @constraint(
            model,
            units_on[row.from] ≤ graph[row.from].initial_capacity + assets_investment[row.from]
        ) for row in eachrow(df_flows) if row.from ∈ Ai  # ** Probably wrong subset
    ]

    # Minimum output flow above the minimum operating point
    # flow_above_min_oper_point >= 0 if Auc_basic
    model[:min_unit_commitment] = [
        @constraint(model, flow_above_min_oper_point ≥ 0) for
        row in eachrow(df_flows) if row.from ∈ Auc
    ]

    # Maximum output flow above the minimum operating point
    # flow_above_min_oper_point <= p_avail_profile * p_capacity * (1- p_min_oper_point) * v_on
    model[:max_unit_commitment] = [
        @constraint(
            model,
            flow_above_min_oper_point ≤
            profile_aggregation(
                Statistics.mean,
                graph[row.from].rep_periods_profiles,
                ("availability", row.rep_period),
                row.timesteps_block,
                1.0,
            ) *
            graph[row.from].capacity *
            (1 - graph[row.from].min_oper_point) *
            units_on[row.from]
        ) for row in eachrow(df_flows) if row.from ∈ Auc
    ]

    ## Ramping Constraints

    # Maximum ramp-UP rate limit to the flow above the operating point
    model[:max_ramp_up] = [
        @constraint(
            model,
            # flow_above_min_oper_point - FLOW_ABOVE_MIN_OPER_POINT(TIMESTEPS_BLOCK - 1) <=
            flow_above_min_oper_point - 1000000000 ≤
            profile_aggregation(
                Statistics.mean,
                graph[row.from].rep_periods_profiles,
                ("availability", row.rep_period),
                row.timesteps_block,
                1.0,
            ) *
            graph[row.from].capacity *
            graph[row.from].max_ramp_up *
            units_on[row.from]
        ) for row in eachrow(df_flows) # if row.from ∈ Auc_basic
    ]

    # Maximum ramp-DOWN rate limit to the flow above the operating point
    model[:max_ramp_down] = [
        @constraint(
            model,
            # flow_above_min_oper_point - FLOW_ABOVE_MIN_OPER_POINT(TIMESTEPS_BLOCK - 1) >=
            flow_above_min_oper_point - 0 ≥
            -profile_aggregation(
                Statistics.mean,
                graph[row.from].rep_periods_profiles,
                ("availability", row.rep_period),
                row.timesteps_block,
                1.0,
            ) *
            graph[row.from].capacity *
            graph[row.from].max_ramp_down *
            units_on[row.from]
        ) for row in eachrow(df_flows) # if row.from ∈ Auc_basic
    ]
end
