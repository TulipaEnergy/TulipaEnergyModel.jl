export add_group_constraints!

"""
    add_group_constraints!(model, graph, ...)

Adds group constraints for assets that share a common limits or bounds
"""
function add_group_constraints!(model, graph, Y, Ai, assets_investment, groups)

    # - Group constraints for investments at each year
    assets_at_year_in_group = Dict(
        group => (
            (a, y) for y in Y for
            a in Ai[y] if !ismissing(graph[a].group) && graph[a].group == group.name
        ) for group in groups
    )
    @expression(
        model,
        investment_group[group in groups],
        if group.invest_method
            sum(
                graph[a].capacity * assets_investment[y, a] for y in Y for
                (a, y) in assets_at_year_in_group[group]
            )
        end
    )

    groups_with_max_investment_limit =
        (group for group in groups if !ismissing(group.max_investment_limit))
    model[:investment_group_max_limit] = [
        @constraint(
            model,
            investment_group[group] ≤ group.max_investment_limit,
            base_name = "investment_group_max_limit[$(group.name)]"
        ) for group in groups_with_max_investment_limit
    ]

    groups_with_min_investment_limit =
        (group for group in groups if !ismissing(group.min_investment_limit))
    model[:investment_group_min_limit] = [
        @constraint(
            model,
            investment_group[group] ≥ group.min_investment_limit,
            base_name = "investment_group_min_limit[$(group.name)]"
        ) for group in groups_with_min_investment_limit
    ]

    # - TODO: More group constraints e.g., limits on the accumulated investments of a group

end
