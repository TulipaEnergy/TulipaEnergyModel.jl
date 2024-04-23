export add_investment_constraints!

"""
add_investment_constraints!(graph, Ai, Fi, assets_investment, flows_investment)

Adds the investment constraints for all asset types and transport flows to the model
"""

function add_investment_constraints!(graph, Ai, Ase, Fi, assets_investment, flows_investment)

    # - Maximum (i.e., potential) investment limit for assets
    for a in Ai
        if !(a in Ase)
            if graph[a].capacity > 0 && !ismissing(graph[a].investment_limit)
                bound_value = _find_upper_bound(graph, Ai, Ase, a)
                JuMP.set_upper_bound(assets_investment[a], bound_value)
            end
        else # for a in Ase, i.e., storage assets with energy method
            if graph[a].capacity_storage_energy > 0 &&
               !ismissing(graph[a].investment_limit_storage_energy)
                bound_value = _find_upper_bound(graph, Ai, Ase, a)
                JuMP.set_upper_bound(assets_investment_energy[a], bound_value)
            end
        end
    end

    # - Maximum (i.e., potential) investment limit for flows
    for (u, v) in Fi
        if graph[u, v].capacity > 0 && !ismissing(graph[u, v].investment_limit)
            bound_value = _find_upper_bound(graph, Ai, Ase, u, v)
            JuMP.set_upper_bound(flows_investment[(u, v)], bound_value)
        end
    end
end

function _find_upper_bound(graph, Ai, Ase, investments...)
    if investments in Ai ∩ Ase # for investments in Ase, i.e., storage assets with energy method
        bound_value =
            graph[investments...].investment_limit_storage_energy /
            graph[investments...].capacity_strorage_energy
        if graph[investments...].investment_integer_storage_energy
            bound_value = floor(bound_value)
        end
    else
        bound_value = graph[investments...].investment_limit / graph[investments...].capacity
        if graph[investments...].investment_integer
            bound_value = floor(bound_value)
        end
    end
end
