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

include("input-schemas.jl")
include("model-parameters.jl")
include("structures.jl")
include("io.jl")
include("create-model.jl")
include("solver-parameters.jl")
include("solve-model.jl")
include("run-scenario.jl")
include("time-resolution.jl")
include("economic-parameters.jl")

for file in filter(f -> endswith(f, ".jl"), readdir(joinpath(@__DIR__, "constraints")))
    include(joinpath(constraints_folder_path, file))
end

end
