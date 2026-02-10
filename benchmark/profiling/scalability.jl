using BenchmarkTools: @benchmark
using CSV: CSV
using DataFrames: DataFrame
using DuckDB: DuckDB, DBInterface
using Plots: Plots
using Statistics: Statistics
using TulipaEnergyModel: TulipaEnergyModel as TEM
using TulipaIO: TulipaIO as TIO

include("../tulipa-data.jl")

function common_setup(; kwargs...)
    connection, tulipa_data = create_synthetic_problem(; kwargs...)
    TEM.populate_with_defaults!(connection)
    return connection, tulipa_data
end

# using StatsPlots

function setup_lower_level_pipeline(; kwargs...)
    connection, tulipa_data = common_setup(; kwargs...)

    # Internal data and structures pre-model
    TEM.create_internal_tables!(connection)
    model_parameters = TEM.ModelParameters(connection)
    variables = TEM.compute_variables_indices(connection)
    constraints = TEM.compute_constraints_indices(connection)
    profiles = TEM.prepare_profiles_structure(connection)

    #= Comment out before relevant function
    # Create model
    model, expressions = TEM.create_model(
        connection,
        variables,
        constraints,
        profiles,
        model_parameters,
    )

    # Solve model
    TEM.solve_model(model)
    TEM.save_solution!(connection, model, variables, constraints)
    output_dir = mktempdir()
    TEM.export_solution_to_csv_files(output_dir, connection)
    =#

    return connection
end

function relevant_lower_level_pipeline(connection)
    # Write relevant function
    model, expressions =
        TEM.create_model(connection, variables, constraints, profiles, model_parameters)

    return nothing
end

function setup_higher_level_pipeline(; kwargs...)
    connection, tulipa_data = common_setup(; kwargs...)

    energy_problem = TEM.EnergyProblem(connection)
    #= Comment out before relevant function
    TEM.create_model!(energy_problem)
    TEM.solve_model!(energy_problem)
    TEM.save_solution!(energy_problem)
    TEM.export_solution_to_csv_files(mktempdir(), energy_problem)
    =#

    return connection, energy_problem
end

function relevant_higher_level_pipeline(connection, energy_problem)
    # Write relevant function
    TEM.create_model!(energy_problem)

    return nothing
end

function compute_results(grid)
    results = Dict()
    for num_countries in grid.num_countries, num_rep_periods in grid.num_rep_periods
        @info "Running benchmark for num_countries = $num_countries and num_rep_periods = $num_rep_periods"
        problem_kwargs = (; num_rep_periods, num_countries)
        key = (num_countries, num_rep_periods)

        # Uncomment one of the two
        # Lower level API
        # results[key] = @benchmark relevant_lower_level_pipeline(connection) setup=(connection=setup_lower_level_pipeline(;$problem_kwargs...))

        # Higher level API
        results[key] = @benchmark relevant_higher_level_pipeline(connection, energy_problem) setup =
            ((connection, energy_problem) = setup_higher_level_pipeline(; $problem_kwargs...))

        @info results[key]
    end

    return results
end

function fake_results(grid)
    results = Dict()
    for num_countries in grid.num_countries, num_rep_periods in grid.num_rep_periods
        @info "Create fake results for num_countries = $num_countries and num_rep_periods = $num_rep_periods"
        key = (num_countries, num_rep_periods)
        nc = num_countries
        nrp = num_rep_periods
        nt = rand(3:8) # length of times
        results[key] = (
            memory = 0,
            times = 1e9 * (
                (1.6 + 0.001nc + 0.0002nrp + 0.1nc * nrp) * (1 .+ randn(nt) * 0.01) +
                rand(nt) * 0.03nc * nrp
            ),
        )
    end

    return results
end

function convert_results_to_df(grid, results)
    df = DataFrame(
        (num_countries = nc, num_rep_periods = nrp, execution_id = id, elapsed_time = t) for
        ((nc, nrp), data) in results for (id, t) in enumerate(data.times)
    )

    return df
end

function plot_results(results_df)
    summary =
        results_df |>
        df ->
            groupby(df, [:num_countries, :num_rep_periods]) |>
            df ->
                combine(
                    df,
                    :elapsed_time => Statistics.mean => :elapsed_time_mean,
                    :elapsed_time => Statistics.std => :elapsed_time_std,
                ) |> df -> sort(df, [:num_countries, :num_rep_periods])
    x = summary.num_countries .* summary.num_rep_periods
    X = [ones(length(x)) x]
    y = summary.elapsed_time_mean / 1e9
    beta = X \ y
    plt = Plots.plot(;
        size = (1200, 800),
        xlabel = "num_countries * num_rep_periods",
        ylabel = "mean time",
    )
    Plots.scatter!(x, y; m = (:circle, stroke(1, :teal), :white), lab = "mean time")
    Plots.plot!(x -> beta[1] + beta[2] * x, extrema(x)...; c = :teal, lw = 2, lab = "fit")
    plots_path = joinpath(@__DIR__, "results")
    Plots.png(plt, plots_path)

    return plt
end

# Use the `fake_results` to make sure that plotting works
# Use smaller `grid` to test compute_results
# Then define proper grid and run everything
# Be patient

grid = (num_countries = [2, 4, 8, 16, 32, 64, 128], num_rep_periods = 3:3:15)
# grid = (num_countries = [10, 20, 40, 80], num_rep_periods = [3, 6, 12])
# grid = (num_countries = [2, 3], num_rep_periods = [3, 4])
results = compute_results(grid)
# results = fake_results(grid)
results_df = convert_results_to_df(grid, results)
results_path = joinpath(@__DIR__, "scalability_results.csv")
CSV.write(results_path, results_df)
plot_results(results_df)
