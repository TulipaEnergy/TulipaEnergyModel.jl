using TulipaEnergyModel
using DuckDB
using TulipaIO

# in_folder = joinpath(pwd(), "test/inputs")
in_folder = joinpath(pwd(), "test/constraint-correctness-inputs")
bench_folder = joinpath(pwd(), "benchmark")

# in_dir = joinpath(in_folder, "3bin")
in_dir = joinpath(in_folder, "all-susd")
# in_dir = joinpath(in_folder, "UC-ramping")
# in_dir = joinpath(in_folder, "susd-ramping-2var-feas")
# in_dir = joinpath(in_folder, "Multi-year Investments")
# in_dir = joinpath(bench_folder, "EU")

conn = DBInterface.connect(DuckDB.DB)
read_csv_folder(conn, in_dir; schemas = TulipaEnergyModel.schema_per_table_name)

energy_problem = run_scenario(conn; model_file_name = "model.lp", log_file = "log_file.log")
