using BenchmarkTools
using TulipaEnergyModel
using TulipaIO
using DuckDB

const SUITE = BenchmarkGroup()

# Each setup helper returns the state needed by the matching pipeline step, so it
# can be reused as the `setup` for the corresponding benchmark.
function input_setup(input_folder)
    connection = DBInterface.connect(DuckDB.DB)
    # Read without strict schemas and fill defaults so that case studies with
    # intentionally-incomplete CSVs (missing optional columns) can also be loaded.
    TulipaIO.read_csv_folder(connection, input_folder)
    TulipaEnergyModel.populate_with_defaults!(connection)
    return connection
end

function create_model_setup(input_folder)
    return EnergyProblem(input_setup(input_folder))
end

function internal_tables_setup(input_folder)
    connection = input_setup(input_folder)
    create_internal_tables!(connection)
    return connection
end

function variables_setup(input_folder)
    connection = internal_tables_setup(input_folder)
    return connection, compute_variables_indices(connection)
end

function constraints_setup(input_folder)
    connection, variables = variables_setup(input_folder)
    return connection, variables, compute_constraints_indices(connection)
end

function profiles_setup(input_folder)
    connection, variables, constraints = constraints_setup(input_folder)
    return connection, variables, constraints, prepare_profiles_structure(connection)
end

# Add the higher- and lower-level pipeline benchmarks for a single dataset.
function add_dataset!(SUITE, name, input_folder)
    higher = BenchmarkGroup()
    lower = BenchmarkGroup()
    SUITE["higher_level"][name] = higher
    SUITE["lower_level"][name] = lower

    higher["input_and_constructor"] = @benchmarkable begin
        EnergyProblem(connection)
    end samples = 3 evals = 1 seconds = 86400 setup = (connection = input_setup($input_folder))

    higher["create_model"] = @benchmarkable begin
        create_model!(energy_problem)
    end samples = 3 evals = 1 seconds = 86400 setup =
        (energy_problem = create_model_setup($input_folder))

    lower["create_internal_tables"] = @benchmarkable begin
        create_internal_tables!(connection)
    end samples = 3 evals = 1 seconds = 86400 setup = (connection = input_setup($input_folder))

    lower["variables"] = @benchmarkable begin
        compute_variables_indices(connection)
    end samples = 3 evals = 1 seconds = 86400 setup =
        (connection = internal_tables_setup($input_folder))

    lower["constraints"] = @benchmarkable begin
        compute_constraints_indices(connection)
    end samples = 3 evals = 1 seconds = 86400 setup =
        ((connection, variables) = variables_setup($input_folder))

    lower["profiles"] = @benchmarkable begin
        prepare_profiles_structure(connection)
    end samples = 3 evals = 1 seconds = 86400 setup =
        ((connection, variables, constraints) = constraints_setup($input_folder))

    lower["create_model"] = @benchmarkable begin
        create_model(connection, variables, constraints, profiles)
    end samples = 3 evals = 1 seconds = 86400 setup =
        ((connection, variables, constraints, profiles) = profiles_setup($input_folder))

    return SUITE
end

SUITE["higher_level"] = BenchmarkGroup()
SUITE["lower_level"] = BenchmarkGroup()

# Large end-to-end dataset: EU when run standalone, Norse when included from the tests.
large_dataset_folder = if isdefined(Main, :Test)
    joinpath(@__DIR__, "../test/inputs/Norse")
else
    joinpath(@__DIR__, "EU")
end
add_dataset!(SUITE, "EU", large_dataset_folder)

# Add every test case study to the suite.
for folder in filter(isdir, readdir(joinpath(@__DIR__, "..", "test", "inputs"); join = true))
    add_dataset!(SUITE, basename(folder), folder)
end
