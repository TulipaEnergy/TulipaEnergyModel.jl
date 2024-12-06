using DataFrames

include("../csv-modifications.jl")

# Local cleanup to ensure clean files
run(`git restore test/inputs/ benchmark/EU/`)

this_agg(col) = begin
    ucol = unique(col)
    if !coalesce(all(col .== ucol), true)
        error("Won't happen")
    end
    return first(col)
end

apply_to_files_named("asset-both.csv") do path
    change_file(path) do t_both_csv
        dirpath = dirname(path)
        am_file = joinpath(dirpath, "asset-milestone.csv")
        change_file(am_file) do t_milestone_csv
            # Add new column to asset-milestone
            leftjoin!(
                t_milestone_csv.csv,
                combine(
                    groupby(t_both_csv.csv, [:asset, :milestone_year]),
                    :units_on_cost => this_agg => :units_on_cost,
                );
                on = [:asset, :milestone_year],
            )
            push!(t_milestone_csv.units, "")

            # Remove from asset-both
            df = t_both_csv.csv
            return unit, _ = remove_column(t_both_csv, "units_on_cost")
        end
    end
end

apply_to_files_named("flow-both.csv") do path
    change_file(path) do t_both_csv
        dirpath = dirname(path)
        am_file = joinpath(dirpath, "flow-milestone.csv")
        change_file(am_file) do t_milestone_csv
            # Add new column to flow-milestone
            leftjoin!(
                t_milestone_csv.csv,
                combine(
                    groupby(t_both_csv.csv, [:from_asset, :to_asset, :milestone_year]),
                    :variable_cost => this_agg => :variable_cost,
                );
                on = [:from_asset, :to_asset, :milestone_year],
            )
            push!(t_milestone_csv.units, "")

            # Remove from flow-both
            df = t_both_csv.csv
            return unit, _ = remove_column(t_both_csv, "variable_cost")
        end
    end
end
