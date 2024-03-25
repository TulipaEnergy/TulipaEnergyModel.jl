export add_transport_constraints!

"""
add_transport_constraints!(model, graph, df_flows, flow, Ft, flows_investment)

Adds the transport flow constraints to the model.
"""

function add_transport_constraints!(model, graph, df_flows, flow, Ft, flows_investment)

    ## Expressions used by transport flow constraints
    # - Create upper limit of transport flow
    upper_bound_transport_flow = [
        if graph[row.from, row.to].investable
            @expression(
                model,
                profile_aggregation(
                    Statistics.mean,
                    graph[row.from, row.to].rep_periods_profiles,
                    (:availability, row.rp),
                    row.timesteps_block,
                    1.0,
                ) * (
                    graph[row.from, row.to].initial_export_capacity +
                    graph[row.from, row.to].capacity * flows_investment[(row.from, row.to)]
                )
            )
        else
            @expression(
                model,
                profile_aggregation(
                    Statistics.mean,
                    graph[row.from, row.to].rep_periods_profiles,
                    (:availability, row.rp),
                    row.timesteps_block,
                    1.0,
                ) * graph[row.from, row.to].initial_export_capacity
            )
        end for row in eachrow(df_flows)
    ]

    # Create lower limit of transport flow
    lower_bound_transport_flow = [
        if graph[row.from, row.to].investable
            @expression(
                model,
                profile_aggregation(
                    Statistics.mean,
                    graph[row.from, row.to].rep_periods_profiles,
                    (:availability, row.rp),
                    row.timesteps_block,
                    1.0,
                ) * (
                    graph[row.from, row.to].initial_import_capacity +
                    graph[row.from, row.to].capacity * flows_investment[(row.from, row.to)]
                )
            )
        else
            @expression(
                model,
                profile_aggregation(
                    Statistics.mean,
                    graph[row.from, row.to].rep_periods_profiles,
                    (:availability, row.rp),
                    row.timesteps_block,
                    1.0,
                ) * graph[row.from, row.to].initial_import_capacity
            )
        end for row in eachrow(df_flows)
    ]

    ## Constraints that define bounds for a transport flow Ft
    df = filter(row -> (row.from, row.to) ∈ Ft, df_flows)

    # - Max transport flow limit
    model[:max_transport_flow_limit] = [
        @constraint(
            model,
            flow[row.index] ≤ upper_bound_transport_flow[row.index],
            base_name = "max_transport_flow_limit[($(row.from),$(row.to)),$(row.rp),$(row.timesteps_block)]"
        ) for row in eachrow(df)
    ]

    # - Min transport flow limit
    model[:min_transport_flow_limit] = [
        @constraint(
            model,
            flow[row.index] ≥ -lower_bound_transport_flow[row.index],
            base_name = "min_transport_flow_limit[($(row.from),$(row.to)),$(row.rp),$(row.timesteps_block)]"
        ) for row in eachrow(df)
    ]
end
