#From test case studies
#=
#@testitem "Tiny Case Study where periods are scenarios" setup = [CommonSetup] tags =
 #   [:case_study, :integration, :slow] begin
  #  dir = joinpath(INPUT_FOLDER, "copy_Tiny")
   # optimizer_list = [HiGHS.Optimizer, GLPK.Optimizer]
    #for optimizer in optimizer_list
     #   connection = DBInterface.connect(DuckDB.DB)
    #    _read_csv_folder(connection, dir)
     #   energy_problem = TulipaEnergyModel.run_scenario(connection; optimizer, show_log = false)
      #  @test energy_problem.objective_value ≈ 269238.43825 rtol = 1e-8
       # # populate_with_defaults shouldn't change the solution
        #TulipaEnergyModel.populate_with_defaults!(connection)
      #  energy_problem = TulipaEnergyModel.run_scenario(connection; optimizer, show_log = false)
       # @test energy_problem.objective_value ≈ 269238.43825 rtol = 1e-8
#    end#
#end

#From tutorial
import TulipaIO as TIO
import TulipaEnergyModel as TEM
import TulipaClustering as TC
import CSV
import Distances
using DuckDB
using DataFrames
using Plots
using Statistics

connection = DBInterface.connect(DuckDB.DB)
input_dir = joinpath(INPUT_FOLDER, "Copy_Tiny")
TIO.read_csv_folder(connection, input_dir)
