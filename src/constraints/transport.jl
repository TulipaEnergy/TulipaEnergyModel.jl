export add_transport_constraints!

"""
add_transport_constraints!(model, graph, df_flows, flow, Ft, flows_investment)

Adds the transport flow constraints to the model.
"""
function add_transport_constraints!(model, variables, constraints, graph)
    ## unpack from model
    accumulated_flows_export_units = model[:accumulated_flows_export_units]
    accumulated_flows_import_units = model[:accumulated_flows_import_units]

    let table_name = :transport_flow_limit, cons = constraints[table_name]
        var_flow = variables[:flow].container

        # - Create upper limit of transport flow
        attach_expression!(
            cons,
            :upper_bound_transport_flow,
            [
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
                ) for row in eachrow(cons.indices)
            ],
        )

        # - Create lower limit of transport flow
        attach_expression!(
            cons,
            :lower_bound_transport_flow,
            [
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
                ) for row in eachrow(cons.indices)
            ],
        )

        ## Constraints that define bounds for an investable transport flow

        # - Max transport flow limit
        attach_constraint!(
            model,
            cons,
            :max_transport_flow_limit,
            [
                @constraint(
                    model,
                    var_flow[row.var_flow_index] ≤ upper_bound_transport_flow,
                    base_name = "max_transport_flow_limit[($(row.from),$(row.to)),$(row.year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]"
                ) for (row, upper_bound_transport_flow) in
                zip(eachrow(cons.indices), cons.expressions[:upper_bound_transport_flow])
            ],
        )

        # - Min transport flow limit
        attach_constraint!(
            model,
            cons,
            :min_transport_flow_limit,
            [
                @constraint(
                    model,
                    var_flow[row.var_flow_index] ≥ -lower_bound_transport_flow,
                    base_name = "min_transport_flow_limit[($(row.from),$(row.to)),$(row.year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]"
                ) for (row, lower_bound_transport_flow) in
                zip(eachrow(cons.indices), cons.expressions[:lower_bound_transport_flow])
            ],
        )
    end
end
