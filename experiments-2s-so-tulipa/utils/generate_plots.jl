# Run this only after results given from main

using DataFrames
using CSV
using Plots

# helper functions
@info "Including constants and helper functions"
include("constants.jl")
include("functions.jl")

mkpath("outputs/plots")
results = "outputs/results.csv"
results_df = CSV.read(results, DataFrame)

hourly_row = results_df[results_df.base_name.=="0_HourlyBenchmark", :]
hourly_obj = only(hourly_row.objective_value)

# compute relative regret 
results_df.rel_regret = [
    row.base_name == "0_HourlyBenchmark" ? 0.0 :
    (row.objective_value_resolve_benchmark - hourly_obj) / hourly_obj
    for row in eachrow(results_df)
]

case_studies_path = "case-studies-info.csv"
case_studies_df = CSV.read(case_studies_path, DataFrame)
@info "Plotting relative regret"
plot_values_stocmethod_method(results_df, case_studies_df, "rel_regret"; savepath="outputs/plots/relative_regret.png")

@info "Plotting time to cluster"
plot_values_stocmethod_method(results_df, case_studies_df, "time_to_cluster"; savepath="outputs/plots/time_to_cluster.png")

@info "Plotting time to solve"
plot_values_stocmethod_method(results_df, case_studies_df, "time_to_solve"; savepath="outputs/plots/time_to_solve.png")

@info "Plotting time to create"
plot_values_stocmethod_method(results_df, case_studies_df, "time_to_create"; savepath="outputs/plots/time_to_create.png")


# compute total time 
results_df.total_time = [
    row.time_to_cluster + row.time_to_read + row.time_to_create + row.time_to_solve + row.time_to_save
    for row in eachrow(results_df)
]

@info "Plotting total time"
plot_values_stocmethod_method(results_df, case_studies_df, "total_time"; savepath="outputs/plots/total_time.png")

# compute number of steps with loss of load 
hourly_lol_e = only(hourly_row.num_loss_of_load_e_demand)
hourly_lol_h2 = only(hourly_row.num_loss_of_load_h2_demand)
results_df.num_loss_of_load_e_demand = [
    row.num_loss_of_load_e_demand - hourly_lol_e
    for row in eachrow(results_df)
]
results_df.num_loss_of_load_h2_demand = [
    row.num_loss_of_load_h2_demand - hourly_lol_h2
    for row in eachrow(results_df)
]
results_df.num_loss_of_load_tot = [
    row.num_loss_of_load_e_demand + row.num_loss_of_load_h2_demand
    for row in eachrow(results_df)
]


@info "Plotting number of steps with lol e_demand"
plot_values_stocmethod_method(results_df, case_studies_df, "num_loss_of_load_e_demand"; savepath="outputs/plots/num_loss_of_load_e_demand.png")

@info "Plotting number of steps with lol h2_demand"
plot_values_stocmethod_method(results_df, case_studies_df, "num_loss_of_load_h2_demand"; savepath="outputs/plots/num_loss_of_load_h2_demand.png")

@info "Plotting number of steps with lol e_demand"
plot_values_stocmethod_method(results_df, case_studies_df, "num_loss_of_load_tot"; savepath="outputs/plots/num_loss_of_load_tot_demand.png")

@info "Plotting amount of water borrowed"
plot_values_stocmethod_method(results_df, case_studies_df, "water_borrowed"; savepath="outputs/plots/water_borrowed.png")


mkpath("outputs/plots/big_rps")
# to plot zoomed in from 60 rps
@info "Plotting for >=60 rps"
plot_values_stocmethod_method(results_df, case_studies_df, "rel_regret"; savepath="outputs/plots/big_rps/relative_regret.png", from_rp=60)

plot_values_stocmethod_method(results_df, case_studies_df, "time_to_cluster"; savepath="outputs/plots/big_rps/time_to_cluster.png", from_rp=60)

plot_values_stocmethod_method(results_df, case_studies_df, "time_to_solve"; savepath="outputs/plots/big_rps/time_to_solve.png", from_rp=60)

plot_values_stocmethod_method(results_df, case_studies_df, "time_to_create"; savepath="outputs/plots/big_rps/time_to_create.png", from_rp=60)

plot_values_stocmethod_method(results_df, case_studies_df, "total_time"; savepath="outputs/plots/big_rps/total_time.png", from_rp=60)

plot_values_stocmethod_method(results_df, case_studies_df, "total_time"; savepath="outputs/plots/big_rps/total_time.png", from_rp=60)

plot_values_stocmethod_method(results_df, case_studies_df, "num_loss_of_load_e_demand"; savepath="outputs/plots/big_rps/num_loss_of_load_e_demand.png", from_rp=60)

plot_values_stocmethod_method(results_df, case_studies_df, "num_loss_of_load_h2_demand"; savepath="outputs/plots/big_rps/num_loss_of_load_h2_demand.png", from_rp=60)

plot_values_stocmethod_method(results_df, case_studies_df, "num_loss_of_load_tot"; savepath="outputs/plots/big_rps/num_loss_of_load_tot_demand.png", from_rp=60)


methods = ["convex_hull", "conical_hull", "convex_hull_with_null"]

