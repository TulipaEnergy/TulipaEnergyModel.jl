
function get_solver_parameters(optimizer::Symbol)
    if optimizer == :HiGHS
        return HiGHS.Optimizer,
        Dict(
            "output_flag" => true,
            "solver" => "hipo",
            "parallel" => "on",
            "run_crossover" => "off",
        )
    elseif optimizer == :Gurobi
        return Gurobi.Optimizer, Dict("OutputFlag" => 1)
    else
        return HiGHS.Optimizer, Dict()
    end
end

function fix_variables_from_solution!(benchmark_model, reduced_model, var_symbol)
    var_to_fix = benchmark_model.variables[var_symbol].container
    val_to_fix = JuMP.value(reduced_model.variables[var_symbol].container)

    for (var, val) in zip(var_to_fix, val_to_fix)
        JuMP.fix(var, val; force = true)
    end
end

function plot_mu_vs_rp(
    results_df::DataFrame,
    case_studies_df::DataFrame;
    savepath = "value_at_risk_threshold_mu.png",
)
    results_with_options =
        outerjoin(case_studies_df, results_df; on = "base_name", makeunique = true)

    results_with_options =
        filter(row -> !ismissing(row.value_at_risk_threshold_mu), results_with_options)

    benchmark_df = filter(row -> row.base_name == "0_HourlyBenchmark", results_with_options)
    nonbenchmark_df = filter(row -> row.base_name != "0_HourlyBenchmark", results_with_options)

    rp_vals = sort(unique(nonbenchmark_df.rp))
    rp_labels = string.(rp_vals)
    rp_index = Dict(rp => i for (i, rp) in enumerate(rp_vals))

    p = plot(;
        xlabel = "Number of representative_periods",
        ylabel = "Optimal value_at_risk_threshold_mu",
        title = "",
        legend = :topright,
        size = (800, 500),
        xticks = (1:length(rp_vals), rp_labels),
    )

    for g in groupby(nonbenchmark_df, :base_name)
        g_sorted = sort(g, :rp)

        stochastic_method = g.stochastic_method[1]
        mk = get(MARKER_MAP, stochastic_method) do
            return error("Unknown stochastic_method: $stochastic_method")
        end

        weight_type = g.weight_type[1]
        mcol = get(COLOR_MAP_weight, weight_type) do
            return error("Unknown weight_type: $weight_type")
        end

        xidx = [rp_index[rp] for rp in g_sorted.rp]

        scatter!(
            p,
            xidx,
            g_sorted.value_at_risk_threshold_mu;
            markershape = mk,
            markersize = 8,
            markercolor = mcol,
            label = "",
        )

        plot!(
            p,
            xidx,
            g_sorted.value_at_risk_threshold_mu;
            color = mcol,
            linewidth = 1.5,
            label = "",
        )
    end

    # Benchmark as horizontal reference line
    if nrow(benchmark_df) > 0
        mu_benchmark = benchmark_df.value_at_risk_threshold_mu[1]

        hline!(
            p,
            [mu_benchmark];
            color = :black,
            linestyle = :dash,
            linewidth = 2,
            label = "Hourly benchmark",
        )
    end

    # Legend for shapes (stochastic methods)
    for (label, marker) in MARKER_MAP
        short_label = replace(string(label), "_scenario" => "-scenario")
        scatter!(
            p,
            [NaN],
            [NaN];
            markershape = marker,
            markersize = 8,
            markercolor = :gray30,
            label = short_label,
        )
    end

    # Legend for colors (weight types)
    for (label, color) in COLOR_MAP_weight
        scatter!(
            p,
            [NaN],
            [NaN];
            markershape = :rect,
            markersize = 8,
            markercolor = color,
            label = get(LEGEND_METHOD_MAP, label) do
                return error("Unknown method: $label")
            end,
        )
    end

    savefig(p, savepath)
    @info "Plot saved in: $savepath"
end

