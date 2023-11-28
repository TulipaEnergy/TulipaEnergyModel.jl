export plot_single_flow, plot_flow_graph, plot_assets_balance

function plot_single_flow(graph, asset_from::String, asset_to::String, rp::Int64)
    plot(rp_time_thingy)
end

#function plot_single_flow(
#    solution::NamedTuple,
#    sets::NamedTuple,
#    asset_from::String,
#    asset_to::String,
#    rp::Int64,
#)
#    rp_partition = sets.rp_partitions_flows[((asset_from, asset_to), rp)]
#    x = 1:length(rp_partition)
#    y = [solution.flow[(asset_from, asset_to), rp, b] for b in rp_partition]
#    plot(x, y; title = string("Flow from ", asset_from, " to ", asset_to), legend = false)
#end

#function plot_flow_graph(
#    graph,
#    sets::NamedTuple,
#    solution::NamedTuple,
#    parameters::NamedTuple,
#)
#
#    # Total the final flow capacity by adding initial plus investment
#    final_flow_cap = copy(parameters.flows_unit_capacity)
#    for f in sets.flows
#        if parameters.flows_investable[f]
#            final_flow_cap[f] += solution.flows_investment[f]
#        end
#    end
#    print(
#        "The TYPE of final_flow_cap is ",
#        typeof(final_flow_cap),
#        " which does not match the Vector that gplot expects.",
#    )
#
#    #gplot(graph; nodelabel = sets.assets, edgelabel = final_flow_cap)
#end

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
