export add_group_constraints!

"""

add_group_constraints!(graph, Ai, assets_investment, groups)

Adds group constraints for assets that share a common limits or bounds

"""

function add_group_constraints!(model, graph, Ai, assets_investment, groups)

    # - Investment group constraints
    @expression(
        model,
        investment_group[group in groups],
        if group.invest_method == true
            sum(
                assets_investment[a] for
                a in Ai if !ismissing(graph[a].group) && graph[a].group == group.name
            )
        end
    )
    model[:investment_group_max_limit] = [
        @constraint(
            model,
            investment_group[group] ≤ group.max_investment_limit,
            base_name = "investment_group_max_limit[$(group.name)]"
        ) for group in groups if !ismissing(group.max_investment_limit)
    ]
    model[:investment_group_min_limit] = [
        @constraint(
            model,
            investment_group[group] ≤ group.min_investment_limit,
            base_name = "investment_group_min_limit[$(group.name)]"
        ) for group in groups if !ismissing(group.min_investment_limit)
    ]

    # - TODO: More group constraints

end
