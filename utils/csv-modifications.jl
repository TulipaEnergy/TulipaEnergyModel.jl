# This file defines functions to help update CSV files.
using CSV, DataFrames, TulipaEnergyModel

struct TulipaCSV
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
    csv = CSV.read(path, DataFrame; header = 2, types = String)

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
    end
    CSV.write(path, tulipa_csv.csv; append = true, writeheader = true)
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
    @info "Adding column $colname ($unit) at $position"
    insert!(tulipa_csv.units, position, unit)
    insertcols!(tulipa_csv.csv, position, colname => content)
end

function add_column(
    tulipa_csv::TulipaCSV,
    colname,
    content;
    unit = "",
    position = size(tulipa_csv.csv, 2) + 1,
)
    add_column(tulipa_csv, unit, colname, content, position)
end

"""
    unit, content = remove_column(tulipa_csv, colname, position)
    unit, content = remove_column(tulipa_csv, colname)
    unit, content = remove_column(tulipa_csv, position)

Removes column `colname` or column at position `position`.
If both are passed, we check that `colname` happens at `position`.
"""
function remove_column(tulipa_csv::TulipaCSV, colname, position)
    @assert colname == names(tulipa_csv.csv)[position]
    content = tulipa_csv.csv[:, position]

    unit = deleteat!(tulipa_csv.units, position)
    select!(tulipa_csv.csv, Not(colname))

    return unit, content
end

function remove_column(tulipa_csv::TulipaCSV, colname)
    position = columnindex(tulipa_csv.csv, colname)
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
end

input_files_folders = [
    [
        joinpath("test", "inputs", test_input) for
        test_input in ["Norse", "Storage", "Tiny", "Variable Resolution"]
    ]
    joinpath("benchmark", "EU")
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
"""
function apply_to_files_named(f, filename)
    for path in (joinpath(folder, filename) for folder in folders)
        if isfile(path)
            f(path)
        else
            @info "No file $path"
        end
    end
end
