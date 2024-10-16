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

include("utils.jl")
include("input-schemas.jl")
include("model-parameters.jl")
include("structures.jl")
include("model-preparation.jl")
include("io.jl")
include("create-model.jl")
include("solver-parameters.jl")
include("solve-model.jl")
include("run-scenario.jl")
include("time-resolution.jl")
include("economic-parameters.jl")

for folder_name in ["variables", "constraints"]
    folder_path = joinpath(@__DIR__, folder_name)
    files = filter(f -> endswith(f, ".jl"), readdir(folder_path))
    for file in files
        include(joinpath(folder_path, file))
    end
end

end
