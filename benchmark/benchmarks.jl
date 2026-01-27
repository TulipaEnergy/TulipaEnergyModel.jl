using BenchmarkTools
using TulipaEnergyModel
using TulipaIO
using DuckDB

const SUITE = BenchmarkGroup()

function higher_level_input_setup()
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

function higher_level_create_model_setup()
    connection = higher_level_input_setup()
    return EnergyProblem(connection)
end

function lower_level_input_setup()
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

function lower_level_create_internal_tables()
    connection = lower_level_input_setup()
    create_internal_tables!(connection)

    return connection
end

function lower_level_model_parameters()
    connection = lower_level_create_internal_tables()
    model_parameters = ModelParameters(connection)

    return connection, model_parameters
end

function lower_level_variables()
    connection, model_parameters = lower_level_model_parameters()
    variables = compute_variables_indices(connection)

    return connection, model_parameters, variables
end

function lower_level_constraints()
    connection, model_parameters, variables = lower_level_variables()
    constraints = compute_constraints_indices(connection)

    return connection, model_parameters, variables, constraints
end

function lower_level_profiles()
    connection, model_parameters, variables, constraints = lower_level_constraints()
    profiles = prepare_profiles_structure(connection)

    return connection, model_parameters, variables, constraints, profiles
end

function lower_level_create_model()
    connection, model_parameters, variables, constraints, profiles = lower_level_profiles()
    model, expressions = TulipaEnergyModel.create_model(
        connection,
        variables,
        constraints,
        profiles,
        model_parameters,
    )

    return connection, model_parameters, variables, constraints, profiles, model, expressions
end

function add_to_suite_higher_level_pipeline!(SUITE)
    SUITE["higher_level"] = BenchmarkGroup()
    SUITE["higher_level"]["EU"] = BenchmarkGroup()

    SUITE["higher_level"]["EU"]["input_and_constructor"] = @benchmarkable begin
        EnergyProblem(connection)
    end samples = 3 evals = 1 seconds = 86400 setup = (connection = higher_level_input_setup())

    SUITE["higher_level"]["EU"]["create_model"] = @benchmarkable begin
        create_model!(energy_problem)
    end samples = 3 evals = 1 seconds = 86400 setup =
        (energy_problem = higher_level_create_model_setup())

    return SUITE
end

function add_to_suite_lower_level_pipeline!(SUITE)
    SUITE["lower_level"] = BenchmarkGroup()
    SUITE["lower_level"]["EU"] = BenchmarkGroup()

    SUITE["lower_level"]["EU"]["create_internal_tables"] = @benchmarkable begin
        create_internal_tables!(connection)
    end samples = 3 evals = 1 seconds = 86400 setup = (connection = lower_level_input_setup())

    SUITE["lower_level"]["EU"]["model_parameters"] = @benchmarkable begin
        ModelParameters(connection)
    end samples = 3 evals = 1 seconds = 86400 setup =
        (connection = lower_level_create_internal_tables())

    SUITE["lower_level"]["EU"]["variables"] = @benchmarkable begin
        compute_variables_indices(connection)
    end samples = 3 evals = 1 seconds = 86400 setup =
        ((connection, model_parameters) = lower_level_model_parameters())

    SUITE["lower_level"]["EU"]["constraints"] = @benchmarkable begin
        compute_constraints_indices(connection)
    end samples = 3 evals = 1 seconds = 86400 setup =
        ((connection, model_parameters, variables) = lower_level_variables())

    SUITE["lower_level"]["EU"]["profiles"] = @benchmarkable begin
        prepare_profiles_structure(connection)
    end samples = 3 evals = 1 seconds = 86400 setup =
        ((connection, model_parameters, variables, constraints) = lower_level_constraints())

    SUITE["lower_level"]["EU"]["create_model"] = @benchmarkable begin
        create_model(connection, variables, constraints, profiles, model_parameters)
    end samples = 3 evals = 1 seconds = 86400 setup = (
        (connection, model_parameters, variables, constraints, profiles) =
            lower_level_profiles()
    )

    return SUITE
end

add_to_suite_higher_level_pipeline!(SUITE)
add_to_suite_lower_level_pipeline!(SUITE)
