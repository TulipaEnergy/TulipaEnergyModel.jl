export add_investment_constraints!

function add_investment_constraints!(graph, Ai, Fi, assets_investment, flows_investment)

    # - Maximum (i.e., potential) investment limit for assets
    for a ∈ Ai
        if graph[a].capacity > 0 && !ismissing(graph[a].investment_limit)
            JuMP.set_upper_bound(
                assets_investment[a],
                graph[a].investment_limit / graph[a].capacity,
            )
        end
    end

    # - Maximum (i.e., potential) investment limit for flows
    for (u, v) ∈ Fi
        if graph[u, v].capacity > 0 && !ismissing(graph[u, v].investment_limit)
            JuMP.set_upper_bound(
                flows_investment[(u, v)],
                graph[u, v].investment_limit / graph[u, v].capacity,
            )
        end
    end
end
