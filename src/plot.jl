export plot_single_flow, plot_final_flow_graph, plot_assets_capacity

"""
    plot_single_flow(graph::MetaGraph,              asset_from::String, asset_to::String, rp::Int64,)
    plot_single_flow(energy_problem::EnergyProblem, asset_from::String, asset_to::String, rp::Int64,)

Plot a single flow over a single representative period,
given a graph or energy problem, the "from" (exporting) asset, the "to" (importing) asset, and the representative period.
"""
function plot_single_flow(graph::MetaGraph, asset_from::String, asset_to::String, rp::Int64)
    rp_partition = graph[asset_from, asset_to].partitions[rp]
    time_dimension = 1:length(rp_partition)
    flow_value = [graph[asset_from, asset_to].flow[(1, B)] for B in rp_partition]

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
function plot_final_flow_graph(graph::MetaGraph)
    # node_names = labels(graph) |> collect
    node_labels = [
        string(
            a,
            "  \n Capacity:  ",
            (
                graph[a].initial_capacity +
                graph[a].investable * graph[a].investment * graph[a].capacity
            ),
        ) for (a) in labels(graph)
    ] # "Node Name \n Capacity: ##"
    # println(node_labels)

    total_flowAtoB_cap = [
        graph[a, b].initial_export_capacity +
        graph[a, b].investable * graph[a, b].investment * graph[a, b].capacity for
        (a, b) in edge_labels(graph)
    ]

    total_flowBtoA_cap = [
        graph[a, b].initial_import_capacity +
        graph[a, b].investable * graph[a, b].investment * graph[a, b].capacity for
        (a, b) in edge_labels(graph)
    ]

    gplot(
        graph;
        arrows = false,
        nodelabel = node_labels,
        #edgelabel = total_flow_cap,
        nodelabelc = "gray",
        edgelabelc = "orange",
        NODELABELSIZE = 3.0,
        EDGELABELSIZE = 3.0,
        # linetype = "curve",
        #EDGELINEWIDTH = [x / maximum(total_flow_cap) + 0.1 for x in total_flow_cap],
    )
end

function plot_final_flow_graph(energy_problem::EnergyProblem)
    plot_final_flow_graph(energy_problem.graph)
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
