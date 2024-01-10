module TulipaEnergyModel

# Packages
using CSV
using DataFrames
using Graphs
using HiGHS
using JuMP
using MathOptInterface
using MetaGraphsNext
using TOML
using Plots
using Colors
using GraphMakie
using GraphMakie.NetworkLayout
using CairoMakie
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