function plot_values_stocmethod_weight( #considering different options: stochastic_method, weight_type
    results_df::DataFrame,
    case_studies_df::DataFrame,
    values::String;
    savepath = "relative_regret.png",
)
    results_with_options =
        outerjoin(case_studies_df, results_df; on = "base_name", makeunique = true)
    results_with_options = filter(row -> row.base_name != "0_HourlyBenchmark", results_with_options)

    rp_vals = sort(unique(results_with_options.rp))
    rp_labels = string.(rp_vals)
    rp_index = Dict(rp => i for (i, rp) in enumerate(rp_vals))

    p = plot(;
        xlabel = "Number of representative_periods",
        ylabel = get(VALUE_MAP, values) do
            return error("Unknown values: $values")
        end,
        title = "",
        legend = :topright,
        size = (800, 500),
        xticks = (1:length(rp_vals), rp_labels),
    )
    for g in groupby(results_with_options, :base_name)
        name = g.base_name[1]
        if name == "0_HourlyBenchmark"
            continue
        end
        g_sorted = sort(g, :rp)

        stochastic_method = g.stochastic_method[1]
        mk = get(MARKER_MAP, stochastic_method) do
            return error("Unknown stochastic_method: $stochastic_method")
        end

        weight_type = g.weight_type[1]
        mcol = get(COLOR_MAP_weight, weight_type) do
            return error("Unknown weight_type: $weight_type")
        end

        column = Symbol(values)
        xidx = [rp_index[rp] for rp in g_sorted.rp]

        scatter!(
            p,
            xidx,
            g_sorted[!, column];
            markershape = mk,
            markersize = 8,
            markercolor = mcol,
            label = "",
        )
    end

    # Legend for shapes (stochastic methods)
    for (label, marker) in MARKER_MAP
        short_label = replace(label, "_scenario" => "-scenario")
        scatter!(
            p,
            [NaN],
            [NaN];
            markershape = marker,
            markersize = 8,
            markercolor = :gray30,
            label = short_label,
        )
    end

    # Legend for colors (weight types)
    for (label, color) in COLOR_MAP_weight
        scatter!(
            p,
            [NaN],
            [NaN];
            markershape = :rect,
            markersize = 8,
            markercolor = color,
            label = get(LEGEND_METHOD_MAP, label) do
                return error("Unknown method: $label")
            end,
        )
    end

    savefig(p, savepath)
    @info "Plot saved in: $savepath"
end

function plot_values_stocmethod_method( # considering options: method, stochastic_method (possible to add weight type dirac)
    results_df::DataFrame,
    case_studies_df::DataFrame,
    values::String;
    savepath = "relative_regret.png",
    include_dirac = false,
    from_rp = 0,
    chosen_method = nothing,
)
    results_with_options =
        outerjoin(case_studies_df, results_df; on = "base_name", makeunique = true)
    results_with_options = filter(row -> row.base_name != "0_HourlyBenchmark", results_with_options)

    rp_vals = sort(unique(results_with_options.rp))
    rp_labels = string.(rp_vals)
    rp_index = Dict(rp => i for (i, rp) in enumerate(rp_vals))

    p = plot(;
        xlabel = "Number of representative periods",
        ylabel = get(VALUE_MAP, values) do
            return error("Unknown values: $values")
        end,
        title = "",
        legend = :topright,
        size = (800, 500),
        xticks = (1:length(rp_vals), rp_labels),
    )
    if !include_dirac
        results_with_options = filter(row -> row.weight_type != "dirac", results_with_options)
    end

    if chosen_method !== nothing
        results_with_options = filter(row -> row.method == chosen_method, results_with_options)
    end
    results_with_options = filter(row -> row.rp >= from_rp, results_with_options)

    for g in groupby(results_with_options, :base_name)
        name = g.base_name[1]
        if name == "0_HourlyBenchmark"
            continue
        end
        g_sorted = sort(g, :rp)

        stochastic_method = g.stochastic_method[1]
        mk = get(MARKER_MAP, stochastic_method) do
            return error("Unknown stochastic_method: $stochastic_method")
        end

        method = g.method[1]
        mcolout = get(COLOR_MAP_method, method) do
            return error("Unknown method: $method")
        end

        weight_type = g.weight_type[1]
        mcolin = get(FILLER_MAP, weight_type) do
            return error("Unknown weight_type: $weight_type")
        end

        column = Symbol(values)
        xidx = [rp_index[rp] for rp in g_sorted.rp]

        if !include_dirac
            mcolout = :black
        end

        scatter!(
            p,
            xidx,
            g_sorted[!, column];
            markershape = mk,
            markersize = 8,
            markercolor = mcolin,
            markerstrokecolor = mcolout,
            label = "",
        )
    end

    # Legend for shapes (stochastic methods)
    for (label, marker) in MARKER_MAP
        short_label = replace(label, "_scenario" => "-scenario")
        scatter!(
            p,
            [NaN],
            [NaN];
            markershape = marker,
            markersize = 8,
            markercolor = :gray30,
            label = short_label,
        )
    end

    # Legend for colors (method types)
    for (label, color) in COLOR_MAP_method
        scatter!(
            p,
            [NaN],
            [NaN];
            markershape = :rect,
            markersize = 8,
            markercolor = color,
            label = get(LEGEND_METHOD_MAP, label) do
                return error("Unknown method: $label")
            end,
        )
    end
    if include_dirac
        # Legend for filler colors (weights type)
        scatter!(
            p,
            [NaN],
            [NaN];
            markershape = :rect,
            markersize = 8,
            markercolor = :white,
            label = "dirac weights",
        )
    end

    savefig(p, savepath)
    @info "Plot saved in: $savepath"
end

function parse_rep_period_name(name::String) # the vars were created as storage_level_rep_period[$(row.asset),$(row.year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]
    inside = name[findfirst('[', name)+1:end-1] # inside []
    parts = split(inside, ",")
    return (
        asset = parts[1],
        year = parse(Int, parts[2]),
        rep_period = parse(Int, parts[3]),
        time_block_start = parse(Int, split(parts[4], ":")[1]),
    )
