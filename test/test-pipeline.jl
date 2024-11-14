@testset "Test that everything works from beginning to end with EnergyProblem struct" begin
    dir = joinpath(INPUT_FOLDER, "Tiny")
    connection = DBInterface.connect(DuckDB.DB)
    _read_csv_folder(connection, dir)
    energy_problem = EnergyProblem(connection)
    create_model!(energy_problem)
    solve_model!(energy_problem, HiGHS.Optimizer)
    save_solution_to_file(mktempdir(), energy_problem)
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
    graph, representative_periods, timeframe, groups, years = create_internal_structures(connection)
    model_parameters = ModelParameters(connection)
    sets = create_sets(graph, years)
    variables = compute_variables_indices(connection)
    constraints = compute_constraints_indices(connection)

    # Create model
    model = create_model(
        graph,
        sets,
        variables,
        constraints,
        representative_periods,
        years,
        timeframe,
        groups,
        model_parameters,
    )

    # Solve model
    solution = solve_model(model, variables, HiGHS.Optimizer)
    save_solution_to_file(mktempdir(), graph, solution)
end
