using Graphs, MetaGraphsNext

struct AssetData
    name::String
    type::Symbol
    can_invest::Bool
end

struct FlowData
    capacity::Int
end

function create_graph_data(params, sets)
    _graph = DiGraph(length(sets.s_assets))
    for flow in sets.s_combinations_of_flows
        i = findfirst(flow[1] .== sets.s_assets)
        j = findfirst(flow[2] .== sets.s_assets)
        add_edge!(_graph, (i, j))
    end

    type_of_asset(a) =
        if a in sets.s_assets_consumer
            return :consumer
        elseif a in sets.s_assets_producer
            return :producer
        else
            return :unknown
        end

    can_invest(a) = a in sets.s_assets_investment

    vertices_description =
        [a => AssetData(a, type_of_asset(a), can_invest(a)) for a in sets.s_assets]
    edges_description =
        [e => FlowData(params.p_unit_capacity[e[1]]) for e in sets.s_combinations_of_flows]
    graph = MetaGraph(_graph, vertices_description, edges_description)
    return graph
end
