export create_parameters_and_sets_from_file, create_graph, save_solution_to_file

"""
    parameters, sets = create_parameters_and_sets_from_file(input_folder)

Returns two NamedTuples with all parameters and sets read and created from the
input files in the `input_folder`.
"""
function create_parameters_and_sets_from_file(input_folder::AbstractString)
    # Read data
    fillpath(filename) = joinpath(input_folder, filename)
    assets_data_df     = read_csv_with_schema(fillpath("assets-data.csv"), AssetData)
    assets_profiles_df = read_csv_with_schema(fillpath("assets-profiles.csv"), AssetProfiles)
    # flows_data_df     = read_csv_with_schema(fillpath("flows-data.csv"), FlowData)
    # flows_profiles_df = read_csv_with_schema(fillpath("flows-profiles.csv"), FlowProfiles)
    rep_period_df = read_csv_with_schema(fillpath("rep-periods-data.csv"), RepPeriodData)

    # Sets and subsets that depend on input data
    A = assets = assets_data_df[assets_data_df.active.==true, :].name         #assets in the energy system that are active
    Ap = assets_producer = assets_data_df[assets_data_df.type.=="producer", :].name  #producer assets in the energy system
    Ac = assets_consumer = assets_data_df[assets_data_df.type.=="consumer", :].name  #consumer assets in the energy system
    assets_investment = assets_data_df[assets_data_df.investable.==true, :].name #assets with investment method in the energy system
    rep_periods = unique(assets_profiles_df.rep_period_id)  #representative periods
    time_steps = unique(assets_profiles_df.time_step)   #time steps in the RP (e.g., hours)

    # Parameters for system
    rep_weight = Dict((row.id) => row.weight for row in eachrow(rep_period_df)) #representative period weight [h]

    # Parameters for assets
    profile = Dict(
        (A[row.id], row.rep_period_id, row.time_step) => row.value for
        row in eachrow(assets_profiles_df)
    ) # asset profile [p.u.]

    # Parameters for producers
    variable_cost   = Dict{String,Float64}()
    investment_cost = Dict{String,Float64}()
    unit_capacity   = Dict{String,Float64}()
    init_capacity   = Dict{String,Float64}()
    for row in eachrow(assets_data_df)
        if row.name in Ap
            variable_cost[row.name] = row.variable_cost
            investment_cost[row.name] = row.investment_cost
            unit_capacity[row.name] = row.capacity
            init_capacity[row.name] = row.initial_capacity
        end
    end

    # Parameters for consumers
    peak_demand = Dict{String,Float64}()
    for row in eachrow(assets_data_df)
        if row.name in Ac
            peak_demand[row.name] = row.peak_demand
        end
    end

    params = (
        init_capacity = init_capacity,
        investment_cost = investment_cost,
        peak_demand = peak_demand,
        profile = profile,
        rep_weight = rep_weight,
        unit_capacity = unit_capacity,
        variable_cost = variable_cost,
    )
    sets = (
        assets = assets,
        assets_consumer = assets_consumer,
        assets_investment = assets_investment,
        assets_producer = assets_producer,
        rep_periods = rep_periods,
        time_steps = time_steps,
    )

    return params, sets
end

"""
    read_csv_with_schema(file_path, schema)

Reads the csv with file_name at location path validating the data using the schema.
It is assumes that the file's header is at the second row.
The first row of the file contains some metadata information that is not used.
"""
function read_csv_with_schema(file_path, schema; csvargs...)
    # Get the schema names and types in the form of Dictionaries
    col_types = zip(fieldnames(schema), fieldtypes(schema)) |> Dict
    df = CSV.read(
        file_path,
        DataFrames.DataFrame;
        header = 2,
        types = col_types,
        strict = true,
        csvargs...,
    )

    return df
end

"""
    save_solution_to_file(output_file, v_investment, unit_capacity)

Saves the solution variable v_investment to a file "investments.csv" inside `output_file`.
The format of each row is `a,v,p*v`, where `a` is the asset indexing `v_investment`, `v`
is corresponding `v_investment` value, and `p` is the corresponding `unit_capacity` value.
"""
function save_solution_to_file(
    output_folder,
    assets_investment,
    v_investment,
    unit_capacity,
)
    # Writing the investment results to a CSV file
    output_file = joinpath(output_folder, "investments.csv")
    output_table = DataFrame(;
        a = assets_investment,
        InstalUnits = [v_investment[a] for a in assets_investment],
        InstalCap_MW = [unit_capacity[a] * v_investment[a] for a in assets_investment],
    )
    CSV.write(output_file, output_table)

    return
end

"""
    graph = create_graph(assets_path, flows_path)

Read the assets and flows data CSVs and create a graph object.
"""
function create_graph(assets_path, flows_path)
    assets_df = CSV.read(assets_path, DataFrames.DataFrame; header = 2)
    flows_df = CSV.read(flows_path, DataFrames.DataFrame; header = 2)

    num_assets = DataFrames.nrow(assets_df)

    graph = Graphs.DiGraph(num_assets)
    for row in eachrow(flows_df)
        Graphs.add_edge!(graph, row.from_asset_id, row.to_asset_id)
    end

    return graph
end
