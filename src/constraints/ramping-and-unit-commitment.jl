export add_ramping_and_unit_commitment_constraints!

"""
add_ramping_and_unit_commitment_constraints!(graph, )

Adds the ramping constraints for producer and conversion assets where ramping = true in assets_data
"""
function add_ramping_constraints!(
    model,
    graph,
    df_units_on_and_outflows,
    df_units_on,
    assets_investment,
    Ai,
    Auc_basic,
    Ar,
)

    # TODO: Add Ar to schema, structures and input data
    # TODO: Fix indices/sets (see TODOs throughout)
    #  - Implement yes/no ramping/UC combos (4 total)
    #  - Issue with defining expressions for subset of df_flows is that index is still df_flows when you try to reference it later
    #    - Look at consumer.jl to see if that implementation would work
    #  - row.index is an actual column of df_flows
    #  - Maybe something like this? df_Auc = filter(:from => ∈(Auc), df_flows; view = true)
    # TODO: Fix init cap units vs init cap in code and input data (separate PR?)
    # TODO: Separate UC into second function (or change function name)

    ## Expressions used by the ramping and unit commitment constraints
    # - Expression to have the product of the profile and the capacity paramters
    profile_times_capacity = [
        @expression(
            model,
            profile_aggregation(
                Statistics.mean,
                graph[row.asset].rep_periods_profiles,
                ("availability", row.rep_period),
                row.timesteps_block,
                1.0,
            ) * graph[row.asset].capacity
        ) for row in eachrow(df_units_on_and_outflows)
    ]

    # - Flow that is above the minimum operating point of the asset
    flow_above_min_oper_point =
        model[:flow_above_min_oper_point] = [
            @expression(
                model,
                row.outgoing_flow -
                profile_times_capacity[row.index] *
                graph[row.asset].capacity *
                graph[row.asset].min_oper_point *
                row.units_on
            ) for row in eachrow(df_units_on_and_outflows)
        ]

    ## Unit Commitment Constraints (basic implementation - more advanced will be added in 2025)
    # - Limit to the units on (i.e. commitment) variable with investment
    df = filter([:asset] => asset -> asset ∈ Ai, df_units_on; view = true)
    model[:limit_units_on_with_investment] = [
        @constraint(
            model,
            graph[row.asset].capacity * row.units_on ≤
            graph[row.asset].initial_capacity +
            graph[row.asset].capacity * assets_investment[row.asset]
        ) for row in eachrow(df)
    ]

    # - Limit to the units on (i.e. commitment) variable without investment (TODO: depending on the input parameter definition, this could be a bound)
    df = filter([:asset] => asset -> asset ∉ Ai, df_units_on; view = true)
    model[:limit_units_on_without_investment] = [
        @constraint(
            model,
            graph[row.asset].capacity * row.units_on ≤ graph[row.asset].initial_capacity
        ) for row in eachrow(df)
    ]

    # - Minimum output flow above the minimum operating point
    model[:min_output_flow_with_unit_commitment] = [
        @constraint(model, flow_above_min_oper_point[row.index] ≥ 0) for
        row in eachrow(df_units_on_and_outflows)
    ]

    # - Maximum output flow above the minimum operating point
    df = filter([:asset] => asset -> asset ∈ Auc_basic, df_units_on_and_outflows; view = true)
    model[:min_output_flow_with_basic_unit_commitment] = [
        @constraint(
            model,
            flow_above_min_oper_point[row.index] ≤
            (1 - graph[row.asset].min_oper_point) *
            profile_times_capacity[row.index] *
            row.units_on
        ) for row in eachrow(df)
    ]

    ## Ramping Constraints
    # Note: We start ramping constraints from the second timesteps_block
    # - Maximum ramp-up rate limit to the flow above the operating point when having unit commitment variables
    # df = filter([:asset] => asset -> asset ∈ Ar, df_units_on_and_outflows; view = true)
    # model[:max_ramp_up_with_unit_commitment] = [
    #     @constraint(
    #         model,
    #         flow_above_min_oper_point[row.index] - flow_above_min_oper_point[row.index-1] ≤
    #         graph[row.asset].max_ramp_up * profile_times_capacity[row.index] * row.units_on
    #     ) for row in eachrow(df)
    # ]

    # # - Maximum ramp-down rate limit to the flow above the operating point when having unit commitment variables
    # model[:max_ramp_up_with_unit_commitment] = [
    #     @constraint(
    #         model,
    #         flow_above_min_oper_point[row.index] - flow_above_min_oper_point[row.index-1] ≥
    #         -graph[row.asset].max_ramp_down * profile_times_capacity[row.index] * row.units_on
    #     ) for row in eachrow(df[2:end])
    # ]
end
