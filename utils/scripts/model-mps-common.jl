using TulipaEnergyModel, TulipaIO, DuckDB

function create_mps(input_folder, mps_folder)
    con = DBInterface.connect(DuckDB.DB)
    TulipaIO.read_csv_folder(con, input_folder)
    TulipaEnergyModel.populate_with_defaults!(con)
    model_file_name = joinpath(mps_folder, basename(input_folder) * ".mps")
    energy_problem = TulipaEnergyModel.EnergyProblem(con)
    TulipaEnergyModel.create_model!(energy_problem; model_file_name)

    return nothing
end
