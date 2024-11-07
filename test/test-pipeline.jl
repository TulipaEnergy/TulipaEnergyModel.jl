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
    constraints_partitions = compute_constraints_partitions(graph, representative_periods, years)
    dataframes = construct_dataframes(
        connection,
        graph,
        representative_periods,
        constraints_partitions,
        years,
    )
    model_parameters = ModelParameters(connection)
    sets = create_sets(graph, years)
    variables = compute_variables_indices(connection, dataframes)

    # Create model
    model = create_model(
        graph,
        sets,
        variables,
        representative_periods,
        dataframes,
        years,
        timeframe,
        groups,
        model_parameters,
    )

    # Solve model
    solution = solve_model(model, HiGHS.Optimizer)
    save_solution_to_file(mktempdir(), graph, dataframes, solution)
end
