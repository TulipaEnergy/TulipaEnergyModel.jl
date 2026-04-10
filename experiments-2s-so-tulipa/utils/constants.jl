# Marker and color mappings for plots
const MARKER_MAP = Dict("per_scenario" => :utriangle, "cross_scenario" => :circle)

const LINE_MAP = Dict("per_scenario" => :solid, "cross_scenario" => :dot)

const COLOR_MAP_weight =
    Dict("dirac" => :red, "convex" => :black, "conical" => :green, "conical_bounded" => :yellow)
const COLOR_MAP_method = Dict(
    "convex_hull" => :black,
    "convex_hull_with_null" => :yellow,
    "conical_hull" => :green,
    # "k_means" => :blue,
    # "k_medoids" => :orange
)

const FILLER_MAP =
    Dict("dirac" => :white, "convex" => :black, "conical" => :green, "conical_bounded" => :yellow)
const VALUE_MAP = Dict(
    "rel_regret" => "Relative regret",
    "num_loss_of_load_e_demand" => "Number of timesteps with electricity loss of load",
    "num_loss_of_load_h2_demand" => "Number of timesteps with hydrogen loss of load",
    "num_loss_of_load_tot" => "Total number of timesteps with loss of load",
    "time_to_cluster" => "Time to cluster (s)",
    "time_to_create" => "Time to create (s)",
    "time_to_solve" => "Time to solve (s)",
    "total_time" => "Total time (s)",
    "water_borrowed" => "Water borrowed",
)

const LEGEND_METHOD_MAP = Dict(
    "convex_hull" => "Convex hull",
    "convex_hull_with_null" => "Bounded conical hull",
    "conical_hull" => "Conical hull",
)
