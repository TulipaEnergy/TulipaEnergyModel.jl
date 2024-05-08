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

include("input-schemas.jl")
include("structures.jl")
include("io.jl")
include("create-model.jl")
include("solver-parameters.jl")
include("solve-model.jl")
include("run-scenario.jl")
include("time-resolution.jl")
include("constraints/capacity.jl")
include("constraints/consumer.jl")
include("constraints/conversion.jl")
include("constraints/hub.jl")
include("constraints/investment.jl")
include("constraints/storage.jl")
include("constraints/transport.jl")

end
