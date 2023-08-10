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
    assets_file       = joinpath(input_folder, "assets.csv")
    availability_file = joinpath(input_folder, "availability.csv")
    demand_file       = joinpath(input_folder, "demand.csv")
    weights_file      = joinpath(input_folder, "weights.csv")

    # Read data
    assets_df       = CSV.read(assets_file, DataFrames.DataFrame)
    availability_df = CSV.read(availability_file, DataFrames.DataFrame)
    demand_df       = CSV.read(demand_file, DataFrames.DataFrame)
    weights_df      = CSV.read(weights_file, DataFrames.DataFrame)

    # Sets
    A  = assets_df.a         #assets in the energy system
    RP = weights_df.rp       #representative periods
    K  = unique(demand_df.k) #time steps in the RP (e.g., hours)

    # Parameters pVarCost,pInvCost,pUnitCap,pIniCap
    p_variable_cost   = Dict((row.a) => row.pVarCost for row in eachrow(assets_df))       #variable   cost  of asset units [kEUR/MWh]
    p_investment_cost = Dict((row.a) => row.pInvCost for row in eachrow(assets_df))       #investment cost  of asset units [kEUR/MW/year]
    p_unit_capacity   = Dict((row.a) => row.pUnitCap for row in eachrow(assets_df))       #capacity         of asset units [MW]
    p_init_capacity   = Dict((row.a) => row.pInitCap for row in eachrow(assets_df))       #initial capacity of asset units [MW]
    p_availability    = Dict((row.a, row.rp, row.k) => row.pAviProf for row in eachrow(availability_df)) #availability profile [p.u.]
    p_demand          = Dict((row.rp, row.k) => row.pDemand for row in eachrow(demand_df))       #demand per representative period [MW]
    p_rp_weight       = Dict((row.rp) => row.pWeight for row in eachrow(weights_df))      #representative period weight [h]

    # Methods
    Ai = [a for a in A if p_unit_capacity[a] * p_investment_cost[a] > 0.0] #assets that can be invested in

    # Model
    model = Model(HiGHS.Optimizer)

    # Variables
    @variable(model, 0 ≤ v_flow[A, RP, K])       #flow [MW]
    @variable(model, 0 ≤ v_investment[Ai], Int)  #number of installed asset units [N]

    # Expressions
    e_investment_cost = @expression(
        model,
        sum(p_investment_cost[a] * p_unit_capacity[a] * v_investment[a] for a in Ai)
    )
    # e_investment_cost = sum(p_investment_cost[a] * p_unit_capacity[a] * v_investment[a] for a in Ai)
    e_variable_cost = @expression(
        model,
        sum(
            p_rp_weight[rp] * p_variable_cost[a] * v_flow[a, rp, k] for a in A,
            rp in RP, k in K
        )
    )

    # Objective function
    @objective(model, Min, e_investment_cost + e_variable_cost)

    # Constraints
    # - balance equation
    @constraint(
        model,
        c_balance[rp in RP, k in K],
        sum(v_flow[a, rp, k] for a in A) == p_demand[rp, k]
    )

    # - maximum generation
    @constraint(
        model,
        c_max_prod[a in Ai, rp in RP, k in K],
        v_flow[a, rp, k] <=
        get(p_availability, (a, rp, k), 1.0) *
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
