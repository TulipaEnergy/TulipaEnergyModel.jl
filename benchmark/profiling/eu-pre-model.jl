# EU read profiling script

include("common.jl")

con = _read_dir_and_return_connection(eu_dir)

@profview EnergyProblem(con)
