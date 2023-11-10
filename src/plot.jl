export plot_single_flow, plot_flow_graph, plot_assets_balance

function plot_single_flow(
    solution::NamedTuple,
    sets::NamedTuple,
    asset_from::String,
    asset_to::String,
    rp::Int64,
)
    rp_partition = sets.rp_partitions_flows[((asset_from, asset_to), rp)]
    x = 1:length(rp_partition)
    y = [solution.flow[(asset_from, asset_to), rp, b] for b in rp_partition]
    plot(x, y; title = string("Flow from ", asset_from, " to ", asset_to), legend = false)
end

#TODO Add more detail in graphics - scaling/coloring based on solution values
function plot_flow_graph(graph, sets, solution)
    #total_flow_capacity = parameters.flows_unit_capacity + solution.flows_investment       # Need help from Abel to unpack these gracefully
    total_flow_capacity = 10
    gplot(graph; nodelabel = sets.assets, edgelinewidth = total_flow_capacity)
end

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
