using BenchmarkTools
using TulipaEnergyModel
using MetaGraphsNext
using TulipaIO
using DuckDB

const SUITE = BenchmarkGroup()

# The following lines are checking whether this is being called from the `test`.
# If it is not, then we use a larger dataset
const INPUT_FOLDER_BM = if isdefined(Main, :Test)
    joinpath(@__DIR__, "../test/inputs/Norse")
else
    joinpath(@__DIR__, "EU")
end

const OUTPUT_FOLDER_BM = mktempdir()

connection = DBInterface.connect(DuckDB.DB)
TulipaIO.read_csv_folder(
    connection,
    INPUT_FOLDER_BM;
    schemas = TulipaEnergyModel.schema_per_table_name,
)

# update data files to have hourly constraints
DuckDB.query(connection, "UPDATE assets_rep_periods_partitions SET partition = 1")
DuckDB.query(connection, "UPDATE flows_rep_periods_partitions SET partition = 1")

SUITE["energy_problem"] = BenchmarkGroup()
SUITE["energy_problem"]["input_and_constructor"] = @benchmarkable begin
    EnergyProblem($connection)
end samples = 3 evals = 1 seconds = 86400
energy_problem = EnergyProblem(connection)

SUITE["energy_problem"]["create_model"] = @benchmarkable begin
    create_model!($energy_problem)
end samples = 3 evals = 1 seconds = 86400
create_model!(energy_problem)

# SUITE["energy_problem"]["output"] = @benchmarkable begin
#     export_solution_to_csv_files($OUTPUT_FOLDER_BM, $energy_problem)
# end