@info "Plotting for each method separately"
for chosen_method in methods
    mkpath(joinpath("outputs", "plots", chosen_method))
    plot_values_stocmethod_method(results_df, case_studies_df, "rel_regret"; savepath="outputs/plots/$chosen_method/relative_regret.png", chosen_method)

    plot_values_stocmethod_method(results_df, case_studies_df, "time_to_cluster"; savepath="outputs/plots/$chosen_method/time_to_cluster.png", chosen_method)

    plot_values_stocmethod_method(results_df, case_studies_df, "time_to_solve"; savepath="outputs/plots/$chosen_method/time_to_solve.png", chosen_method)

    plot_values_stocmethod_method(results_df, case_studies_df, "time_to_create"; savepath="outputs/plots/$chosen_method/time_to_create.png", chosen_method)

    plot_values_stocmethod_method(results_df, case_studies_df, "total_time"; savepath="outputs/plots/$chosen_method/total_time.png", chosen_method)

    plot_values_stocmethod_method(results_df, case_studies_df, "total_time"; savepath="outputs/plots/$chosen_method/total_time.png", chosen_method)

    plot_values_stocmethod_method(results_df, case_studies_df, "num_loss_of_load_e_demand"; savepath="outputs/plots/$chosen_method/num_loss_of_load_e_demand.png", chosen_method)

    plot_values_stocmethod_method(results_df, case_studies_df, "num_loss_of_load_h2_demand"; savepath="outputs/plots/$chosen_method/num_loss_of_load_h2_demand.png", chosen_method)

    plot_values_stocmethod_method(results_df, case_studies_df, "num_loss_of_load_tot"; savepath="outputs/plots/$chosen_method/num_loss_of_load_tot_demand.png", chosen_method)

    mkpath(joinpath("outputs", "plots", chosen_method, "big_rps"))
    plot_values_stocmethod_method(results_df, case_studies_df, "rel_regret"; savepath="outputs/plots/$chosen_method/big_rps/relative_regret.png", from_rp=60, chosen_method)

    plot_values_stocmethod_method(results_df, case_studies_df, "time_to_cluster"; savepath="outputs/plots/$chosen_method/big_rps/time_to_cluster.png", from_rp=60, chosen_method)

    plot_values_stocmethod_method(results_df, case_studies_df, "time_to_solve"; savepath="outputs/plots/$chosen_method/big_rps/time_to_solve.png", from_rp=60, chosen_method)

    plot_values_stocmethod_method(results_df, case_studies_df, "time_to_create"; savepath="outputs/plots/$chosen_method/big_rps/time_to_create.png", from_rp=60, chosen_method)

    plot_values_stocmethod_method(results_df, case_studies_df, "total_time"; savepath="outputs/plots/$chosen_method/big_rps/total_time.png", from_rp=60, chosen_method)

    plot_values_stocmethod_method(results_df, case_studies_df, "total_time"; savepath="outputs/plots/$chosen_method/big_rps/total_time.png", from_rp=60, chosen_method)

    plot_values_stocmethod_method(results_df, case_studies_df, "num_loss_of_load_e_demand"; savepath="outputs/plots/$chosen_method/big_rps/num_loss_of_load_e_demand.png", from_rp=60, chosen_method)

    plot_values_stocmethod_method(results_df, case_studies_df, "num_loss_of_load_h2_demand"; savepath="outputs/plots/$chosen_method/big_rps/num_loss_of_load_h2_demand.png", from_rp=60, chosen_method)

    plot_values_stocmethod_method(results_df, case_studies_df, "num_loss_of_load_tot"; savepath="outputs/plots/$chosen_method/big_rps/num_loss_of_load_tot_demand.png", from_rp=60, chosen_method)
end


@info "Plotting storage behavior comparing per and cross"
base_name = "0_HourlyBenchmark"
bench_path = joinpath("outputs", base_name, "Gurobi", "var_storage_level_rep_period.csv")
representative_periods = [9, 15, 30, 60, 90, 120, 180, 240, 360]
storage_levels_hourly = CSV.read(bench_path, DataFrame)

plot_storage_behavior(results_df, case_studies_df, storage_levels_hourly, "hydro_reservoir", representative_periods, 1; tables_path="outputs", savepath="outputs/plots/hydro_reservoir_scen1.png")
plot_storage_behavior(results_df, case_studies_df, storage_levels_hourly, "h2_storage", representative_periods, 1; tables_path="outputs", savepath="outputs/plots/h2_storage_scen1.png")


plot_storage_behavior(results_df, case_studies_df, storage_levels_hourly, "hydro_reservoir", representative_periods, 2; tables_path="outputs", savepath="outputs/plots/hydro_reservoir_scen2.png")
plot_storage_behavior(results_df, case_studies_df, storage_levels_hourly, "h2_storage", representative_periods, 2; tables_path="outputs", savepath="outputs/plots/h2_storage_scen2.png")


plot_storage_behavior(results_df, case_studies_df, storage_levels_hourly, "hydro_reservoir", representative_periods, 3; tables_path="outputs", savepath="outputs/plots/hydro_reservoir_scen3.png")
plot_storage_behavior(results_df, case_studies_df, storage_levels_hourly, "h2_storage", representative_periods, 3; tables_path="outputs", savepath="outputs/plots/h2_storage_scen3.png")