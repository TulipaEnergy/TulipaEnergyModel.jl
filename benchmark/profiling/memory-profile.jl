using BenchmarkTools: @benchmark
using DuckDB: DuckDB, DBInterface
using Profile: Profile
using PProf: PProf
using TulipaEnergyModel: TulipaEnergyModel as TEM
using TulipaIO: TulipaIO as TIO

include("../tulipa-data.jl")

function common_setup(; kwargs...)
    connection, tulipa_data = create_synthetic_problem(; kwargs...)
    TEM.populate_with_defaults!(connection)
    return connection, tulipa_data
end

function setup_lower_level_pipeline(; kwargs...)
    connection, tulipa_data = common_setup(; kwargs...)

    # Internal data and structures pre-model
    TEM.create_internal_tables!(connection)
    model_parameters = TEM.ModelParameters(connection)
    variables = TEM.compute_variables_indices(connection)
    constraints = TEM.compute_constraints_indices(connection)
    profiles = TEM.prepare_profiles_structure(connection)

    # Create model
    #= Comment out before relevant function
    model, expressions = TEM.create_model(
        connection,
        variables,
        constraints,
        profiles,
        model_parameters,
    )

    # Solve model
    TEM.solve_model(model)
    TEM.save_solution!(connection, model, variables, constraints)
    output_dir = mktempdir()
    TEM.export_solution_to_csv_files(output_dir, connection)
    =#

    # return connection
    return connection, model_parameters, variables, constraints, profiles
end

# function relevant_lower_level_pipeline(connection)
function relevant_lower_level_pipeline(
    connection,
    model_parameters,
    variables,
    constraints,
    profiles,
)
    # Write relevant function
    model, expressions =
        TEM.create_model(connection, variables, constraints, profiles, model_parameters)

    return nothing
end

function setup_higher_level_pipeline(; kwargs...)
    connection, tulipa_data = common_setup(; kwargs...)

    energy_problem = TEM.EnergyProblem(connection)
    #= Comment out before relevant function
    TEM.create_model!(energy_problem)
    TEM.solve_model!(energy_problem)
    TEM.save_solution!(energy_problem)
    TEM.export_solution_to_csv_files(mktempdir(), energy_problem)
    =#

    return connection, energy_problem
end

function relevant_higher_level_pipeline(connection, energy_problem)
    # Write relevant function
    TEM.create_model!(energy_problem)

    return nothing
end

problem_kwargs = (num_days = 3, num_countries = 3)

Profile.Allocs.clear()

# Uncomment one of the two
# Lower level API
args = setup_lower_level_pipeline(; problem_kwargs...)
relevant_lower_level_pipeline(args...) # run once to precompile
Profile.Allocs.@profile sample_rate = 0.001 relevant_lower_level_pipeline(args...)

# Higher level API
# connection, energy_problem=setup_higher_level_pipeline(;problem_kwargs...)
# relevant_higher_level_pipeline(connection, energy_problem) # run once to precompile
# Profile.Allocs.@profile sample_rate=0.001 relevant_higher_level_pipeline(connection, energy_problem)

prof = Profile.Allocs.fetch()
PProf.Allocs.pprof(prof; from_c = false)
