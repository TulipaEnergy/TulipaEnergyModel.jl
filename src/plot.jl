export plot_single_flow, plot_graph, plot_assets_capacity

"""
    plot_single_flow(graph,          asset_from, asset_to, rp)
    plot_single_flow(energy_problem, asset_from, asset_to, rp)

Plot a single flow over a single representative period, given a graph or energy problem,
the "from" (exporting) asset, the "to" (importing) asset, and the representative period.

"""
#TODO Rework using CairoMakie instead of Plots
function plot_single_flow(graph::MetaGraph, asset_from::String, asset_to::String, rp::Int64)
    rp_partition = graph[asset_from, asset_to].partitions[rp]
    time_dimension = 1:length(rp_partition)
    flow_value = [graph[asset_from, asset_to].flow[(rp, B)] for B in rp_partition]

    Plots.plot(
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
    plot_final_flow_graph(graph)
    plot_final_flow_graph(energy_problem)

Given a graph or energy problem, plot the graph with the "final" (initial + investment) flow capacities,
represented by the thickness of the graph edges, as well as displayed values.
"""
function plot_graph(graph::MetaGraph)
    # Choose colors
    nodelabelcolor = RGB(0.345, 0.164, 0.376)
    transportflowcolor = RGB(1, 0.647, 0)
    assetflowcolor = RGB(0.988, 0.525, 0.110)
    nodecolor = RGBA(0.345, 0.164, 0.376, 0.5)

    node_labels = labels(graph) |> collect

    # Create a temporary graph that has arrows both directions for transport
    temp_graph = DiGraph(nv(graph))
    for e in edges(graph)
        add_edge!(temp_graph, e.src, e.dst)
        if graph[node_names[e.src], node_names[e.dst]].is_transport
            add_edge!(temp_graph, e.dst, e.src)
        end
    end

    # Calculate node size based on initial and investment capacity
    node_size = []
    node_names = []
    for a in node_labels
        node_total_capacity =
            graph[a].initial_capacity +
            graph[a].investable * graph[a].investment * graph[a].capacity
        push!(node_names, "$a \n $(node_total_capacity)") # "Node Name, Capacity: ##"
        push!(node_size, node_total_capacity)
    end
    node_size = node_size * 98 / maximum(node_size) .+ 5

    # Calculate edge width (and set color) depending on type and (if transport) capacity
    edge_colors = []
    edge_width = []
    edge_labels = []
    for e in edges(temp_graph)
        from = node_names[e.src]
        to = node_names[e.dst]
        edge_data = has_edge(graph, e.src, e.dst) ? graph[from, to] : graph[to, from]

        if edge_data.is_transport
            # Compare temp_graph to graph to determine export vs. import edges
            total_trans_cap =
                (
                    if has_edge(graph, e.src, e.dst)
                        edge_data.initial_export_capacity
                    else
                        edge_data.initial_import_capacity
                    end
                ) + edge_data.investable * edge_data.investment * edge_data.capacity
            push!(edge_labels, string(total_trans_cap))
            push!(edge_width, total_trans_cap)
            push!(edge_colors, transportflowcolor)
        else
            push!(edge_labels, "")
            push!(edge_width, 0)
            push!(edge_colors, assetflowcolor)
        end
    end
    edge_width = edge_width * 0.9 / (maximum(edge_width) == 0 ? 1 : maximum(edge_width)) .+ 0.1 # Normalize edge_width with minimum of 0.1 (just visible)

    #TODO Show initial vs investment somehow (couldn't get node stroke to work)
    f, ax, p = graphplot(
        temp_graph;
        node_size = node_size,
        node_strokewidth = 0,
        node_color = nodecolor,
        ilabels = node_names,
        ilabels_color = nodelabelcolor,
        ilabels_fontsize = 10.0,
        edge_width = edge_width * 10,
        arrow_size = (edge_width .+ 2) * 10,
        edge_color = edge_colors,
        elabels = edge_labels,
        elabels_fontsize = 10.0,
        elabels_color = edge_colors,
    )

    #TODO Make these axis adjustments a calculation (so labels aren't cut off)
    CairoMakie.xlims!(ax, -5.5, 5.5)
    CairoMakie.ylims!(ax, -5, 6)
    hidedecorations!(ax)
    hidespines!(ax)

    return f
end

function plot_graph(energy_problem::EnergyProblem)
    plot_graph(energy_problem.graph)
end

"""
    plot_assets_capacity(graph)
    plot_assets_capacity(energy_problem)

Given a graph or energy problem, display a stacked bar graph of
the initial and invested capacity of each asset (initial + invested = total).
"""
#TODO Rework using CairoMakie instead of Plots
function plot_assets_capacity(graph::MetaGraph)
    asset_labels = labels(graph) |> collect

    total_asset_cap = [
        graph[a].initial_capacity + graph[a].investable * graph[a].investment * graph[a].capacity for a in asset_labels
    ]
    initial_cap = [graph[a].initial_capacity for a in asset_labels]
    investment_cap =
        [graph[a].investable * graph[a].investment * graph[a].capacity for a in asset_labels]

    Plots.plot(
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
