module TulipaBulb

# Packages
using JuMP
using HiGHS
using CSV
using DataFrames

# Exported functions
export optimise_investments

"""
    optimise_investments

This is a doc for optimise_investments.
It should probably be improved.
"""
function optimise_investments(input_folder::AbstractString, output_folder::AbstractString)
    # Files names
    assets_file   = joinpath(input_folder, "assets.csv")
    profiles_file = joinpath(input_folder, "profiles.csv")
    weights_file  = joinpath(input_folder, "weights.csv")

    # Read data
    assets_df   = CSV.read(assets_file, DataFrames.DataFrame; header = 2)
    profiles_df = CSV.read(profiles_file, DataFrames.DataFrame; header = 2)
    weights_df  = CSV.read(weights_file, DataFrames.DataFrame; header = 2)

    # Sets and subsets that depend on input data
    A  = assets_df[assets_df.is_active.==true, :].asset_name         #assets in the energy system that are active
    Ap = assets_df[assets_df.asset_type.=="producer", :].asset_name  #producer assets in the energy system
    Ac = assets_df[assets_df.asset_type.=="consumer", :].asset_name  #consumer assets in the energy system
    Ai = assets_df[assets_df.invest_method.=="invest", :].asset_name #assets with investment method in the energy system
    RP = unique(profiles_df.rp)  #representative periods
    K  = unique(profiles_df.k)   #time steps in the RP (e.g., hours)

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
    F = [(a, aa) for a in A, aa in A if p_output_assets[a] == aa || p_input_assets[a] == aa] #set of combitation of flows from asset a to asset aa

    # Model
    model = Model(HiGHS.Optimizer)

    # Variables
    @variable(model, 0 ≤ v_flow[F, RP, K])         #flow from asset a to asset aa [MW]
    @variable(model, 0 ≤ v_investment[Ai], Int)  #number of installed asset units [N]

    # Expressions
    e_investment_cost = @expression(
        model,
        sum(p_investment_cost[a] * p_unit_capacity[a] * v_investment[a] for a in Ai)
    )

    e_variable_cost = @expression(
        model,
        sum(
            p_rp_weight[rp] * p_variable_cost[a] * v_flow[f, rp, k] for
            a in A, f in F, rp in RP, k in K if f[1] == a
        )
    )

    # Objective function
    @objective(model, Min, e_investment_cost + e_variable_cost)

    # Constraints
    # - balance equation
    @constraint(
        model,
        c_balance[a in Ac, rp in RP, k in K],
        sum(v_flow[f, rp, k] for f in F if f[2] == a) ==
        p_profile[a, rp, k] * p_peak_demand[a]
    )

    # - maximum generation
    @constraint(
        model,
        c_max_prod[a in Ai, f in F, rp in RP, k in K; f[1] == a],
        v_flow[f, rp, k] <=
        get(p_profile, (a, rp, k), 1.0) *
        (p_init_capacity[a] + p_unit_capacity[a] * v_investment[a])
    )

    # print lp file
    write_to_file(model, "model.lp")

    # Solve model
    optimize!(model)

    # Objective function value
    println("Total cost: ", objective_value(model))

    # Writing the investment results to a CSV file
    output_file = open(joinpath(output_folder, "investments.csv"), "w")
    write(output_file, "a,InstalUnits,InstalCap_MW\n")
    for a in Ai
        write(
            output_file,
            "$a,$(value(v_investment[a])),$(value(p_unit_capacity[a]) * value(v_investment[a]))\n",
        )
    end
    close(output_file)

    return objective_value(model)
end

end # module
