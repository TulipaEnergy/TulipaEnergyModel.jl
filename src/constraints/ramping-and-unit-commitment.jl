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
                profile_times_capacity[row.index] * graph[row.asset].min_oper_point * row.units_on
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
            graph[row.asset].capacity * assets_investment[row.asset],
            base_name = "limit_units_on_with_investment[$(row.asset),$(row.rep_period),$(row.timesteps_block)]"
        ) for row in eachrow(df)
    ]

    # - Limit to the units on (i.e. commitment) variable without investment (TODO: depending on the input parameter definition, this could be a bound)
    df = filter([:asset] => asset -> asset ∉ Ai, df_units_on; view = true)
    model[:limit_units_on_without_investment] = [
        @constraint(
            model,
            graph[row.asset].capacity * row.units_on ≤ graph[row.asset].initial_capacity,
            base_name = "limit_units_on_without_investment[$(row.asset),$(row.rep_period),$(row.timesteps_block)]"
        ) for row in eachrow(df)
    ]

    # - Minimum output flow above the minimum operating point
    model[:min_output_flow_with_unit_commitment] = [
        @constraint(
            model,
            flow_above_min_oper_point[row.index] ≥ 0,
            base_name = "min_output_flow_with_unit_commitment[$(row.asset),$(row.rep_period),$(row.timesteps_block)]"
        ) for row in eachrow(df_units_on_and_outflows)
    ]

    # - Maximum output flow above the minimum operating point
    df = filter([:asset] => asset -> asset ∈ Auc_basic, df_units_on_and_outflows; view = true)
    model[:max_output_flow_with_basic_unit_commitment] = [
        @constraint(
            model,
            flow_above_min_oper_point[row.index] ≤
            (1 - graph[row.asset].min_oper_point) *
            profile_times_capacity[row.index] *
            row.units_on,
            base_name = "max_output_flow_with_basic_unit_commitment[$(row.asset),$(row.rep_period),$(row.timesteps_block)]"
        ) for row in eachrow(df)
    ]

    ## Ramping Constraints
    # Note: We start ramping constraints from the second timesteps_block
    # First we filter and group the dataframe per asset and representative period
    df = filter([:asset] => asset -> asset ∈ Ar, df_units_on_and_outflows; view = true)
    df_grouped = DataFrames.groupby(df, [:asset, :rep_period])

    #- Maximum ramp-up rate limit to the flow above the operating point when having unit commitment variables
    for ((a, rp), sub_df) in pairs(df_grouped)
        model[Symbol("max_ramp_up_with_unit_commitment_$(a)_$(rp)")] = [
            @constraint(
                model,
                flow_above_min_oper_point[row.index] - flow_above_min_oper_point[row.index-1] ≤
                graph[row.asset].max_ramp_up * profile_times_capacity[row.index] * row.units_on,
                base_name = "max_ramp_up_with_unit_commitment[$a,$rp,$(row.timesteps_block)]"
            ) for (k, row) in enumerate(eachrow(sub_df)) if k > 1
        ]
    end

    # - Maximum ramp-down rate limit to the flow above the operating point when having unit commitment variables
    for ((a, rp), sub_df) in pairs(df_grouped)
        model[Symbol("max_ramp_down_with_unit_commitment_$(a)_$(rp)")] = [
            @constraint(
                model,
                flow_above_min_oper_point[row.index] - flow_above_min_oper_point[row.index-1] ≥
                -graph[row.asset].max_ramp_down * profile_times_capacity[row.index] * row.units_on,
                base_name = "max_ramp_down_with_unit_commitment[$a,$rp,$(row.timesteps_block)]"
            ) for (k, row) in enumerate(eachrow(sub_df)) if k > 1
        ]
    end
end
