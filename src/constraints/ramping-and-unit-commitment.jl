export add_ramping_constraints!

"""
add_ramping_constraints!(graph, )

Adds the ramping constraints for producer and conversion assets where unit_commitment = true in assets_data
"""
function add_ramping_constraints!(graph, Auc)
    ## Expressions used by the ramping and unit commitment constraints
    # - Flow that is above the minimum operating point of the asset
    flow_above_min_oper_point = [
    #v_flow - asset_avail_profile(rp, timeblock) * asset_capacity * ASSET_MIN_OPERATING_POINT
    ]

    for a in Auc
        # Maximum ramp-UP rate limit to the flow above the operating point

        # Maximum ramp-DOWN rate limit to the flow above the operating point

    end
end
