# Copyright (c) 2025: Diego Tejada and contributors
#
# Use of this source code is governed by an Apache 2.0 license that can be found
# in the LICENSE.md file or at https://opensource.org/license/apache-2-0.

cd(@__DIR__)
using Pkg: Pkg
Pkg.activate(".")

# Load the required packages
import TulipaEnergyModel as TEM
import TulipaIO as TIO
import TulipaClustering as TC
using DuckDB: DuckDB
using HiGHS: HiGHS
using Gurobi: Gurobi
using Distances: Distances
using CSV: CSV
using Statistics: Statistics
using JuMP: JuMP
using TOML: TOML
using DataFrames

# helper functions
@info "Including helper functions"
include("utils/functions.jl")

distance_map = Dict(
    :Euclidean => Distances.Euclidean(),
    :SqEuclidean => Distances.SqEuclidean(),
    :CosineDist => Distances.CosineDist(),
    :Cityblock => Distances.Cityblock(),
    :Chebyshev => Distances.Chebyshev(),
)

# Read and transform user input files to Tulipa input files
config = TOML.parsefile("config.toml")
input_data_path = config["simulation"]["input_data"]
use_ratio = config["clustering"]["use_ratio"]
heuristic_distance = config["clustering"]["heuristic_distance"]
fix_level_storage = config["simulation"]["fix_level_storage"]
representative_periods = config["simulation"]["representative_periods"]
solvers = [Symbol(el) for el in config["simulation"]["solvers"]]

case_studies_info = CSV.read(
    "case-studies-info.csv",
    DataFrame;
    types = Dict(
        :base_name => String,
        :period_duration => Int,
        :method => Symbol,
        :distance => Symbol,
        :weight_type => Symbol,
        :niters => Int,
        :learning_rate => Float64,
        :stochastic_method => Symbol,
        :risk_aversion_weight_lambda => Float64,
        :risk_aversion_confidence_level => Float64,
        :run_case => Bool,
    ),
)

enable_names = true
direct_model = false
results_df = DataFrame(;
    base_name = String[],
    rp = Int[],
    solver = Symbol[],
    time_to_cluster = Float64[],
    time_to_read = Float64[],
    time_to_create = Float64[],
    time_to_solve = Float64[],
    time_to_save = Float64[],
    objective_value = Float64[],
    termination_status = String[],
    num_constraints = Int[],
    num_variables = Int[],
    time_to_resolve_benchmark = Float64[],
    objective_value_resolve_benchmark = Float64[],
    termination_status_resolve_benchmark = String[],
    num_loss_of_load_e_demand = Int[],
    num_loss_of_load_h2_demand = Int[],
    water_borrowed = Float64[],
)

