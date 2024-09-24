using DataFrames

include("../csv-modifications.jl")

# Local cleanup
run(`git restore test/inputs benchmark/EU`)

# Creating new file
apply_to_files_named("vintage-assets-data.csv"; include_missing = true) do path
    # Cleaning
    if isfile(path)
        rm(path)
    end
    # Creating empty
    touch(path)

    t_assets_data = TulipaCSV(joinpath(dirname(path), "assets-data.csv"))
    change_file(path) do tcsv
        tcsv.units = ["", "", "kEUR/MW/year", "kEUR/MW/year"]
        tcsv.csv =
            t_assets_data.csv[:, [:name, :commission_year, :fixed_cost, :investment_cost]] |> unique
    end
end

# Changes to the graph-assets-data file
apply_to_files_named("graph-assets-data.csv") do path
    change_file(path) do tcsv
        change_file(joinpath(dirname(path), "assets-data.csv")) do t_assets_data
            df = t_assets_data.csv[:, [:name, :capacity, :technical_lifetime]] |> unique

            append!(tcsv.units, ["MW", "year"])
            leftjoin!(tcsv.csv, df; on = :name)
            add_column(tcsv, "discount_rate", 0.05)

            remove_column(t_assets_data, :capacity)
            remove_column(t_assets_data, :technical_lifetime)
        end
    end
end

# Creating new file
apply_to_files_named("vintage-flows-data.csv"; include_missing = true) do path
    # Cleaning
    if isfile(path)
        rm(path)
    end
    # Creating empty
    touch(path)

    t_assets_data = TulipaCSV(joinpath(dirname(path), "flows-data.csv"))
    change_file(path) do tcsv
        tcsv.units = ["asset_name", "asset_name", "kEUR/MW"]
        tcsv.csv = t_assets_data.csv[:, [:from_asset, :to_asset, :investment_cost]] |> unique
    end
end

# Changes to the graph-assets-data file
apply_to_files_named("graph-flows-data.csv") do path
    change_file(path) do tcsv
        change_file(joinpath(dirname(path), "flows-data.csv")) do t_flows_data
            df = t_flows_data.csv[:, [:from_asset, :to_asset, :capacity]] |> unique

            append!(tcsv.units, ["MW"])
            leftjoin!(tcsv.csv, df; on = [:from_asset, :to_asset])

            remove_column(t_flows_data, :capacity)
        end
    end
end
