using DataFrames

include("../csv-modifications.jl")

# Local cleanup to ensure clean files
run(`git restore test/inputs/ benchmark/EU/`)

# Add year to assets and flows data
for filename in ["assets-data.csv", "flows-data.csv"]
    apply_to_files_named(filename) do path
        change_file(path) do tcsv
            add_column(tcsv, "year", 2030; position = 5)
        end
    end
end

# New file to hold year information. Just one file for existing test files
# This file can exist even before the clustering
apply_to_files_named("year-data.csv"; include_missing = true) do path
    @debug "Creating $path"
    if isfile(path)
        rm(path)
    end
    touch(path)
    change_file(path) do tcsv
        tcsv.units = ["", "h"]
        tcsv.csv = DataFrame(:year => [2030], :length => [8760])
    end
end

# New file to hold timeframe information. This should be a by-product of the clustering.
# It should list the timeframes per year with their number of timesteps.
apply_to_files_named("timeframe-data.csv"; include_missing = true) do path
    if isfile(path)
        rm(path)
    end
    touch(path)
    change_file(path) do tcsv
        rep_periods_mapping = TulipaCSV(joinpath(dirname(path), "rep-periods-mapping.csv")).csv
        rep_periods_data = TulipaCSV(joinpath(dirname(path), "rep-periods-data.csv")).csv
        n = length(unique(rep_periods_mapping.period))

        tcsv.csv = unique(
            select(
                leftjoin(
                    rep_periods_mapping,
                    rep_periods_data;
                    on = :rep_period,
                    makeunique = true,
                ),
                :period,
                :num_timesteps,
            ),
        )
        tcsv.units = ["", ""]
        add_column(tcsv, "year", 2030; position = 1)
    end
end

# Some files are defined per rep_period (or subsets).
# For these files, just add `year` before `rep_period`:
for filename in [
    "assets-rep-periods-partitions.csv",
    "flows-rep-periods-partitions.csv",
    "profiles-rep-periods.csv",
    "rep-periods-data.csv",
]
    apply_to_files_named(filename) do path
        change_file(path) do tcsv
            idx = findfirst(==("rep_period"), names(tcsv.csv))
            @assert idx !== nothing
            add_column(tcsv, "year", 2030; position = idx)
        end
    end
end

# Some files are defined per period in a timeframe.
# For these files, just add `year` before `period`:
for filename in ["profiles-timeframe.csv", "rep-periods-mapping.csv"]
    apply_to_files_named(filename) do path
        change_file(path) do tcsv
            idx = findfirst(==("period"), names(tcsv.csv))
            @assert idx !== nothing
            add_column(tcsv, "year", 2030; position = idx)
        end
    end
end

# These are the links between assets/flows and the profile data.
# They should exist before the clustering as well, so the `year` specification already exists.
# For these files, just add `year` before the `profile_type`
for filename in [
    "assets-profiles.csv",
    "assets-timeframe-profiles.csv",
    "flows-profiles.csv",
    "flows-timeframe-profiles.csv",
]
    apply_to_files_named(filename) do path
        change_file(path) do tcsv
            idx = findfirst(==("profile_type"), names(tcsv.csv))
            @assert idx !== nothing
            add_column(tcsv, "year", 2030; position = idx)
        end
    end
end

# The partition of timeframes also happen per year.
# Maybe this should be renamed to `assets-year-partitions.csv`?
apply_to_files_named("assets-timeframe-partitions.csv") do path
    change_file(path) do tcsv
        add_column(tcsv, "year", 2030; position = 2)
    end
end

# And don't forget groups
apply_to_files_named("group-asset.csv") do path
    change_file(path) do tcsv
        add_column(tcsv, "year", 2030; position = 2)
    end
end
