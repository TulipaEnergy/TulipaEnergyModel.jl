module TulipaEnergyModel

# Packages

## Data
using CSV: CSV
using DataFrames: DataFrames, DataFrame
using DuckDB: DuckDB, DBInterface
using TOML: TOML
using TulipaIO: TulipaIO

## Graph
using Graphs: Graphs, SimpleDiGraph
using MetaGraphsNext: MetaGraphsNext, MetaGraph

## Optimization
using HiGHS: HiGHS
using JuMP: JuMP, @constraint, @expression, @objective, @variable
using MathOptInterface: MathOptInterface

## Others
using LinearAlgebra: LinearAlgebra
using OrderedCollections: OrderedDict
using Statistics: Statistics
using TimerOutputs: TimerOutput, @timeit

const to = TimerOutput()

# Definitions and auxiliary files
include("utils.jl")
include("time-resolution.jl")
include("run-scenario.jl")
include("model-parameters.jl")
include("structures.jl")

# Data
include("input-schemas.jl")
include("io.jl")

# Data massage and model preparation
include("model-preparation.jl")

# Model creation
for folder_name in ["variables", "constraints", "expressions"]
    folder_path = joinpath(@__DIR__, folder_name)
    files = filter(endswith(".jl"), readdir(folder_path))
    for file in files
        include(joinpath(folder_path, file))
    end
end
include("expressions.jl")
include("economic-parameters.jl")
include("objective.jl")
include("create-model.jl")

# Solution
include("solver-parameters.jl")
include("solve-model.jl")

end
