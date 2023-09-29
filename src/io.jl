export create_parameters_and_sets_from_file, create_graph, save_solution_to_file

"""
    parameters, sets = create_parameters_and_sets_from_file(input_folder)

Returns two NamedTuples with all parameters and sets read and created from the
input files in the `input_folder`.
"""
function create_parameters_and_sets_from_file(input_folder::AbstractString)
    # Files names
    nodes_data_file     = joinpath(input_folder, "nodes-data.csv")
    nodes_profiles_file = joinpath(input_folder, "nodes-profiles.csv")
    # edges_data_file     = joinpath(input_folder, "edges-data.csv")
    # edges_profiles_file = joinpath(input_folder, "edges-profiles.csv")
    rep_period_file = joinpath(input_folder, "rep-periods-data.csv")

    # Read data
    nodes_data_df     = CSV.read(nodes_data_file, DataFrames.DataFrame; header = 2)
    nodes_profiles_df = CSV.read(nodes_profiles_file, DataFrames.DataFrame; header = 2)
    # edges_data_df     = CSV.read(edges_data_file, DataFrames.DataFrame; header = 2)
    # edges_nodes_profiles_df = CSV.read(edges_profiles_file, DataFrames.DataFrame; header = 2)
    rep_period_df = CSV.read(rep_period_file, DataFrames.DataFrame; header = 2)

    # Sets and subsets that depend on input data
    A = s_assets = nodes_data_df[nodes_data_df.active.==true, :].name         #assets in the energy system that are active
    Ap =
        s_assets_producer = nodes_data_df[nodes_data_df.type.=="producer", :].name  #producer assets in the energy system
    Ac =
        s_assets_consumer = nodes_data_df[nodes_data_df.type.=="consumer", :].name  #consumer assets in the energy system
    s_assets_investment = nodes_data_df[nodes_data_df.investable.==true, :].name #assets with investment method in the energy system
    s_representative_periods = unique(nodes_profiles_df.rep_period_id)  #representative periods
    s_time_steps = unique(nodes_profiles_df.time_step)   #time steps in the RP (e.g., hours)

    # Parameters for system
    p_rp_weight = Dict((row.id) => row.weight for row in eachrow(rep_period_df)) #representative period weight [h]

    # Parameters for assets
    p_profile = Dict(
        (A[row.id], row.rep_period_id, row.time_step) => row.value for
        row in eachrow(nodes_profiles_df)
    ) # asset profile [p.u.]

    # Parameters for producers
    p_variable_cost   = Dict{String,Float64}()
    p_investment_cost = Dict{String,Float64}()
    p_unit_capacity   = Dict{String,Float64}()
    p_init_capacity   = Dict{String,Float64}()
    for row in eachrow(nodes_data_df)
        if row.name in Ap
            p_variable_cost[row.name] = row.variable_cost
            p_investment_cost[row.name] = row.investment_cost
            p_unit_capacity[row.name] = row.capacity
            p_init_capacity[row.name] = row.initial_capacity
        end
    end

    # Parameters for consumers
    p_peak_demand = Dict{String,Float64}()
    for row in eachrow(nodes_data_df)
        if row.name in Ac
            p_peak_demand[row.name] = row.peak_demand
        end
    end

    params = (
        p_init_capacity = p_init_capacity,
        p_investment_cost = p_investment_cost,
        p_peak_demand = p_peak_demand,
        p_profile = p_profile,
        p_rp_weight = p_rp_weight,
        p_unit_capacity = p_unit_capacity,
        p_variable_cost = p_variable_cost,
    )
    sets = (
        s_assets = s_assets,
        s_assets_consumer = s_assets_consumer,
        s_assets_investment = s_assets_investment,
        s_assets_producer = s_assets_producer,
        s_representative_periods = s_representative_periods,
        s_time_steps = s_time_steps,
    )

    return params, sets
end

"""
    save_solution_to_file(output_file, v_investment, p_unit_capacity)

Saves the solution variable v_investment to a file "investments.csv" inside `output_file`.
The format of each row is `a,v,p*v`, where `a` is the asset indexing `v_investment`, `v`
is corresponding `v_investment` value, and `p` is the corresponding `p_unit_capacity` value.
"""
function save_solution_to_file(
    output_folder,
    s_assets_investment,
    v_investment,
    p_unit_capacity,
)
    # Writing the investment results to a CSV file
    output_file = joinpath(output_folder, "investments.csv")
    output_table = DataFrame(;
        a = s_assets_investment,
        InstalUnits = [v_investment[a] for a in s_assets_investment],
        InstalCap_MW = [p_unit_capacity[a] * v_investment[a] for a in s_assets_investment],
    )
    CSV.write(output_file, output_table)

    return
end

"""
    graph = create_graph(nodes_path, edges_path)

Read the nodes and edges data CSVs and create a graph object.
"""
function create_graph(nodes_path, edges_path)
    nodes_df = CSV.read(nodes_path, DataFrames.DataFrame; header = 2)
    edges_df = CSV.read(edges_path, DataFrames.DataFrame; header = 2)

    num_nodes = DataFrames.nrow(nodes_df)

    graph = Graphs.DiGraph(num_nodes)
    for row in eachrow(edges_df)
        Graphs.add_edge!(graph, row.from_node_id, row.to_node_id)
    end

    return graph
end
