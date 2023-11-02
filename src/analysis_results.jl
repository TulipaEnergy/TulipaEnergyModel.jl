using GraphPlot

sets, graph, F, solution = run_model()

# plot flow time series
from_flow = "Valhalla_Fuel_cell"
to_flow = "Valhalla_E_balance"
p = show_flow_time_series(from_flow, to_flow, 1, sets.time_steps, solution.flow)
display(p)

# plot graph with edge values
rp = 1
time = 1
edge_labels = Dict(f => solution.flow[f, rp, time] for f in F)

edge_label_list = [edge_labels[(src(e), dst(e))] for e in edges(graph)]
g = gplot(graph; edgelabel = edge_label_list)
display(g)
