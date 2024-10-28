using DataFrames

include("../csv-modifications.jl")

# Local cleanup to ensure clean files
apply_to_files_named(rm, "graph-assets-data.csv")
apply_to_files_named(rm, "graph-flows-data.csv")
run(`git restore test/inputs/ benchmark/EU/`)

# graph-assets-data.csv is created by simplifying assets-data.csv (and flows)
apply_to_files_named("assets-data.csv") do path
    # Old file changes
    change_file(path) do old_tcsv
        new_file = "graph-assets-data.csv"
        new_file_path = joinpath(dirname(path), new_file)

        static_cols = [:type, :group]

        # New file changes
        touch(new_file_path)
        change_file(new_file_path) do tcsv
            cols = [:name; static_cols]
            indices = columnindex.(Ref(old_tcsv.csv), cols)

            tcsv.units = old_tcsv.units[indices]
            tcsv.csv = unique(old_tcsv.csv[:, indices])

            idx = findfirst(names(tcsv.csv) .== "investment_cost")
            add_column(tcsv, "investment_method", "simple"; unit = "{none;simple;compact}")
        end

        indices = setdiff(1:length(old_tcsv.units), columnindex.(Ref(old_tcsv.csv), static_cols))
        old_tcsv.units = old_tcsv.units[indices]
        old_tcsv.csv = old_tcsv.csv[:, indices]
    end
end

apply_to_files_named("flows-data.csv") do path
    # Old file changes
    change_file(path) do old_tcsv
        new_file = "graph-flows-data.csv"
        new_file_path = joinpath(dirname(path), new_file)

        static_cols = [:carrier]

        # New file changes
        touch(new_file_path)
        change_file(new_file_path) do tcsv
            cols = [:from_asset; :to_asset; static_cols]
            indices = columnindex.(Ref(old_tcsv.csv), cols)

            tcsv.units = old_tcsv.units[indices]
            tcsv.csv = unique(old_tcsv.csv[:, indices])
        end

        indices = setdiff(1:length(old_tcsv.units), columnindex.(Ref(old_tcsv.csv), static_cols))
        old_tcsv.units = old_tcsv.units[indices]
        old_tcsv.csv = old_tcsv.csv[:, indices]
    end
end

apply_to_files_named("year-data.csv") do path
    change_file(path) do tcsv
        add_column(tcsv, "is_milestone", true; unit = "{true;false}")
    end
end
