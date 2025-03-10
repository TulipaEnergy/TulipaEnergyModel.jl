# Run from project folder with
#
#   julia --project=. utils/scripts/update-model-mps.jl
#
using TulipaEnergyModel, TulipaIO, DuckDB

model_mps_folder = joinpath("benchmark", "model-mps-folder")
if isdir(model_mps_folder)
    rm(model_mps_folder; force = true, recursive = true)
end
mkdir(model_mps_folder)

for folder in readdir("test/inputs"; join = true)
    isdir(folder) || continue

    @info "Running run_scenario for $folder"

    con = DBInterface.connect(DuckDB.DB)
    schemas = TulipaEnergyModel.schema_per_table_name
    TulipaIO.read_csv_folder(con, folder; schemas)
    model_file_name = joinpath(model_mps_folder, basename(folder) * ".mps")
    TulipaEnergyModel.run_scenario(con; model_file_name, show_log = false)

    @info "Storing model.mps into $model_file_name"
end
