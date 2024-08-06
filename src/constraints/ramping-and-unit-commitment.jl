export add_ramping_constraints!

"""
add_ramping_constraints!(graph, )

Adds the ramping constraints for producer and conversion assets where unit_commitment = true in assets_data
"""
function add_ramping_constraints!(model, graph, df_flows, flow, F, Auc, units_on, dataframes)
    ## Expressions used by the ramping and unit commitment constraints

    # - Flow that is above the minimum operating point of the asset
    flow_above_min_oper_point = [
        if row.from ∈ Auc               # Not sure if I should be working in an asset df or flow df
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

    for a in Auc
        # Maximum ramp-UP rate limit to the flow above the operating point

        # Maximum ramp-DOWN rate limit to the flow above the operating point

    end
end
