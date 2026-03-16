using TulipaEnergyModel
using DuckDB
using TulipaIO

in_folder = joinpath(pwd(), "test/inputs")
in_folder = joinpath(pwd(), "debugging/experiment-inputs")
bench_folder = joinpath(pwd(), "debugging")

# in_dir = joinpath(in_folder, "Multi-year Investments")
# in_dir = joinpath(in_folder, "with_limits_model_2")
# in_dir = joinpath(in_folder, "all-susd")
# in_dir = joinpath(in_folder, "UC-ramping")
in_dir = joinpath(in_folder, "trajectories-feas")
# in_dir = joinpath(bench_folder, "EU")

# Conversion
# conv_dir = joinpath(pwd(), "debugging", "to-convert")
# conv_dir = joinpath(pwd(), "debugging", "converted")

# in_dir = joinpath(conv_dir, "conv_test")

# Trajectory
# in_dir = joinpath(pwd(), "test", "constraint-correctness-inputs", "trajectories-feas")
# in_dir = joinpath(pwd(), "test", "constraint-correctness-inputs", "trajectories-infeas")

# SUSD Ramping 1,2,3var
# in_dir = joinpath(pwd(), "test", "constraint-correctness-inputs", "susd-ramping-1var-feas")
# in_dir = joinpath(pwd(), "test", "constraint-correctness-inputs", "susd-ramping-1var-infeas")
# in_dir = joinpath(pwd(), "test", "constraint-correctness-inputs", "susd-ramping-2var-feas")
# in_dir = joinpath(pwd(), "test", "constraint-correctness-inputs", "susd-ramping-2var-infeas")
# in_dir = joinpath(pwd(), "test", "constraint-correctness-inputs", "susd-ramping-3var-feas")
# in_dir = joinpath(pwd(), "test", "constraint-correctness-inputs", "susd-ramping-3var-infeas")

conn = DBInterface.connect(DuckDB.DB)
read_csv_folder(conn, in_dir; schemas = TulipaEnergyModel.schema_per_table_name)

energy_problem = run_scenario(conn; model_file_name = "model.lp", log_file = "log_file.log")

# FILL_IN,producer,,FILL_IN,FILL_IN,simple,true,15,15,0.05,==,0.0,false,,true,FILL_IN,true,true,false,0.0,false,FILL_IN,FILL_IN,FILL_IN,FILL_IN,FILL_IN,FILL_IN,FILL_IN,FILL_IN,FILL_IN,FILL_IN