end

function parse_over_clustered_name(name::String) # storage_level_over_clustered_year[$(row.asset),$(row.year),$(row.scenario),$(row.period_block_start):$(row.period_block_end)]
    inside = name[findfirst('[', name)+1:end-1]
    parts = split(inside, ",")
    return (
        asset = parts[1],
        year = parse(Int, parts[2]),
        scenario = parse(Int, parts[3]),
        period_block_start = parse(Int, split(parts[4], ":")[1]),
    )
end

function fix_storage_levels!(
    benchmark_model,
    reduced_model,
    scenario_to_rep_period_map,
    period_duration,
    storage_asset,
)
    bench_vars = benchmark_model.variables[:storage_level_rep_period].container
    red_vars = reduced_model.variables[:storage_level_over_clustered_year].container

    bench_pairs = [
        (bench_vars[i], parse_rep_period_name(JuMP.name(bench_vars[i]))) for
        i in eachindex(bench_vars)
    ]

    red_pairs = [
        (red_vars[i], parse_over_clustered_name(JuMP.name(red_vars[i]))) for
        i in eachindex(red_vars)
    ]

    bench_pairs = filter(p -> p[2].asset == storage_asset, bench_pairs)
    red_pairs = filter(p -> p[2].asset == storage_asset, red_pairs)

    val_to_fix = Dict()

    for (v, row) in red_pairs
        key = (row.asset, row.year, row.scenario, row.period_block_start)
        val_to_fix[key] = JuMP.value(v)
    end

    for (v, row) in bench_pairs

        # only at the end of each day
        if row.time_block_start % period_duration != 0
            continue
        end
        scenario = scenario_to_rep_period_map[row.rep_period]

        period = row.time_block_start ÷ period_duration

        key = (row.asset, row.year, scenario, period)

        if haskey(val_to_fix, key)
            JuMP.fix(v, val_to_fix[key]; force = true)
        else
            error("No reduced_model value found for key $key")
        end
    end

    return nothing
end

function plot_storage_behavior(
    results_df::DataFrame,
    case_studies_df::DataFrame,
    storage_levels_hourly::DataFrame,
    storage_asset::String,
    representative_periods::Vector{Int64},
    scenario::Int64;
    tables_path = "outputs",
    savepath = "storage.png",
)
    results_with_options =
        outerjoin(case_studies_df, results_df; on = "base_name", makeunique = true)

    asset_to_filter = storage_asset
    hourly_filtered_asset = filter(row -> row.asset == asset_to_filter, storage_levels_hourly)
    hourly_filtered_asset = filter(row -> row.rep_period == scenario, hourly_filtered_asset)

    # grid for all rp subplots
    n = length(representative_periods)
    ncols = min(n, 3)
    nrows = ceil(Int, n / ncols)

    p = plot(; layout = grid(nrows, ncols), link = :x, size = (1500, 350 * nrows), legend = false)

    for (i, rp) in enumerate(representative_periods)
        # plotting the results for the hourly benchmark
        plot!(
            p,
            hourly_filtered_asset.time_block_end,
            hourly_filtered_asset.solution;
            subplot = i,
            label = "hourly",
            color = :red,
            title = "Storage level — $asset_to_filter (rp = $rp)",
            xlabel = "Hour",
            ylabel = "[GWh]",
            xlims = (1, 8760),
            legend = false,
            dpi = 600,
        )

        # add storage levels for each base_name, but using the rp-specific folder
        for g in groupby(results_with_options, :base_name)
            name = g.base_name[1]
            if name == "0_HourlyBenchmark"
                continue
            end

            stochastic_method = g.stochastic_method[1]

            stochastic_method = g.stochastic_method[1]
            mk = get(LINE_MAP, stochastic_method) do
                return error("Unknown stochastic_method: $stochastic_method")
            end

            weight_type = g.weight_type[1]
            mcol = get(FILLER_MAP, weight_type) do
                return error("Unknown weight_type: $weight_type")
            end

            name_rp = string(name, "_rp_", rp)

            path = joinpath(
                tables_path,
                "fixed",
                name_rp,
                "Gurobi",
                "var_storage_level_rep_period.csv",
            )

            reduced_storage_levels = CSV.read(path, DataFrame)

            reduced_filtered_asset =
                filter(row -> row.asset == asset_to_filter, reduced_storage_levels)
            reduced_filtered_asset =
                filter(row -> row.rep_period == scenario, reduced_filtered_asset)

            plot!(
                p,
                reduced_filtered_asset.time_block_end,
                reduced_filtered_asset.solution;
                subplot = i,
                label = "$stochastic_method selection",
                color = mcol,
                linestyle = mk,
            )
        end
    end

    savefig(p, savepath)
    @info "Plot saved in: $savepath"
end

using DataFrames
