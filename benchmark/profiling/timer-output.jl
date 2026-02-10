using TimerOutputs: reset_timer!
using TulipaEnergyModel: TulipaEnergyModel as TEM
using TulipaIO: TulipaIO as TIO

include("../tulipa-data.jl")

function common_setup(; kwargs...)
    connection, tulipa_data = create_synthetic_problem(; kwargs...)
    reset_timer!(TEM.to)
    TEM.populate_with_defaults!(connection)
    return connection, tulipa_data
end

function lower_level_pipeline(; kwargs...)
    connection, tulipa_data = common_setup(; kwargs...)

    # Internal data and structures pre-model
    TEM.create_internal_tables!(connection)
    model_parameters = TEM.ModelParameters(connection)
    variables = TEM.compute_variables_indices(connection)
    constraints = TEM.compute_constraints_indices(connection)
    profiles = TEM.prepare_profiles_structure(connection)

    # Create model
    model, expressions =
        TEM.create_model(connection, variables, constraints, profiles, model_parameters)

    # Solve model
    TEM.solve_model(model)
    TEM.save_solution!(connection, model, variables, constraints)
    output_dir = mktempdir()
    TEM.export_solution_to_csv_files(output_dir, connection)
    #= Comment out not relevant
    =#

    return connection
end

function higher_level_pipeline(; kwargs...)
    connection, tulipa_data = common_setup(; kwargs...)

    energy_problem = TEM.EnergyProblem(connection)
    TEM.create_model!(energy_problem)
    #= Comment out not relevant
    TEM.solve_model!(energy_problem)
    TEM.save_solution!(energy_problem)
    TEM.export_solution_to_csv_files(mktempdir(), energy_problem)
    =#

    return connection, energy_problem
end

# connection = lower_level_pipeline(; num_rep_periods = 3)
connection, energy_problem =
    higher_level_pipeline(; num_rep_periods = 3, num_countries = 10, period_duration = 24)
show(TEM.to)
# print(energy_problem.model)
energy_problem
