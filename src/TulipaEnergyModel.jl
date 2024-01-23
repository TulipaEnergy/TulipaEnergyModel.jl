module TulipaEnergyModel

# Packages

## Data
using CSV, DataFrames, TOML

## Graphs
using Graphs, MetaGraphsNext

## Optimization
using HiGHS, JuMP, MathOptInterface

## Plots
using Plots, Colors, GraphMakie, GraphMakie.NetworkLayout, CairoMakie

## Others
using TimerOutputs

include("input-tables.jl")
include("structures.jl")
include("io.jl")
include("create-model.jl")
include("solver-parameters.jl")
include("solve-model.jl")
include("run-scenario.jl")
include("time-resolution.jl")
include("plot.jl")

end
