@testitem "Ensuring tutorials data can be read and create the internal structures" setup =
    [CommonSetup] tags = [:integration, :fast] begin
    connection = DBInterface.connect(DuckDB.DB)
    tutorial_files_path = joinpath(@__DIR__, "../docs/src/10-tutorials/my-awesome-energy-system/")
    # for each folder called "tutorial-X" in tutorial_files_path
    for folder in filter(
        x -> isdir(joinpath(tutorial_files_path, x)) && startswith(x, "tutorial-"),
        readdir(tutorial_files_path),
    )
        TulipaIO.read_csv_folder(connection, joinpath(tutorial_files_path, folder))
        TulipaEnergyModel.populate_with_defaults!(connection)
        @test TulipaEnergyModel.create_internal_tables!(connection) === nothing
    end
end
