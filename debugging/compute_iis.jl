using TulipaEnergyModel
using DuckDB
using TulipaIO
using JuMP

in_dir = joinpath(pwd(), "debugging", "experiment-inputs", "trajectories-feas")
conn = DBInterface.connect(DuckDB.DB)
read_csv_folder(conn, in_dir; schemas = TulipaEnergyModel.schema_per_table_name)

energy_problem = run_scenario(conn; model_file_name = "model.lp", log_file = "log_file.log")
println("termination=", energy_problem.termination_status)
println("primal=", JuMP.primal_status(energy_problem.model))
println("dual=", JuMP.dual_status(energy_problem.model))

if energy_problem.termination_status == JuMP.INFEASIBLE
    JuMP.compute_conflict!(energy_problem.model)
    iis_model, _ = JuMP.copy_conflict(energy_problem.model)
    JuMP.write_to_file(iis_model, "debugging/iis_model.lp")
    println("Wrote debugging/iis_model.lp")
end
