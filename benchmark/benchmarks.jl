using BenchmarkTools
using TulipaEnergyModel
using TulipaIO
using DuckDB

const SUITE = BenchmarkGroup()

function input_setup()
    # The following lines are checking whether this is being called from the `test`.
    # If it is not, then we use a larger dataset
    input_folder = if isdefined(Main, :Test)
        joinpath(@__DIR__, "../test/inputs/Norse")
    else
        joinpath(@__DIR__, "EU")
    end

    connection = DBInterface.connect(DuckDB.DB)
    TulipaIO.read_csv_folder(
        connection,
        input_folder;
        schemas = TulipaEnergyModel.schema_per_table_name,
    )
    return connection
end

function create_model_setup()
    connection = input_setup()
    return EnergyProblem(connection)
end

SUITE["energy_problem"] = BenchmarkGroup()
SUITE["energy_problem"]["input_and_constructor"] = @benchmarkable begin
    EnergyProblem(connection)
end samples = 3 evals = 1 seconds = 86400 setup = (connection = input_setup())

SUITE["energy_problem"]["create_model"] = @benchmarkable begin
    create_model!(energy_problem)
end samples = 3 evals = 1 seconds = 86400 setup = (energy_problem = create_model_setup())
