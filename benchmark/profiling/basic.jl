# Basic profiling script

include("common.jl")

con = _read_dir_and_return_connection(norse_dir)

function mycode(n)
    for _ in 1:n
        ep = EnergyProblem(con)
        create_model!(con, ep)
    end
end

@profview mycode(1)
@profview mycode(100)
