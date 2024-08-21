# export add_ramping_and_unit_commitment_constraints!

# """
# add_ramping_and_unit_commitment_constraints!(graph, )

# Adds the ramping constraints for producer and conversion assets where ramping = true in assets_data
# """
# function add_ramping_constraints!(model, graph, df_flows, flow, Auc, Auc_basic, units_on, Ai)

#     # TODO: Add Ar to schema, structures and input data
#     # TODO: Fix indices/sets (see TODOs throughout)
#     #  - Implement yes/no ramping/UC combos (4 total)
#     #  - Issue with defining expressions for subset of df_flows is that index is still df_flows when you try to reference it later
#     #    - Look at consumer.jl to see if that implementation would work
#     #  - row.index is an actual column of df_flows
#     #  - Maybe something like this? df_Auc = filter(:from => ∈(Auc), df_flows; view = true)
#     # TODO: Fix init cap units vs init cap in code and input data (separate PR?)
#     # TODO: Separate UC into second function (or change function name)

#     ## Expressions used by the ramping and unit commitment constraints
#     # - This is availability*capacity*units_on
#     temp_avail_production = [
#         @expression(
#             model,
#             profile_aggregation(
#                 Statistics.mean,
#                 graph[row.from].rep_periods_profiles,
#                 ("availability", row.rep_period),
#                 row.timesteps_block,
#                 1.0,
#             ) *
#             graph[row.from].capacity *
#             units_on[row.from]
#         ) for row in eachrow(df_flows) # TODO This should probably iterate over something smaller than df_flows, but that would mess up the index
#     ] # TODO Does this need an iterator for rp and k?

#     # - Flow that is above the minimum operating point of the asset
#     flow_above_min_oper_point =
#         model[:flow_above_min_oper_point] = [
#             @expression(
#                 model,
#                 flow[row.index] - graph[row.from].min_oper_point * temp_avail_production[row.index] # This row.index is probably wrong
#             ) for row in eachrow(df_flows) # TODO This should probably iterate over something smaller than df_flows, but that would mess up the index
#         ]

#     ## Unit Commitment Constraints (basic implementation - more advanced will be added in 2025)
#     # - Limit to the units on (i.e. commitment) variable
#     model[:limit_units_on] = [
#         @constraint(
#             model,
#             units_on[row.from] ≤ graph[row.from].initial_capacity + assets_investment[row.from] # TODO: Fix init_cap should be init_units
#         ) for row in eachrow(df_flows) if row.from ∈ Auc
#     ]

#     # - Minimum output flow above the minimum operating point
#     model[:min_unit_commitment] = [
#         @constraint(model, flow_above_min_oper_point[row.index] ≥ 0) for
#         row in eachrow(df_flows) if row.from ∈ Auc
#     ]

#     # - Maximum output flow above the minimum operating point
#     model[:max_unit_commitment] = [
#         if row.from ∈ Auc_basic
#             @constraint(
#                 model,
#                 flow_above_min_oper_point[row.index] ≤ # This row.index is probably wrong
#                 (1 - graph[row.from].min_oper_point) * temp_avail_production[row.index] # This row.index is probably wrong
#             )
#             # TODO: else for Auc_advanced?
#         end for row in eachrow(df_flows) if row.from ∈ Auc
#     ]

#     ## Ramping Constraints
#     # - Maximum ramp-UP rate limit to the flow above the operating point
#     model[:max_ramp_up] = [
#         if row.from ∈ Ar
#             @constraint(
#                 model,
#                 flow_above_min_oper_point[row.index] - flow_above_min_oper_point[row.index-1] ≤ # TODO: This row.index is probably wrong
#                 graph[row.from].max_ramp_up * temp_avail_production[row.index] # TODO: This row.index is probably wrong
#             )
#         end for row in eachrow(df_flows)
#     ]

#     # - Maximum ramp-DOWN rate limit to the flow above the operating point
#     model[:max_ramp_down] = [
#         if row.from ∈ Ar
#             @constraint(
#                 model,
#                 flow_above_min_oper_point[row.index] - flow_above_min_oper_point[row.index-1] ≥ # TODO: This row.index is probably wrong
#                 -graph[row.from].max_ramp_down * temp_avail_production[row.index] # TODO: This row.index is probably wrong
#                 # TODO: Check that this simplification is okay with the negative
#                 # OR (move negative):
#                 # graph[row.from].max_ramp_down * -temp_production[row.index]
#                 #
#                 # OR (original):
#                 # -profile_aggregation(
#                 #     Statistics.mean,
#                 #     graph[row.from].rep_periods_profiles,
#                 #     ("availability", row.rep_period),
#                 #     row.timesteps_block,
#                 #     1.0,
#                 # ) *
#                 # graph[row.from].capacity *
#                 # graph[row.from].max_ramp_down *
#                 # units_on[row.from]
#             )
#         end for row in eachrow(df_flows)
#     ]
# end
