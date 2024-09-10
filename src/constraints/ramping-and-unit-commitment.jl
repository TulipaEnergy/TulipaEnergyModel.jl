export add_ramping_and_unit_commitment_constraints!

"""
    add_ramping_and_unit_commitment_constraints!(graph, ...)

Adds the ramping constraints for producer and conversion assets where ramping = true in assets_data
"""
function add_ramping_constraints!(
    model,
    graph,
    df_units_on_and_outflows,
    df_units_on,
    df_highest_out,
    outgoing_flow_highest_out_resolution,
    assets_investment,
    Ai,
    Auc,
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
                row.year,
                ("availability", row.rep_period),
                row.timesteps_block,
                1.0,
            ) * graph[row.asset].capacity[row.year]
        ) for row in eachrow(df_units_on_and_outflows) if
        get(graph[row.asset].active, row.year, false)
    ]

    # - Flow that is above the minimum operating point of the asset
    flow_above_min_operating_point =
        model[:flow_above_min_operating_point] = [
            @expression(
                model,
                row.outgoing_flow -
                profile_times_capacity[row.index] *
                graph[row.asset].min_operating_point[row.year] *
                row.units_on
            ) for row in eachrow(df_units_on_and_outflows)
        ]

    ## Unit Commitment Constraints (basic implementation - more advanced will be added in 2025)
    # - Limit to the units on (i.e. commitment) variable with investment
    model[:limit_units_on_with_investment] = [
        @constraint(
            model,
            row.units_on ≤
            graph[row.asset].initial_units[row.year] + assets_investment[row.year, row.asset],
            base_name = "limit_units_on_with_investment[$(row.asset),$(row.year),$(row.rep_period),$(row.timesteps_block)]"
        ) for row in eachrow(df_units_on) if row.asset in Ai[row.year]
    ]

    # - Limit to the units on (i.e. commitment) variable without investment (TODO: depending on the input parameter definition, this could be a bound)
    model[:limit_units_on_without_investment] = [
        @constraint(
            model,
            row.units_on ≤ graph[row.asset].initial_units[row.year],
            base_name = "limit_units_on_without_investment[$(row.asset),$(row.year),$(row.rep_period),$(row.timesteps_block)]"
        ) for row in eachrow(df_units_on) if !(row.asset in Ai[row.year])
    ]

    # - Minimum output flow above the minimum operating point
    model[:min_output_flow_with_unit_commitment] = [
        @constraint(
            model,
            flow_above_min_operating_point[row.index] ≥ 0,
            base_name = "min_output_flow_with_unit_commitment[$(row.asset),$(row.year),$(row.rep_period),$(row.timesteps_block)]"
        ) for row in eachrow(df_units_on_and_outflows)
    ]

    # - Maximum output flow above the minimum operating point
    model[:max_output_flow_with_basic_unit_commitment] = [
        @constraint(
            model,
            flow_above_min_operating_point[row.index] ≤
            (1 - graph[row.asset].min_operating_point[row.year]) *
            profile_times_capacity[row.index] *
            row.units_on,
            base_name = "max_output_flow_with_basic_unit_commitment[$(row.asset),$(row.year),$(row.rep_period),$(row.timesteps_block)]"
        ) for row in eachrow(df_units_on_and_outflows) if row.asset ∈ Auc_basic[row.year]
    ]

    ## Ramping Constraints with unit commitment
    # Note: We start ramping constraints from the second timesteps_block
    # We filter and group the dataframe per asset and representative period
    df_grouped = DataFrames.groupby(df_units_on_and_outflows, [:asset, :year, :rep_period])

    # get the units on column to get easier the index - 1, i.e., the previous one
    units_on = df_units_on_and_outflows.units_on

    #- Maximum ramp-up rate limit to the flow above the operating point when having unit commitment variables
    for ((a, y, rp), sub_df) in pairs(df_grouped)
        if !(a ∈ Ar[y] && a ∈ Auc_basic[y])
            continue
        end
        model[Symbol("max_ramp_up_with_unit_commitment_$(a)_$(y)_$(rp)")] = [
            @constraint(
                model,
                flow_above_min_operating_point[row.index] -
                flow_above_min_operating_point[row.index-1] ≤
                graph[row.asset].max_ramp_up[row.year] *
                row.min_outgoing_flow_duration *
                profile_times_capacity[row.index] *
                units_on[row.index],
                base_name = "max_ramp_up_with_unit_commitment[$a,$y,$rp,$(row.timesteps_block)]"
            ) for (k, row) in enumerate(eachrow(sub_df)) if k > 1
        ]
    end

    # - Maximum ramp-down rate limit to the flow above the operating point when having unit commitment variables
    for ((a, y, rp), sub_df) in pairs(df_grouped)
        if !(a ∈ Ar[y] && a ∈ Auc_basic[y])
            continue
        end
        model[Symbol("max_ramp_down_with_unit_commitment_$(a)_$(y)_$(rp)")] = [
            @constraint(
                model,
                flow_above_min_operating_point[row.index] -
                flow_above_min_operating_point[row.index-1] ≥
                -graph[row.asset].max_ramp_down[row.year] *
                row.min_outgoing_flow_duration *
                profile_times_capacity[row.index] *
                units_on[row.index-1],
                base_name = "max_ramp_down_with_unit_commitment[$a,$y,$rp,$(row.timesteps_block)]"
            ) for (k, row) in enumerate(eachrow(sub_df)) if k > 1
        ]
    end

    ## Ramping Constraints without unit commitment
    # Note: We start ramping constraints from the second timesteps_block
    # We filter and group the dataframe per asset and representative period that does not have the unit_commitment methods
    df_grouped = DataFrames.groupby(df_highest_out, [:asset, :year, :rep_period])

    # get the expression from the capacity constraints for the highest_out
    assets_profile_times_capacity_out = model[:assets_profile_times_capacity_out]

    # - Maximum ramp-up rate limit to the flow (no unit commitment variables)
    for ((a, y, rp), sub_df) in pairs(df_grouped)
        if !(a ∈ Ar[y]) || a ∈ Auc[y] # !(a ∈ Ar[y] \ Auc[y]) = !(a ∈ Ar[y] ∩ Auc[y]ᶜ) = !(a ∈ Ar[y] && a ∉ Auc[y]) = a ∉ Ar[y] || a ∈ Auc[y]
            continue
        end
        model[Symbol("max_ramp_up_without_unit_commitment_$(a)_$(y)_$(rp)")] = [
            @constraint(
                model,
                outgoing_flow_highest_out_resolution[row.index] -
                outgoing_flow_highest_out_resolution[row.index-1] ≤
                graph[row.asset].max_ramp_up[row.year] *
                row.min_outgoing_flow_duration *
                assets_profile_times_capacity_out[row.index],
                base_name = "max_ramp_up_without_unit_commitment[$a,$y,$rp,$(row.timesteps_block)]"
            ) for (k, row) in enumerate(eachrow(sub_df)) if
            k > 1 && outgoing_flow_highest_out_resolution[row.index] != 0
        ]
    end

    # - Maximum ramp-down rate limit to the flow (no unit commitment variables)
    for ((a, y, rp), sub_df) in pairs(df_grouped)
        if !(a ∈ Ar[y]) || a ∈ Auc[y] # !(a ∈ Ar[y] \ Auc[y]) = !(a ∈ Ar[y] ∩ Auc[y]ᶜ) = !(a ∈ Ar[y] && a ∉ Auc[y]) = a ∉ Ar[y] || a ∈ Auc[y]
            continue
        end
        model[Symbol("max_ramp_down_without_unit_commitment_$(a)_$(y)_$(rp)")] = [
            @constraint(
                model,
                outgoing_flow_highest_out_resolution[row.index] -
                outgoing_flow_highest_out_resolution[row.index-1] ≥
                -graph[row.asset].max_ramp_down[row.year] *
                row.min_outgoing_flow_duration *
                assets_profile_times_capacity_out[row.index],
                base_name = "max_ramp_down_without_unit_commitment[$a,$y,$rp,$(row.timesteps_block)]"
            ) for (k, row) in enumerate(eachrow(sub_df)) if
            k > 1 && outgoing_flow_highest_out_resolution[row.index] != 0
        ]
    end
end
