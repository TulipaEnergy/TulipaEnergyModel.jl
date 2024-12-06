export add_investment_constraints!

"""
    add_investment_constraints!(graph, Ai, Ase, Fi, assets_investment, assets_investment_energy, flows_investment)

Adds the investment constraints for all asset types and transport flows to the model
"""
function add_investment_constraints!(graph, sets, variables)
    # TODO: Since this function is defining bound constraints, it doesn't need the `model`
    # When we refactor the signatures to look the same, we should consider naming it differently
    # TODO: Verify if it's possible and reasonable to move the bound definition to when the
    # indices are created
    # unpack from sets
    Ai = sets[:Ai]
    Ase = sets[:Ase]
    Fi = sets[:Fi]
    Y = sets[:Y]

    assets_investment = variables[:assets_investment].lookup
    assets_investment_energy = variables[:assets_investment_energy].lookup
    flows_investment = variables[:flows_investment].lookup
end

function _find_upper_bound(graph, year, investments...; is_bound_for_energy = false)
    graph_investment = graph[investments...]
    if !is_bound_for_energy
        bound_value = graph_investment.investment_limit[year] / graph_investment.capacity
        if graph_investment.investment_integer
            bound_value = floor(bound_value)
        end
    else
        bound_value =
            graph_investment.investment_limit_storage_energy[year] /
            graph_investment.capacity_storage_energy
        if graph_investment.investment_integer_storage_energy
            bound_value = floor(bound_value)
        end
    end
    return bound_value
end
