export add_group_constraints!

"""
    add_group_constraints!(model, graph, ...)

Adds group constraints for assets that share a common limits or bounds
"""
function add_group_constraints!(model, variables, constraints, graph, sets, groups)
    # unpack from sets
    Ai = sets[:Ai]
    Y = sets[:Y]

    assets_investment = variables[:assets_investment].lookup

    # - Group constraints for investments at each year
    assets_at_year_in_group = Dict(
        group.name => (
            (a, y) for y in Y for
            a in Ai[y] if !ismissing(graph[a].group) && graph[a].group == group.name
        ) for group in groups
    )

    for table_name in [:group_max_investment_limit, :group_min_investment_limit]
        cons = constraints[table_name]
        attach_expression!(
            cons,
            :investment_group,
            [
                @expression(
                    model,
                    sum(
                        graph[a].capacity * assets_investment[y, a] for y in Y for
                        (a, y) in assets_at_year_in_group[row.name]
                    )
                ) for row in eachrow(cons.indices)
            ],
        )
    end

    let table_name = :group_max_investment_limit, cons = constraints[table_name]
        attach_constraint!(
            model,
            cons,
            :investment_group_max_limit,
            [
                @constraint(
                    model,
                    investment_group ≤ row.max_investment_limit,
                    base_name = "investment_group_max_limit[$(row.name)]"
                ) for (row, investment_group) in
                zip(eachrow(cons.indices), cons.expressions[:investment_group])
            ],
        )
    end

    let table_name = :group_min_investment_limit, cons = constraints[table_name]
        attach_constraint!(
            model,
            cons,
            :investment_group_min_limit,
            [
                @constraint(
                    model,
                    investment_group ≥ row.min_investment_limit,
                    base_name = "investment_group_min_limit[$(row.name)]"
                ) for (row, investment_group) in
                zip(eachrow(cons.indices), cons.expressions[:investment_group])
            ],
        )
    end

    # - TODO: More group constraints e.g., limits on the accumulated investments of a group

    return
end
