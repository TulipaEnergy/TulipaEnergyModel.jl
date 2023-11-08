export plot_single_flow, plot_graph_with_flows, plot_assets_balance

function plot_single_flow(
    solution::NamedTuple,
    sets::NamedTuple,
    asset_from::String,
    asset_to::String,
    rp::Int64,
)
    rp_partition = sets.time_intervals_per_flow[((asset_from, asset_to), rp)]
    x = 1:length(rp_partition)
    y = [solution.flow[(asset_from, asset_to), rp, b] for b in rp_partition]
    plot(x, y; title = string("Flow from ", asset_from, " to ", asset_to), legend = false)
end

#function plot_graph_with_flows()

#end

#function plot_assets_balance()

#end