function main()
    # optimize for the base case study (0_HourlyBenchmark)
    @info "Running the base case study (0_HourlyBenchmark)"
    base_name = "0_HourlyBenchmark"

    # set up the connection and read the data
    connection_benchmark = DuckDB.DBInterface.connect(DuckDB.DB)
    TIO.read_csv_folder(connection_benchmark, input_data_path)

    # transform the profiles data from wide to long
    TC.transform_wide_to_long!(
        connection_benchmark,
        "profiles_wide",
        "profiles";
        exclude_columns = ["scenario", "year", "timestep"],
    )

    # To make number of rps comparable with per and cross scenario
    # we consider the case that n_rps is not divisible by the number of scenarios
    profiles_wide = TIO.get_table(connection_benchmark, "profiles_wide")
    n_scenarios = length(unique(profiles_wide.scenario))
    representative_periods .= n_scenarios .* round.(Int, representative_periods ./ n_scenarios)

    layout = TC.ProfilesTableLayout(; cols_to_groupby = [:year, :scenario])
    time_to_cluster = @elapsed TC.dummy_cluster!(connection_benchmark; layout = layout)
    ensure_milestone_year!(connection_benchmark)
    TEM.populate_with_defaults!(connection_benchmark)
    DuckDB.query(connection_benchmark, "UPDATE asset SET is_seasonal = false")

    time_to_read = @elapsed energy_problem_benchmark = TEM.EnergyProblem(connection_benchmark)

    for solver in solvers
        optimizer, parameters = get_solver_parameters(solver)

        @info "Creating the model for the base case study (0_HourlyBenchmark) with $solver"
        time_to_create = @elapsed TEM.create_model!(
            energy_problem_benchmark;
            optimizer = optimizer,
            optimizer_parameters = parameters,
            model_file_name = "",
            enable_names = enable_names,
            direct_model = direct_model,
        )

        output_folder = joinpath(@__DIR__, "outputs", base_name, string(solver))
        mkpath(output_folder)

        @info "Solving the model and saving the solution for the base case study (0_HourlyBenchmark) with $solver"
        time_to_solve = @elapsed TEM.solve_model!(energy_problem_benchmark)
        time_to_save = @elapsed TEM.save_solution!(energy_problem_benchmark)
        TEM.export_solution_to_csv_files(output_folder, energy_problem_benchmark)

        var_flow_df = TIO.get_table(connection_benchmark, "var_flow")
        flow_ens = filter(row -> row.from_asset == "ens" && row.to_asset == "e_demand", var_flow_df)
        flow_smr_ccs =
            filter(row -> row.from_asset == "smr_ccs" && row.to_asset == "h2_demand", var_flow_df)
        water_borrowed = filter(
            row -> row.from_asset == "water_borrower" && row.to_asset == "hydro_reservoir",
            var_flow_df,
        )

        # count steps with loss of load
        n_lol_ens = count(row -> row.solution > 0.0, eachrow(flow_ens))
        n_lol_smr_cca = count(row -> row.solution > 0.0, eachrow(flow_smr_ccs))

        # count how much water_borrowed
        amount_water_borrowed_b = sum(water_borrowed.solution)

        new_results_row = (
            base_name = base_name,
            rp = 1,
            solver = solver,
            time_to_cluster = 0.0,
            time_to_read = time_to_read,
            time_to_create = time_to_create,
            time_to_solve = time_to_solve,
            time_to_save = time_to_save,
            objective_value = energy_problem_benchmark.objective_value,
            termination_status = string(energy_problem_benchmark.termination_status),
            num_constraints = JuMP.num_constraints(
                energy_problem_benchmark.model;
                count_variable_in_set_constraints = false,
            ),
            num_variables = JuMP.num_variables(energy_problem_benchmark.model),
            time_to_resolve_benchmark = 0.0,
            objective_value_resolve_benchmark = 0.0,
            termination_status_resolve_benchmark = "",
            num_loss_of_load_e_demand = n_lol_ens,
            num_loss_of_load_h2_demand = n_lol_smr_cca,
            water_borrowed = amount_water_borrowed_b,
        )
        push!(results_df, new_results_row)
    end

    # optimize the energy system for each case study
    for row in eachrow(case_studies_info)
        base_name = row[:base_name]
        period_duration = row[:period_duration]
        method = row[:method]
        distance = distance_map[row[:distance]]
        weight_type = row[:weight_type]
        niters = row[:niters]
        learning_rate = row[:learning_rate]
        stochastic_method = row[:stochastic_method]
        risk_aversion_weight_lambda = row[:risk_aversion_weight_lambda]
        risk_aversion_confidence_level = row[:risk_aversion_confidence_level]
        run_case = row[:run_case]

        weight_fitting_kwargs = Dict(:learning_rate => learning_rate, :niters => niters)
        clustering_kwargs = Dict(:learning_rate => learning_rate, :niters => niters)

        if !run_case
            continue
        end

        for rp in representative_periods
            case_name = base_name * "_rp_" * "$rp"

            @info "Processing case study: $case_name"

            connection = DuckDB.DBInterface.connect(DuckDB.DB)
            TIO.read_csv_folder(connection, input_data_path)

            # to use the ratio availability/demand
            if use_ratio == true # be careful: this works now that we have only one demand location, so we divide each availability and inflow by that only demand
                DuckDB.query(
                    connection,
                    "
                    UPDATE profiles_wide
                    SET
                        solar = solar / demand,
                        wind_offshore = wind_offshore / demand,
                        wind_onshore = wind_onshore / demand,
                        hydro_inflow = hydro_inflow / demand;
                    ",
                )
            end

            # transform the profiles data from wide to long
            TC.transform_wide_to_long!(
                connection,
                "profiles_wide",
                "profiles";
                exclude_columns = ["scenario", "year", "timestep"],
            )

            if stochastic_method == :per_scenario
                layout = TC.ProfilesTableLayout(; cols_to_groupby = [:year, :scenario])
                time_to_cluster = @elapsed TC.cluster!(
                    connection,
                    period_duration,
                    round(Int, rp / n_scenarios);
                    method = method,
                    distance = distance,
                    weight_type = weight_type,
                    layout = layout,
                    clustering_kwargs,
                    weight_fitting_kwargs,
                )
                if use_ratio == true
                    DuckDB.query(
                        connection,
                        "UPDATE profiles_rep_periods AS x
                            SET value =
                                CASE
                                    WHEN x.profile_name = 'demand' THEN x.value
                                    ELSE x.value * d.value
                                END
                            FROM profiles_rep_periods AS d
                            WHERE d.timestep   = x.timestep
                            AND d.rep_period       = x.rep_period
                            AND d.year       = x.year
                            AND d.scenario   = x.scenario
                            AND d.profile_name = 'demand';
                                ",
                    )
                end

            elseif stochastic_method == :cross_scenario
                layout = TC.ProfilesTableLayout(;
                    cols_to_groupby = [:year],
                    cols_to_crossby = [:scenario],
                )
                time_to_cluster = @elapsed TC.cluster!(
                    connection,
                    period_duration,
                    rp;
                    method = method,
                    distance = distance,
                    weight_type = weight_type,
                    layout = layout,
                    clustering_kwargs,
                    weight_fitting_kwargs,
                )
                if use_ratio == true
                    DuckDB.query(
                        connection,
                        "UPDATE profiles_rep_periods AS x
                            SET value =
                                CASE
                                    WHEN x.profile_name = 'demand' THEN x.value
                                    ELSE x.value * d.value
                                END
                            FROM profiles_rep_periods AS d
                            WHERE d.timestep   = x.timestep
                            AND d.rep_period       = x.rep_period
                            AND d.year       = x.year
                            AND d.profile_name = 'demand';
                                ",
                    )
                end
            else
                error("Unknown stochastic method: $stochastic_method")
            end
            if use_ratio == true
                DuckDB.query(
                    connection,
                    "UPDATE profiles AS x
                        SET value =
                            CASE
                                WHEN x.profile_name = 'demand' THEN x.value
                                ELSE x.value * d.value
                            END
                        FROM profiles AS d
                        WHERE d.timestep   = x.timestep
                        AND d.year       = x.year
                        AND d.scenario   = x.scenario
                        AND d.profile_name = 'demand';
                            ",
                )
            end
            ensure_milestone_year!(connection)
            TEM.populate_with_defaults!(connection)

            time_to_read = @elapsed energy_problem = TEM.EnergyProblem(connection)

            for solver in solvers
                optimizer, parameters = get_solver_parameters(solver)

                @info "Creating the model for the case study: $case_name"
                time_to_create = @elapsed TEM.create_model!(
                    energy_problem;
                    optimizer = optimizer,
                    optimizer_parameters = parameters,
                    model_file_name = "",
                    enable_names = enable_names,
                )

                output_folder = joinpath(@__DIR__, "outputs", case_name, string(solver))
                mkpath(output_folder)

                @info "Solving the model and saving the solution for the case study: $case_name with $solver"
                time_to_solve = @elapsed TEM.solve_model!(energy_problem)
                time_to_save = @elapsed TEM.save_solution!(energy_problem)
                TEM.export_solution_to_csv_files(output_folder, energy_problem)

                var_flow_df = TIO.get_table(connection, "var_flow")
                water_borrowed = filter(
                    row ->
                        row.from_asset == "water_borrower" && row.to_asset == "hydro_reservoir",
                    var_flow_df,
                )
                amount_water_borrowed_err = sum(water_borrowed.solution)
                if amount_water_borrowed_err > 0.0
                    error("Borrowed water has been used: $amount_water_borrowed")
                end

                @info "Fixing variables in the benchmark case study: $case_name with $solver"
                fix_variables_from_solution!(
                    energy_problem_benchmark,
                    energy_problem,
                    :assets_investment,
                )
                fix_variables_from_solution!(
                    energy_problem_benchmark,
                    energy_problem,
                    :assets_investment_energy,
                )

                # to fix also level of the seasonal storage
                if fix_level_storage
                    df_profiles = TIO.get_table(connection, "profiles")
                    scenarios = unique(df_profiles.scenario)
                    scenario_to_rep_period_map = Dict(i => val for (i, val) in enumerate(scenarios))
                    fix_storage_levels!(
                        energy_problem_benchmark,
                        energy_problem,
                        scenario_to_rep_period_map,
                        period_duration,
                        "hydro_reservoir",
                    )
                    fix_storage_levels!(
                        energy_problem_benchmark,
                        energy_problem,
                        scenario_to_rep_period_map,
                        period_duration,
                        "h2_storage",
                    )
                end

                @info "Resolving the benchmark case study: $case_name with $solver"
                time_to_resolve_benchmark = @elapsed TEM.solve_model!(energy_problem_benchmark)

                if energy_problem_benchmark.termination_status == JuMP.INFEASIBLE
                    JuMP.compute_conflict!(energy_problem_benchmark.model)
                    iis_model, reference_map = JuMP.copy_conflict(energy_problem_benchmark.model)
                    print(iis_model)
                end

                TEM.save_solution!(energy_problem_benchmark)
                var_flow_df = TIO.get_table(connection_benchmark, "var_flow")
                flow_ens = filter(
                    row -> row.from_asset == "ens" && row.to_asset == "e_demand",
                    var_flow_df,
                )
                flow_smr_ccs = filter(
                    row -> row.from_asset == "smr_ccs" && row.to_asset == "h2_demand",
                    var_flow_df,
                )
                water_borrowed = filter(
                    row ->
                        row.from_asset == "water_borrower" && row.to_asset == "hydro_reservoir",
                    var_flow_df,
                )

                # count steps with loss of load
                n_lol_ens = count(row -> row.solution > 0.0, eachrow(flow_ens))
                n_lol_smr_cca = count(row -> row.solution > 0.0, eachrow(flow_smr_ccs))

                # count how much water_borrowed
                amount_water_borrowed = sum(water_borrowed.solution)

                output_folder = joinpath(@__DIR__, "outputs", "fixed", case_name, string(solver))
                mkpath(output_folder)
                TEM.export_solution_to_csv_files(output_folder, energy_problem_benchmark)

                new_results_row = (
                    base_name = base_name,
                    rp = rp,
                    solver = solver,
                    time_to_cluster = time_to_cluster,
                    time_to_read = time_to_read,
                    time_to_create = time_to_create,
                    time_to_solve = time_to_solve,
                    time_to_save = time_to_save,
                    objective_value = energy_problem.objective_value,
                    termination_status = string(energy_problem.termination_status),
                    num_constraints = JuMP.num_constraints(
                        energy_problem.model;
                        count_variable_in_set_constraints = false,
                    ),
                    num_variables = JuMP.num_variables(energy_problem.model),
                    time_to_resolve_benchmark = time_to_resolve_benchmark,
                    objective_value_resolve_benchmark = energy_problem_benchmark.objective_value,
                    termination_status_resolve_benchmark = string(
                        energy_problem_benchmark.termination_status,
                    ),
                    num_loss_of_load_e_demand = n_lol_ens,
                    num_loss_of_load_h2_demand = n_lol_smr_cca,
                    water_borrowed = amount_water_borrowed,
                )
                push!(results_df, new_results_row)
            end
        end
    end

    results_df |> CSV.write("outputs/results.csv"; writeheader = true)

    return nothing
end

main()
