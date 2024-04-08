export add_investment_constraints!

"""
add_investment_constraints!(graph, Ai, Fi, assets_investment, flows_investment)

Adds the investment constraints for all asset types and transport flows to the model
"""

function add_investment_constraints!(graph, Ai, Fi, assets_investment, flows_investment)

    # - Maximum (i.e., potential) investment limit for assets
    for a in Ai
        if graph[a].capacity > 0 && !ismissing(graph[a].investment_limit)
            JuMP.set_upper_bound(
                assets_investment[a],
                if graph[a].investment_integer
                    floor(graph[a].investment_limit / graph[a].capacity)
                else
                    graph[a].investment_limit / graph[a].capacity
                end,
            )
        end
    end

    # - Maximum (i.e., potential) investment limit for flows
    for (u, v) in Fi
        if graph[u, v].capacity > 0 && !ismissing(graph[u, v].investment_limit)
            JuMP.set_upper_bound(
                flows_investment[(u, v)],
                if graph[u, v].investment_integer
                    floor(graph[u, v].investment_limit / graph[u, v].capacity)
                else
                    graph[u, v].investment_limit / graph[u, v].capacity
                end,
            )
        end
    end
end
