# This file defines functions to help update CSV files.
using CSV, DataFrames, TulipaEnergyModel

mutable struct TulipaCSV
    units::Vector{String}
    csv::DataFrame
end

"""
    TulipaCSV(path)

Creates a structure to hold the Tulipa CSV, including the unit line.

The functions [`add_column`](@ref), [`remove_column`](@ref), and [`write_tulipa_csv`](@ref) can
then be used to process the CSV and save it back.
"""
function TulipaCSV(path)
    if !isfile(path)
        error("$path is not a file")
    end

    units = split(readline(path), ",")
    csv = CSV.read(path, DataFrame; header = 1, types = String)

    if size(csv) == (0, 0)
        units = String[]
    end

    @assert length(units) == size(csv, 2)

    return TulipaCSV(units, csv)
end

"""
    write_tulipa_csv(tulipa_csv, path)

Saves the CSV file at `path`.

!!! warning
    This will overwrite the `path`.
"""
function write_tulipa_csv(tulipa_csv::TulipaCSV, path)
    open(path, "w") do io
        println(io, join(tulipa_csv.units, ","))
        return
    end
    CSV.write(path, tulipa_csv.csv; append = true, writeheader = true)
    return
end

"""
    add_column(tulipa_csv, colname, content; unit="", position=<after last>)
    add_column(tulipa_csv, unit, colname, content, position)

Adds a column `colname => content` to the CSV file.
If `unit` is not specified, `""` is used.
If `position` is not specified, the column is added to the rightmost place.

The `content` can be a value or a vector of proper size.
"""
function add_column(tulipa_csv::TulipaCSV, unit::String, colname, content, position::Int)
    @debug "Adding column $colname ($unit) at $position"
    insert!(tulipa_csv.units, position, unit)
    insertcols!(tulipa_csv.csv, position, Symbol(colname) => content)
    return
end

function add_column(
    tulipa_csv::TulipaCSV,
    colname,
    content;
    unit = "",
    position = size(tulipa_csv.csv, 2) + 1,
)
    add_column(tulipa_csv, unit, colname, content, position)
    return
end

"""
    unit, content = get_column(tulipa_csv, colname)
    unit, content = get_column(tulipa_csv, position)

Returns column `colname` or column at position `position`.
"""
function get_column(tulipa_csv::TulipaCSV, position::Int)
    unit = tulipa_csv.units[position]
    content = tulipa_csv.csv[:, position]

    return unit, content
end

function get_column(tulipa_csv::TulipaCSV, colname)
    position = columnindex(tulipa_csv.csv, Symbol(colname))
    return get_column(tulipa_csv, position)
end

"""
    unit, content = remove_column(tulipa_csv, colname, position)
    unit, content = remove_column(tulipa_csv, colname)
    unit, content = remove_column(tulipa_csv, position)

Removes column `colname` or column at position `position`.
If both are passed, we check that `colname` happens at `position`.
"""
function remove_column(tulipa_csv::TulipaCSV, colname, position)
    @assert string(colname) == names(tulipa_csv.csv)[position]
    content = tulipa_csv.csv[:, position]

    unit = popat!(tulipa_csv.units, position)
    select!(tulipa_csv.csv, Not(Symbol(colname)))

    return unit, content
end

function remove_column(tulipa_csv::TulipaCSV, colname)
    position = columnindex(tulipa_csv.csv, Symbol(colname))
    return remove_column(tulipa_csv, colname, position)
end

function remove_column(tulipa_csv::TulipaCSV, position::Int)
    colname = names(tulipa_csv.csv)[position]
    return remove_column(tulipa_csv, colname, position)
end

"""
    change_file(f, path)
    change_file(path) do tulipa_csv
        # Do stuff to tulipa_csv
    end

This functions creates a TulipaCSV, applies `f` to it, and then writes it back using `write_tulipa_csv`.
It's supposed to be used with the `do` syntax:

```julia
change_file("test/inputs/Norse/assets-data.csv") do tcsv
    add_column(tcsv, "year", 2030; position=4)
end
```
"""
function change_file(f, path)
    tulipa_csv = TulipaCSV(path)
    f(tulipa_csv)
    write_tulipa_csv(tulipa_csv, path)
    return
end

input_files_folders = [
    [
        joinpath(@__DIR__, "..", "test", "inputs", test_input) for test_input in [
            "Multi-year Investments",
            "Norse",
            "Storage",
            "Tiny",
            "UC-ramping",
            "Variable Resolution",
        ]
    ]
    joinpath(@__DIR__, "..", "benchmark", "EU")
]

"""
    apply_to_files_named(f, filename)
    apply_to_files_named(filename) do path
        # Do stuff to path
    end

Looks in the input folders defined in `input_files_folders` for a file named `filename` and apply
the function `f` to it.
Skips paths that don't exist.

This is supposed to be used with the `do` syntax:

```julia
apply_to_files_named("assets-data.csv") do path
    change_file(path) do tcsv
        add_column(tcsv, "year", 2030; position=4)
    end
end
```

## Keyword arguments

- `include_missing (default = false)`: If `true`, applies the function even if `isfile(path)` is `false`.

"""
function apply_to_files_named(f, filename; include_missing = false)
    for path in (joinpath(folder, filename) for folder in input_files_folders)
        if isfile(path) || include_missing
            @debug "Applying to file $path"
            f(path)
        else
            @warn "No file $path"
        end
    end
end

"""
    delete_header_in_csvs(path)

Searches for all CSV files in the given `path` and its subfolders, deletes the header row of each file, and saves the file.
"""
function delete_header_in_csvs(path)
    for (root, _, files) in walkdir(path)
        for file in files
            if endswith(file, ".csv")
                try
                    file_path = joinpath(root, file)
                    df = CSV.read(file_path, DataFrame; header = 2)
                    CSV.write(file_path, df; append = false)
                    println("Processed: $file_path")
                catch e
                    println("Error processing $file_path: $e")
                end
            end
        end
    end
end
