@testset "Test that everything works from beginning to end with EnergyProblem struct" begin
    dir = joinpath(INPUT_FOLDER, "Tiny")
    connection = DBInterface.connect(DuckDB.DB)
    _read_csv_folder(connection, dir)
    energy_problem = TulipaEnergyModel.EnergyProblem(connection)
    TulipaEnergyModel.create_model!(energy_problem)
    TulipaEnergyModel.solve_model!(energy_problem, HiGHS.Optimizer)
    TulipaEnergyModel.export_solution_to_csv_files(mktempdir(), energy_problem)
end

@testset "Test that everything works for $input from beginning to end without EnergyProblem struct" for input in
                                                                                                        [
    "Tiny",
    "Norse",
    "Variable Resolution",
    "Multi-year Investments",
]
    # Data loading
    dir = joinpath(INPUT_FOLDER, input)
    connection = DBInterface.connect(DuckDB.DB)
    _read_csv_folder(connection, dir)

    # Internal data and structures pre-model
    TulipaEnergyModel.create_internal_structures(connection)
    model_parameters = TulipaEnergyModel.ModelParameters(connection)
    variables = TulipaEnergyModel.compute_variables_indices(connection)
    expressions = Dict()
    constraints = TulipaEnergyModel.compute_constraints_indices(connection)
    profiles = TulipaEnergyModel.prepare_profiles_structure(connection)

    # Create model
    model = TulipaEnergyModel.create_model(
        connection,
        variables,
        expressions,
        constraints,
        profiles,
        model_parameters,
    )

    # Solve model
    TulipaEnergyModel.solve_model(model, HiGHS.Optimizer)
    TulipaEnergyModel.save_solution!(connection, model, variables, constraints)
    TulipaEnergyModel.export_solution_to_csv_files(mktempdir(), connection, variables, constraints)
end
