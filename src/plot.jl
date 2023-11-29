export plot_single_flow, plot_final_flow_graph #, plot_assets_balance

#%%
# using TulipaEnergyModel
# using MetaGraphsNext
# using Plots
# using GraphPlot
# energy_problem = run_scenario("test/inputs/Norse")
# graph = energy_problem.graph
# rp = 1

#%%
function plot_single_flow(graph::MetaGraph, asset_from::String, asset_to::String, rp::Int64)
    rp_partition = graph[asset_from, asset_to].partitions[rp]
    x = 1:length(rp_partition)  # time dimension
    y = [graph[asset_from, asset_to].flow[(1, B)] for B in rp_partition] # flow value
    plot(
        x,
        y;
        title = string("Flow from ", asset_from, " to ", asset_to, " for RP", rp),
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

# plot_single_flow(graph, "G_imports", "Midgard_CCGT", rp)

function plot_final_flow_graph(graph::MetaGraph)
    node_labels = labels(graph) |> collect
    total_flow_cap = [
        graph[a, b].initial_capacity +
        graph[a, b].investable * graph[a, b].investment * graph[a, b].unit_capacity for
        (a, b) in edge_labels(graph)
    ] # total = initial + investable * investment * unit_capacity
    gplot(graph; nodelabel = node_labels, edgelabel = total_flow_cap)
end

function plot_final_flow_graph(energy_problem::EnergyProblem)
    plot_final_flow_graph(energy_problem.graph)
end

# plot_flow_graph(energy_problem.graph)

#function plot_assets_balance(solution)
#    plot_data = solution.assets_investment.data
#xlabel =
#    groupedbar(
#        plot_data,
#        bar_position = :stack,
#        xticks = (#:##, xlabel),
#        label = ["" ""]
#    )
#end

#function plot_all_flows(   ????
#    solution::NamedTuple,
#    sets::NamedTuple,
#    rp::Int64,
#)

#end
