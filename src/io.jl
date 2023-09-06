export create_parameters_and_sets_from_file, save_solution_to_file

"""
    parameters, sets = create_parameters_and_sets_from_file(input_folder)

Returns two NamedTuples with all parameters and sets read and created from the
input files in the `input_folder`.
"""
function create_parameters_and_sets_from_file(input_folder::AbstractString)
    # Files names
    assets_file   = joinpath(input_folder, "assets.csv")
    profiles_file = joinpath(input_folder, "profiles.csv")
    weights_file  = joinpath(input_folder, "weights.csv")

    # Read data
    assets_df   = CSV.read(assets_file, DataFrames.DataFrame; header = 2)
    profiles_df = CSV.read(profiles_file, DataFrames.DataFrame; header = 2)
    weights_df  = CSV.read(weights_file, DataFrames.DataFrame; header = 2)

    # Sets and subsets that depend on input data
    A = s_assets = assets_df[assets_df.is_active.==true, :].asset_name         #assets in the energy system that are active
    Ap = s_assets_producer = assets_df[assets_df.asset_type.=="producer", :].asset_name  #producer assets in the energy system
    Ac = s_assets_consumer = assets_df[assets_df.asset_type.=="consumer", :].asset_name  #consumer assets in the energy system
    s_assets_investment = assets_df[assets_df.invest_method.=="invest", :].asset_name #assets with investment method in the energy system
    s_representative_periods = unique(profiles_df.rp)  #representative periods
    s_time_steps = unique(profiles_df.k)   #time steps in the RP (e.g., hours)

    # Parameters for system
    p_rp_weight = Dict((row.rp) => row.weight for row in eachrow(weights_df)) #representative period weight [h]

    # Parameters for assets
    p_profile = Dict(
        (row.asset_name, row.rp, row.k) => row.profile_value for
        row in eachrow(profiles_df)
    ) # asset profile [p.u.]
    p_output_assets =
        Dict((row.asset_name) => row.output_assets for row in eachrow(assets_df)) # output assets of asset a
    p_input_assets =
        Dict((row.asset_name) => row.input_assets for row in eachrow(assets_df)) # input assets of asset a

    # Parameters for producers
    p_variable_cost   = Dict{String,Float64}()
    p_investment_cost = Dict{String,Float64}()
    p_unit_capacity   = Dict{String,Float64}()
    p_init_capacity   = Dict{String,Float64}()
    for row in eachrow(assets_df)
        if row.asset_name in Ap
            p_variable_cost[row.asset_name] = row.variable_cost
            p_investment_cost[row.asset_name] = row.investment_cost
            p_unit_capacity[row.asset_name] = row.asset_capacity
            p_init_capacity[row.asset_name] = row.initial_capacity
        end
    end

    # Parameters for consumers
    p_peak_demand = Dict{String,Float64}()
    for row in eachrow(assets_df)
        if row.asset_name in Ac
            p_peak_demand[row.asset_name] = row.consumer_peak_demand
        end
    end

    # Subsets that depend on parameters
    s_combinations_of_flows =
        [(a, aa) for a in A, aa in A if p_output_assets[a] == aa || p_input_assets[a] == aa] #set of combitation of flows from asset a to asset aa

    params = (
        p_init_capacity = p_init_capacity,
        p_input_assets = p_input_assets,
        p_investment_cost = p_investment_cost,
        p_output_assets = p_output_assets,
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
        s_combinations_of_flows = s_combinations_of_flows,
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
