@testitem "Test that solve_model! throws if model is not created but works otherwise" setup =
    [CommonSetup] tags = [:integration, :validation, :fast] begin
    connection = DBInterface.connect(DuckDB.DB)
    _read_csv_folder(connection, joinpath(INPUT_FOLDER, "Tiny"))
    energy_problem = TulipaEnergyModel.EnergyProblem(connection)
    @test_throws Exception TulipaEnergyModel.solve_model!(energy_problem)
    @test !energy_problem.solved
    TulipaEnergyModel.create_model!(energy_problem)
    @test !energy_problem.solved
    solution = TulipaEnergyModel.solve_model!(energy_problem)
    @test energy_problem.solved
end

@testitem "Test that model.lp and model.mps are created" setup = [CommonSetup] tags =
    [:integration, :validation, :fast] begin
    for ext in ("lp", "mps")
        connection = DBInterface.connect(DuckDB.DB)
        _read_csv_folder(connection, joinpath(INPUT_FOLDER, "Tiny"))
        energy_problem = TulipaEnergyModel.EnergyProblem(connection)

        model_file_name = joinpath(mktempdir(), "saved_model.$ext")
        @test !isfile(model_file_name)
        TulipaEnergyModel.create_model!(energy_problem; model_file_name)
        @test isfile(model_file_name)
    end
end

@testitem "Test that solution column is created with variables" setup = [CommonSetup] tags =
    [:unit, :fast] begin
    for input_dir in readdir(INPUT_FOLDER; join = true)
        if !isdir(input_dir)
            continue
        end
        connection = DBInterface.connect(DuckDB.DB)
        TulipaIO.read_csv_folder(connection, input_dir)
        TulipaEnergyModel.populate_with_defaults!(connection)
        energy_problem = TulipaEnergyModel.EnergyProblem(connection)

        variable_tables = [
            row.table_name for
            row in DuckDB.query(connection, "FROM duckdb_tables WHERE table_name LIKE 'var_%'")
        ]
        @test length(variable_tables) > 0 # this is not a relevant test, but we're making sure some variables were created
        for table_name in variable_tables
            @test "solution" in [
                row.column_name for row in DuckDB.query(
                    connection,
                    "FROM duckdb_columns
                    WHERE table_name = '$table_name'
                        AND column_name = 'solution'",
                )
            ]
        end
    end
end
