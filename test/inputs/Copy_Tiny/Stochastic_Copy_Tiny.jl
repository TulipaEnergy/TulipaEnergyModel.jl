#From test case studies
#=
@testitem "Tiny Case Study where periods are scenarios" setup = [CommonSetup] tags =
    [:case_study, :integration, :slow] begin
    dir = joinpath(INPUT_FOLDER, "copy_Tiny")
    optimizer_list = [HiGHS.Optimizer, GLPK.Optimizer]
    for optimizer in optimizer_list
        connection = DBInterface.connect(DuckDB.DB)
        _read_csv_folder(connection, dir)
        energy_problem = TulipaEnergyModel.run_scenario(connection; optimizer, show_log = false)
        @test energy_problem.objective_value ≈ 269238.43825 rtol = 1e-8
        # populate_with_defaults shouldn't change the solution
        TulipaEnergyModel.populate_with_defaults!(connection)
        energy_problem = TulipaEnergyModel.run_scenario(connection; optimizer, show_log = false)
        @test energy_problem.objective_value ≈ 269238.43825 rtol = 1e-8
    end
end
=#

#we will test and compare the following strategies:
#1. Reduce the scenarios and cluster the temporal dimension
#2. Keep the scenarios but cluster temporal dimension using CROSS scenario
#3. Reduce the scenarios and then cluster the temporal dimension using CROSS scenario

#From tutorial

using Pkg: Pkg       # Julia package manager
Pkg.activate(".")    # Creates and activates the project in the new folder - notice it creates Project.toml and Manifest.toml in your folder for reproducibility
Pkg.add("TulipaEnergyModel")
Pkg.add("TulipaIO")
Pkg.add("DuckDB")
Pkg.add("DataFrames")
Pkg.add("Plots")
Pkg.add("TulipaClustering")
Pkg.add("Distances")
Pkg.instantiate()

import TulipaIO as TIO
import TulipaEnergyModel as TEM
import TulipaClustering as TC
using CSV: CSV
using Distances: Distances
using DuckDB
using DataFrames
using Plots
using Statistics

#copy tiny with many scenarios, adjusted rep-periods mapping
connection = DBInterface.connect(DuckDB.DB)
input_dir = "C:/Users/fjlaseur/Tulipa/CVaR/TulipaEnergyModel.jl/test/inputs/Copy_Tiny"
TIO.read_csv_folder(connection, input_dir)
#test per and cross

TEM.populate_with_defaults!(connection)
energy_problem = TEM.run_scenario(connection)

##############################################
#tiny

connection = DBInterface.connect(DuckDB.DB)
input_dir = "C:/Users/fjlaseur/Tulipa/CVaR/TulipaEnergyModel.jl/test/inputs/Tiny"
TIO.read_csv_folder(connection, input_dir)
#test per and cross

TEM.populate_with_defaults!(connection)
energy_problem = TEM.run_scenario(connection)
