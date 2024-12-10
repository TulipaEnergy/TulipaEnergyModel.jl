using DataFrames

include("../csv-modifications.jl")

tiny_folder = "test/inputs/Tiny"
multiyear_folder = "test/inputs/Multi-year Investments"

# We clean up and copy Tiny
if isdir(multiyear_folder)
    rm(multiyear_folder; recursive = true)
end
cp(tiny_folder, multiyear_folder)

# Always inside the right folder
cd(multiyear_folder) do
    # Extra bad-assets.csv is not necessary
    rm("bad-assets-data.csv")

    # Copy rows and change year to 2050 in new lines
    for filename in (
        "assets-data.csv",
        "assets-profiles.csv",
        "flows-data.csv",
        "flows-profiles.csv",
        "profiles-rep-periods.csv",
        "rep-periods-data.csv",
        "rep-periods-mapping.csv",
        "timeframe-data.csv",
        "year-data.csv",
    )
        change_file(filename) do tcsv
            df_2050 = copy(tcsv.csv)
            df_2050.year .= 2050
            return tcsv.csv = [tcsv.csv; df_2050]
        end
    end

    change_file("assets-data.csv") do tcsv
        return tcsv.csv[end, :active] = "false"
    end

    change_file("flows-data.csv") do tcsv
        return tcsv.csv[end, :active] = "false"
    end
end
