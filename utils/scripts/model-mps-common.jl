using TulipaEnergyModel, TulipaIO, DuckDB

function create_mps(input_folder, mps_folder)
    con = DBInterface.connect(DuckDB.DB)
    schemas = TulipaEnergyModel.schema_per_table_name
    TulipaIO.read_csv_folder(con, input_folder; schemas)
    model_file_name = joinpath(mps_folder, basename(input_folder) * ".mps")
    energy_problem = TulipaEnergyModel.EnergyProblem(con)
    TulipaEnergyModel.create_model!(energy_problem; model_file_name)

    return nothing
end
