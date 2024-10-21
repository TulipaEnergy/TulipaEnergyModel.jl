export add_transport_constraints!

"""
add_transport_constraints!(model, graph, df_flows, flow, Ft, flows_investment)

Adds the transport flow constraints to the model.
"""

function add_transport_constraints!(
    model,
    graph,
    df_flows,
    flow,
    sets,
    accumulated_flows_export_units,
    accumulated_flows_import_units,
    flows_investment,
)
    Ft = sets[:Ft]
    ## Expressions used by transport flow constraints
    # Filter df_flows to flows only for transport assets
    df = filter([:from, :to] => (from, to) -> (from, to) ∈ Ft, df_flows; view = true)

    # - Create upper limit of transport flow
    upper_bound_transport_flow = [
        @expression(
            model,
            profile_aggregation(
                Statistics.mean,
                graph[row.from, row.to].rep_periods_profiles,
                row.year,
                row.year,
                ("availability", row.rep_period),
                row.timesteps_block,
                1.0,
            ) *
            graph[row.from, row.to].capacity *
            accumulated_flows_export_units[row.year, (row.from, row.to)]
        ) for row in eachrow(df)
    ]

    # - Create lower limit of transport flow
    lower_bound_transport_flow = [
        @expression(
            model,
            profile_aggregation(
                Statistics.mean,
                graph[row.from, row.to].rep_periods_profiles,
                row.year,
                row.year,
                ("availability", row.rep_period),
                row.timesteps_block,
                1.0,
            ) *
            graph[row.from, row.to].capacity *
            accumulated_flows_import_units[row.year, (row.from, row.to)]
        ) for row in eachrow(df)
    ]

    ## Constraints that define bounds for a transport flow Ft

    # - Max transport flow limit
    model[:max_transport_flow_limit] = [
        @constraint(
            model,
            flow[row.index] ≤ upper_bound_transport_flow[idx],
            base_name = "max_transport_flow_limit[($(row.from),$(row.to)),$(row.year),$(row.rep_period),$(row.timesteps_block)]"
        ) for (idx, row) in enumerate(eachrow(df))
    ]

    # - Min transport flow limit
    model[:min_transport_flow_limit] = [
        @constraint(
            model,
            flow[row.index] ≥ -lower_bound_transport_flow[idx],
            base_name = "min_transport_flow_limit[($(row.from),$(row.to)),$(row.year),$(row.rep_period),$(row.timesteps_block)]"
        ) for (idx, row) in enumerate(eachrow(df))
    ]
end
