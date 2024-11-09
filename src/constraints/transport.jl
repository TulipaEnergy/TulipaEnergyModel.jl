export add_transport_constraints!

"""
add_transport_constraints!(model, graph, df_flows, flow, Ft, flows_investment)

Adds the transport flow constraints to the model.
"""

function add_transport_constraints!(
    model,
    graph,
    sets,
    variables,
    accumulated_flows_export_units,
    accumulated_flows_import_units,
)
    ## unpack from sets
    Ft = sets[:Ft]

    ## unpack from variables
    flows_indices = variables[:flow].indices
    flow = variables[:flow].container

    ## Expressions used by transport flow constraints
    # Filter flows_indices to flows only for transport assets
    transport_flows_indices =
        filter([:from, :to] => (from, to) -> (from, to) ∈ Ft, flows_indices; view = true)

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
                row.time_block_start:row.time_block_end,
                1.0,
            ) *
            graph[row.from, row.to].capacity *
            accumulated_flows_export_units[row.year, (row.from, row.to)]
        ) for row in eachrow(transport_flows_indices)
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
                row.time_block_start:row.time_block_end,
                1.0,
            ) *
            graph[row.from, row.to].capacity *
            accumulated_flows_import_units[row.year, (row.from, row.to)]
        ) for row in eachrow(transport_flows_indices)
    ]

    ## Constraints that define bounds for a transport flow Ft

    # - Max transport flow limit
    model[:max_transport_flow_limit] = [
        @constraint(
            model,
            flow[row.index] ≤ upper_bound_transport_flow[idx],
            base_name = "max_transport_flow_limit[($(row.from),$(row.to)),$(row.year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]"
        ) for (idx, row) in enumerate(eachrow(transport_flows_indices))
    ]

    # - Min transport flow limit
    model[:min_transport_flow_limit] = [
        @constraint(
            model,
            flow[row.index] ≥ -lower_bound_transport_flow[idx],
            base_name = "min_transport_flow_limit[($(row.from),$(row.to)),$(row.year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]"
        ) for (idx, row) in enumerate(eachrow(transport_flows_indices))
    ]
end
