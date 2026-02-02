using DuckDB: DuckDB, DBInterface
using JET: JET
using TulipaEnergyModel: TulipaEnergyModel as TEM
using TulipaIO: TulipaIO as TIO

include("tulipa-data.jl")

function common_setup(; kwargs...)
    connection, tulipa_data = give_me_better_name(; kwargs...)
    TEM.populate_with_defaults!(connection)
    return connection, tulipa_data
end

function setup_lower_level_pipeline(; kwargs...)
    connection, tulipa_data = common_setup(; kwargs...)

    # Internal data and structures pre-model
    #= Comment out before revelant function
    TEM.create_internal_tables!(connection)
    model_parameters = TEM.ModelParameters(connection)
    variables = TEM.compute_variables_indices(connection)
    constraints = TEM.compute_constraints_indices(connection)
    profiles = TEM.prepare_profiles_structure(connection)

    # Create model
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

    return connection
    # return connection, model_parameters, variables, constraints, profiles
end

function relevant_lower_level_pipeline(connection)
    # function relevant_lower_level_pipeline(
    #     connection,
    #     model_parameters,
    #     variables,
    #     constraints,
    #     profiles,
    # )
    # Write relevant function
    TEM.create_internal_tables!(connection)

    return nothing
end

function setup_higher_level_pipeline(; kwargs...)
    connection, tulipa_data = common_setup(; kwargs...)

    energy_problem = TEM.EnergyProblem(connection)
    #= Comment out before revelant function
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

# Uncomment one of the two
# Lower level API
args = setup_lower_level_pipeline(; problem_kwargs...)
# @code_warntype relevant_lower_level_pipeline(args)
JET.@report_opt target_modules = (TEM,) relevant_lower_level_pipeline(args)

# Higher level API
# connection, energy_problem=setup_higher_level_pipeline(;problem_kwargs...)
# @code_warntype relevant_higher_level_pipeline(connection, energy_problem)
