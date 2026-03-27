module TulipaEnergyModel

const SQL_FOLDER = joinpath(@__DIR__, "sql")

# Packages

## Data
using CSV: CSV
using DuckDB: DuckDB, DBInterface
using TOML: TOML
using JSON: JSON
using TulipaIO: TulipaIO

## Optimization
using HiGHS: HiGHS
using JuMP: JuMP, @constraint, @expression, @objective, @variable
using MathOptInterface: MathOptInterface
using ParametricOptInterface: ParametricOptInterface as POI

## Others
using OrderedCollections: OrderedDict
using Statistics: Statistics
using TimerOutputs: TimerOutput, @timeit

const to = TimerOutput()

# Public API
export

    # Run
    run_scenario,

    # Model parameters
    ModelParameters,

    # Structures
    EnergyProblem,
    ProfileLookup,
    TulipaVariable,
    TulipaConstraint,
    TulipaExpression,
    PeriodsBlock,
    TimestepsBlock,
    attach_constraint!,
    attach_expression!,
    attach_coefficient!,

    # Data
    DataValidationException,
    create_internal_tables!,
    export_solution_to_csv_files,
    populate_with_defaults!,

    # Model preparation
    prepare_profiles_structure,

    # Variables
    compute_variables_indices,
    add_flow_variables!,
    add_vintage_flow_variables!,
    add_storage_variables!,
    add_unit_commitment_variables!,
    add_start_up_and_shut_down_variables!,
    add_power_flow_variables!,
    add_decommission_variables!,
    add_investment_variables!,
    add_conditional_value_at_risk_variables!,

    # Constraints
    compute_constraints_indices,
    add_capacity_constraints!,
    add_energy_constraints!,
    add_storage_constraints!,
    add_consumer_constraints!,
    add_conversion_constraints!,
    add_transport_constraints!,
    add_flows_relationships_constraints!,
    add_vintage_flow_sum_constraints!,
    add_uc_logic_constraints!,
    add_ramping_constraints!,
    add_dc_power_flow_constraints!,
    add_investment_group_constraints!,
    add_start_up_upper_bound_constraints!,
    add_shut_down_upper_bound_constraints!,

    # Objectives
    add_objective!,

    # Model creation
    create_model!,
    create_model,

    # Solver
    default_parameters,
    read_parameters_from_file,

    # Solution
    solve_model!,
    solve_model,
    save_solution!,

    # Rolling horizon
    run_rolling_horizon

# Definitions and auxiliary files
include("run-scenario.jl")
include("structures.jl")
include("utils.jl")

# Data
include("input-schemas.jl")
include("io.jl")
include("data-validation.jl")
include("data-preparation.jl")

# Data massage and model preparation
include("model-preparation.jl")

# Rolling horizon
include("rolling-horizon/rolling-horizon.jl")

# Model creation
for folder_name in ["variables", "constraints", "expressions", "objectives"]
    folder_path = joinpath(@__DIR__, folder_name)
    files = filter(endswith(".jl"), readdir(folder_path))
    for file in files
        include(joinpath(folder_path, file))
    end
end
include("create-model.jl")

# Solution
include("solver-parameters.jl")
include("solve-model.jl")

end
