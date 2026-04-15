using TulipaEnergyModel
using TulipaIO
using DuckDB
using JuMP
using Gurobi
using DataFrames
using CSV

experiment_inputs_dir = "debugging/experiment-inputs/single-country"
experiment_results_dir = "debugging/experiment-results"
reference_objective = 2338362.08463463

cases = ["1var-0", "1var-E1C"]

# DB connection helper
function input_setup_regret(input_folder)
    connection = DBInterface.connect(DuckDB.DB)

    TulipaIO.read_csv_folder(
        connection,
        input_folder;
        schemas = TulipaEnergyModel.schema_per_table_name,
    )
    return connection
end

function regret_calculation(case, reference_objective)
    # case = "1var-0"

    input_folder = joinpath(pwd(), "$experiment_inputs_dir/$case")

    connection = input_setup_regret(input_folder)

    energy_problem = EnergyProblem(connection)
    create_model!(energy_problem)
    solve_model!(energy_problem)

    save_solution!(energy_problem)

    investments_made = get_table(connection, "var_assets_investment")[:, [:asset, :solution]]
    investments_made.solution = round.(investments_made.solution)

    CSV.write(
        "$experiment_results_dir/investment-solutions/$case-investments.csv",
        DataFrame(investments_made),
    )

    indices = DuckDB.query(
        connection,
        "SELECT
            var.id,
            var.asset,
            obj.weight_for_asset_investment_discount
                * obj.investment_cost
                * obj.capacity
                AS cost,
        FROM var_assets_investment AS var
        LEFT JOIN t_objective_assets as obj
            ON var.asset = obj.asset
            AND var.milestone_year = obj.milestone_year
        ORDER BY var.id
        ",
    )

    investments_and_costs = leftjoin(DataFrame(indices), investments_made; on = :asset)

    assets_investment_cost = sum(investments_and_costs.cost .* investments_and_costs.solution)

    input_folder_baseline = joinpath(pwd(), "$experiment_inputs_dir/regret_baseline")

    asset_both_df = DataFrame(CSV.File("$input_folder_baseline/asset-both.csv"))

    asset_both_df = leftjoin(asset_both_df, investments_made; on = :asset)
    asset_both_df.initial_units = asset_both_df.solution
    asset_both_df = select!(asset_both_df, Not(:solution))

    asset_both_df[asset_both_df.asset.=="ens", :initial_units] .= 1
    asset_both_df[asset_both_df.asset.=="demand", :initial_units] .= 0

    CSV.write("$input_folder_baseline/asset-both.csv", asset_both_df)

    connection = input_setup_regret(input_folder_baseline)

    energy_problem_baseline = EnergyProblem(connection)

    create_model!(energy_problem_baseline)

    solve_model!(energy_problem_baseline)

    REGRET =
        (energy_problem_baseline.objective_value + assets_investment_cost) - reference_objective

    return [REGRET, assets_investment_cost, energy_problem_baseline.objective_value]
end

function write_results_regret(metrics_dict)
    open("$experiment_results_dir/regret.csv", "w") do io
        println(io, "case,regret,investment_cost,operation_cost")

        for (key, value) in metrics_dict
            to_print = "$key," * join(value, ",")
            println(io, to_print)
        end
    end
end

metrics_dict = Dict()

for case in cases
    metrics_dict[case] = regret_calculation(case, reference_objective)
end

write_results_regret(metrics_dict)
