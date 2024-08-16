export add_capacity_constraints!

"""
add_capacity_constraints!(model,
                          graph,
                          dataframes,
                          df_flows,
                          flow,
                          Ai,
                          Asb,
                          assets_investment_accumulated,
                          outgoing_flow_highest_out_resolution,
                          incoming_flow_highest_in_resolution
                          )

Adds the capacity constraints for all asset types to the model
"""

function add_capacity_constraints!(
    model,
    graph,
    dataframes,
    df_flows,
    flow,
    Ai,
    Asb,
    assets_investment_accumulated,
    outgoing_flow_highest_out_resolution,
    incoming_flow_highest_in_resolution,
)

    ## Expressions used by capacity constraints
    # - Create capacity limit for outgoing flows
    assets_profile_times_capacity_out =
        model[:assets_profile_times_capacity_out] = [
            if row.asset ∈ Ai
                @expression(
                    model,
                    profile_aggregation(
                        Statistics.mean,
                        graph[row.asset].rep_periods_profiles,
                        row.year,
                        ("availability", row.rep_period),
                        row.timesteps_block,
                        1.0,
                    ) * (
                        graph[row.asset].initial_capacity[row.year] + # this does not matter for now
                        graph[row.asset].capacity[row.investment_year] *
                        assets_investment_accumulated[row.asset, row.year, row.investment_year]
                    )
                )
            else
                @expression(
                    model,
                    profile_aggregation(
                        Statistics.mean,
                        graph[row.asset].rep_periods_profiles,
                        row.year,
                        ("availability", row.rep_period),
                        row.timesteps_block,
                        1.0,
                    ) * graph[row.asset].initial_capacity[row.year]
                )
            end for row in eachrow(dataframes[:highest_out])
        ]

    # - Create capacity limit for outgoing flows with binary is_charging for storage assets
    assets_profile_times_capacity_out_with_binary_part1 =
        model[:assets_profile_times_capacity_out_with_binary_part1] = [
            if row.asset ∈ Ai && row.asset ∈ Asb
                @expression(
                    model,
                    profile_aggregation(
                        Statistics.mean,
                        graph[row.asset].rep_periods_profiles,
                        ("availability", row.rep_period),
                        row.timesteps_block,
                        1.0,
                    ) *
                    (
                        graph[row.asset].initial_capacity[row.investment_year] +
                        graph[row.asset].investment_limit[row.investment_year]
                    ) * # fix this
                    (1 - row.is_charging[row.year])
                )
            else
                @expression(
                    model,
                    profile_aggregation(
                        Statistics.mean,
                        graph[row.asset].rep_periods_profiles,
                        ("availability", row.rep_period),
                        row.timesteps_block,
                        1.0,
                    ) *
                    (graph[row.asset].initial_capacity[row.year]) * # check this,
                    (1 - row.is_charging)
                )
            end for row in eachrow(dataframes[:highest_out])
        ]

    assets_profile_times_capacity_out_with_binary_part2 =
        model[:assets_profile_times_capacity_out_with_binary_part2] = [
            if row.asset ∈ Ai && row.asset ∈ Asb
                @expression(
                    model,
                    profile_aggregation(
                        Statistics.mean,
                        graph[row.asset].rep_periods_profiles,
                        ("availability", row.rep_period),
                        row.timesteps_block,
                        1.0,
                    ) * (
                        graph[row.asset].initial_capacity[row.investment_year] *
                        (1 - row.is_charging) +
                        graph[row.asset].capacity[row.investment_year] *
                        assets_investment_accumulated[row.asset, row.year, row.investment_year]
                    )
                )
            end for row in eachrow(dataframes[:highest_out])
        ]

    # - Create capacity limit for incoming flows
    assets_profile_times_capacity_in =
        model[:assets_profile_times_capacity_in] = [
            if row.asset ∈ Ai
                @expression(
                    model,
                    profile_aggregation(
                        Statistics.mean,
                        graph[row.asset].rep_periods_profiles,
                        ("availability", row.rep_period),
                        row.timesteps_block,
                        1.0,
                    ) * (
                        graph[row.asset].initial_capacity[row.investment_year] +
                        graph[row.asset].capacity[row.investment_year] *
                        assets_investment_accumulated[row.asset, row.year, row.investment_year]
                    )
                )
            else
                @expression(
                    model,
                    profile_aggregation(
                        Statistics.mean,
                        graph[row.asset].rep_periods_profiles,
                        ("availability", row.rep_period),
                        row.timesteps_block,
                        1.0,
                    ) * graph[row.asset].initial_capacity[row.year]
                )
            end for row in eachrow(dataframes[:highest_in])
        ]

    # - Create capacity limit for incoming flows with binary is_charging for storage assets
    assets_profile_times_capacity_in_with_binary_part1 =
        model[:assets_profile_times_capacity_in_with_binary_part1] = [
            if row.asset ∈ Ai && row.asset ∈ Asb
                @expression(
                    model,
                    profile_aggregation(
                        Statistics.mean,
                        graph[row.asset].rep_periods_profiles,
                        ("availability", row.rep_period),
                        row.timesteps_block,
                        1.0,
                    ) *
                    (
                        graph[row.asset].initial_capacity[row.investment_year] +
                        graph[row.asset].investment_limit[row.investment_year]
                    ) *
                    row.is_charging
                )
            else
                @expression(
                    model,
                    profile_aggregation(
                        Statistics.mean,
                        graph[row.asset].rep_periods_profiles,
                        ("availability", row.rep_period),
                        row.timesteps_block,
                        1.0,
                    ) *
                    (graph[row.asset].initial_capacity[row.investment_year]) *
                    row.is_charging
                )
            end for row in eachrow(dataframes[:highest_in])
        ]

    assets_profile_times_capacity_in_with_binary_part2 =
        model[:assets_profile_times_capacity_in_with_binary_part2] = [
            if row.asset ∈ Ai && row.asset ∈ Asb
                @expression(
                    model,
                    profile_aggregation(
                        Statistics.mean,
                        graph[row.asset].rep_periods_profiles,
                        ("availability", row.rep_period),
                        row.timesteps_block,
                        1.0,
                    ) * (
                        graph[row.asset].initial_capacity[row.investment_year] * row.is_charging +
                        graph[row.asset].capacity[row.investment_year] *
                        assets_investment_accumulated[row.asset, row.year, row.investment_year]
                    )
                )
            end for row in eachrow(dataframes[:highest_in])
        ]

    ## Capacity limit constraints (using the highest resolution)
    # - Maximum output flows limit
    model[:max_output_flows_limit] = [
        @constraint(
            model,
            outgoing_flow_highest_out_resolution[row.index] ≤ # this df has been changed to include years, so no need to change here.
            assets_profile_times_capacity_out[row.index], # this df has been changed to include years, so no need to change here.
            base_name = "max_output_flows_limit[$(row.asset), $(row.investment_year), $(row.year), $(row.rep_period),$(row.timesteps_block)]"
        ) for row in eachrow(dataframes[:highest_out]) if
        row.asset ∉ Asb && outgoing_flow_highest_out_resolution[row.index] != 0
    ]

    # - Maximum input flows limit
    model[:max_input_flows_limit] = [
        @constraint(
            model,
            incoming_flow_highest_in_resolution[row.index] ≤
            assets_profile_times_capacity_in[row.index],
            base_name = "max_input_flows_limit[$(row.asset),$(row.rep_period),$(row.timesteps_block)]"
        ) for row in eachrow(dataframes[:highest_in]) if
        row.asset ∉ Asb && incoming_flow_highest_in_resolution[row.index] != 0
    ]

    ## Capacity limit constraints (using the highest resolution) for storage assets using binary to avoid charging and discharging at the same time
    # - Maximum output flows limit with is_charging binary for storage assets
    model[:max_output_flows_limit_with_binary_part1] = [
        @constraint(
            model,
            outgoing_flow_highest_out_resolution[row.index] ≤
            assets_profile_times_capacity_out_with_binary_part1[row.index],
            base_name = "max_output_flows_limit_with_binary_part1[$(row.asset),$(row.rep_period),$(row.timesteps_block)]"
        ) for row in eachrow(dataframes[:highest_out]) if
        row.asset ∈ Asb && outgoing_flow_highest_out_resolution[row.index] != 0
    ]

    model[:max_output_flows_limit_with_binary_part2] = [
        @constraint(
            model,
            outgoing_flow_highest_out_resolution[row.index] ≤
            assets_profile_times_capacity_out_with_binary_part2[row.index],
            base_name = "max_output_flows_limit_with_binary_part2[$(row.asset),$(row.rep_period),$(row.timesteps_block)]"
        ) for row in eachrow(dataframes[:highest_out]) if row.asset ∈ Ai &&
        row.asset ∈ Asb &&
        outgoing_flow_highest_out_resolution[row.index] != 0
    ]

    # - Maximum input flows limit with is_charging binary for storage assets
    model[:max_input_flows_limit_with_binary_part1] = [
        @constraint(
            model,
            incoming_flow_highest_in_resolution[row.index] ≤
            assets_profile_times_capacity_in_with_binary_part1[row.index],
            base_name = "max_input_flows_limit_with_binary_part1[$(row.asset),$(row.rep_period),$(row.timesteps_block)]"
        ) for row in eachrow(dataframes[:highest_in]) if
        row.asset ∈ Asb && incoming_flow_highest_in_resolution[row.index] != 0
    ]
    model[:max_input_flows_limit_with_binary_part2] = [
        @constraint(
            model,
            incoming_flow_highest_in_resolution[row.index] ≤
            assets_profile_times_capacity_in_with_binary_part2[row.index],
            base_name = "max_input_flows_limit_with_binary_part2[$(row.asset),$(row.rep_period),$(row.timesteps_block)]"
        ) for row in eachrow(dataframes[:highest_in]) if
        row.asset ∈ Ai && row.asset ∈ Asb && incoming_flow_highest_in_resolution[row.index] != 0
    ]

    # - Lower limit for flows that are not transport assets
    for row in eachrow(df_flows)
        if !graph[row.from, row.to].is_transport[row.year]
            JuMP.set_lower_bound(flow[row.index], 0.0)
        end
    end
end
