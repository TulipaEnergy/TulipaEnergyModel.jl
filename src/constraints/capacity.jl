export add_capacity_constraints!

function add_capacity_constraints!(
    model,
    dataframes,
    outgoing_flow_highest_out_resolution,
    assets_profile_times_capacity_out,
    incoming_flow_highest_in_resolution,
    assets_profile_times_capacity_in,
    df_flows,
    graph,
    flow,
)
    # - maximum output flows limit
    model[:max_output_flows_limit] = [
        @constraint(
            model,
            outgoing_flow_highest_out_resolution[row.index] ≤
            assets_profile_times_capacity_out[row.index],
            base_name = "max_output_flows_limit[$(row.asset),$(row.rp),$(row.timesteps_block)]"
        ) for row in eachrow(dataframes[:highest_out]) if
        outgoing_flow_highest_out_resolution[row.index] != 0
    ]

    # - maximum input flows limit
    model[:max_input_flows_limit] = [
        @constraint(
            model,
            incoming_flow_highest_in_resolution[row.index] ≤
            assets_profile_times_capacity_in[row.index],
            base_name = "max_input_flows_limit[$(row.asset),$(row.rp),$(row.timesteps_block)]"
        ) for row in eachrow(dataframes[:highest_in]) if
        incoming_flow_highest_in_resolution[row.index] != 0
    ]

    # - define lower bounds for flows that are not transport assets
    for row in eachrow(df_flows)
        if !graph[row.from, row.to].is_transport
            JuMP.set_lower_bound(flow[row.index], 0.0)
        end
    end
end
