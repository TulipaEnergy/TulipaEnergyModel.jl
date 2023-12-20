export plot_single_flow, plot_graph, plot_assets_capacity

"""
    plot_single_flow(graph::MetaGraph,              asset_from::String, asset_to::String, rp::Int64,)
    plot_single_flow(energy_problem::EnergyProblem, asset_from::String, asset_to::String, rp::Int64,)

Plot a single flow over a single representative period,
given a graph or energy problem, the "from" (exporting) asset, the "to" (importing) asset, and the representative period.
"""
#TODO Rework as Makie
function plot_single_flow(graph::MetaGraph, asset_from::String, asset_to::String, rp::Int64)
    rp_partition = graph[asset_from, asset_to].partitions[rp]
    time_dimension = 1:length(rp_partition)
    flow_value = [graph[asset_from, asset_to].flow[(rp, B)] for B in rp_partition]

    plot(
        time_dimension,
        flow_value;
        title = string("Flow from ", asset_from, " to ", asset_to, " for RP", rp),
        titlefontsize = 10,
        legend = false,
    )
end

function plot_single_flow(
    energy_problem::EnergyProblem,
    asset_from::String,
    asset_to::String,
    rp::Int64,
)
    plot_single_flow(energy_problem.graph, asset_from, asset_to, rp)
end

"""
    plot_final_flow_graph(graph::MetaGraph)
    plot_final_flow_graph(energy_problem::EnergyProblem)

Given a graph or energy problem, plot the graph with the "final" (initial + investment) flow capacities,
represented by the thickness of the graph edges, as well as displayed values.
"""
function plot_graph(graph::MetaGraph)
    nodelabelcolor = RGB(0.5, 0.5, 0.5)
    exportflowcolor = RGB(0, 0.5, 0.5)
    importflowcolor = RGB(0.5, 0, 0.5)
    assetflowcolor = RGB(0.5, 0.5, 0.5)
    nodecentercolor = RGBA(0, 0.4, 0.7, 0.5)
    nodebordercolor = RGBA(0, 0.9, 1, 0.5)

    node_names = labels(graph) |> collect

    temp_graph = DiGraph(nv(graph))
    for e in edges(graph)
        add_edge!(temp_graph, e.src, e.dst)
        if graph[node_names[e.src], node_names[e.dst]].is_transport
            add_edge!(temp_graph, e.dst, e.src)
        end
    end

    node_size = []
    node_labels = []
    border_width = []
    for a in labels(graph)
        node_capacity = graph[a].initial_capacity
        node_investment = graph[a].investable * graph[a].investment * graph[a].capacity
        push!(node_labels, "$a \n $(node_capacity + node_investment)") # "Node Name \n Capacity: ##"
        push!(node_size, node_capacity)
        push!(border_width, node_investment)
    end
    node_size = node_size * 0.8 / maximum(node_size) .+ 0.2

    edge_colors = []
    edge_width = []
    edge_labels = []
    for e in edges(temp_graph)
        from = node_names[e.src]
        to = node_names[e.dst]
        edge_data = has_edge(graph, e.src, e.dst) ? graph[from, to] : graph[to, from]

        if edge_data.is_transport
            push!(edge_colors, has_edge(graph, e.src, e.dst) ? exportflowcolor : importflowcolor)
            ttc =
                (
                    if has_edge(graph, e.src, e.dst)
                        edge_data.initial_export_capacity
                    else
                        edge_data.initial_import_capacity
                    end
                ) + edge_data.investable * edge_data.investment * edge_data.capacity
            push!(edge_labels, string(ttc))
            push!(edge_width, ttc)
        else
            push!(edge_colors, assetflowcolor)
            push!(edge_labels, "")
            push!(edge_width, 0)
        end
    end
    edge_width = edge_width * 0.8 / maximum(edge_width) .+ 0.2 # Normalize edge_width with minimum of 0.2 (just visible)

    #TODO Labels are cut off by edge of figure
    #TODO Color scheme
    #TODO Investment strokewidth

    f, ax, p = graphplot(
        temp_graph;
        node_size = node_size * 100,                # Node center size (scaled)
        # node_strokewidth = border_width * 100,    # Node border size #TODO Normalizing to self, should normalize to nodelabelsize
        node_color = nodecentercolor,               # Node center color (initial capacity)
        node_strokecolor = nodebordercolor,         # Node border color (invested capacity)
        nlabels = node_labels,
        nlabels_color = nodelabelcolor,
        nlabels_fontsize = 10.0,
        edge_width = edge_width * 10,
        arrow_size = (edge_width .+ 2) * 10,
        edge_color = edge_colors,                    # Edge color
        elabels = edge_labels,
        elabels_fontsize = 10.0,                     # Max edge label size
        elabels_color = edge_colors,                 #
        # layout = Spring(),
    )
    hidedecorations!(ax)
    hidespines!(ax)
    return f
end

function plot_graph(energy_problem::EnergyProblem)
    plot_graph(energy_problem.graph)
end

"""
    plot_assets_capacity(graph::MetaGraph)
    plot_assets_capacity(energy_problem::EnergyProblem)

Given a graph or energy problem, display a stacked bar graph of
the initial and invested capacity of each asset (initial + invested = total).
"""
function plot_assets_capacity(graph::MetaGraph)
    asset_labels = labels(graph) |> collect
    total_asset_cap = [
        graph[a].initial_capacity + graph[a].investable * graph[a].investment * graph[a].capacity for a in labels(graph)
    ] # total = initial + investable * investement * capacity
    initial_cap = [graph[a].initial_capacity for a in labels(graph)]
    investment_cap =
        [graph[a].investable * graph[a].investment * graph[a].capacity for a in labels(graph)]

    plot(
        [initial_cap, investment_cap];
        seriestype = :bar,
        xticks = (1:length(total_asset_cap), asset_labels),
        xrotation = 90,
        title = string("Total Capacity of Assets after Investment"),
        titlefontsize = 10,
        label = ["Initial Capacity" "Invested Capacity"],
    )
end

function plot_assets_capacity(energy_problem::EnergyProblem)
    plot_assets_capacity(energy_problem.graph)
end
