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
function write_tulipa_csv(tulipa_csv, path)
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
function add_column(tulipa_csv, unit::String, colname, content, position::Int)
    insert!(tulipa_csv.units, position, unit)
    insertcols!(tulipa_csv.csv, position, colname => content)
end

function add_column(tulipa_csv, colname, content; unit = "", position = size(tulipa_csv.csv, 2) + 1)
    add_column(tulipa_csv, unit, colname, content, position)
end

"""
    remove_column(tulipa_csv, colname)
    remove_column(tulipa_csv, position)

Removes column `colname` or column at position `position`.
"""
function remove_column(tulipa_csv, colname)
    position = columnindex(tulipa_csv.csv, colname)
    @assert idx > 0
    deleteat!(tulipa_csv.units, position)
    select!(tulipa_csv.csv, Not(colname))
end

function remove_column(tulipa_csv, position::Int)
    colname = names(tulipa_csv.csv)[position]
    deleteat!(tulipa_csv.units, position)
    select!(tulipa_csv.csv, Not(colname))
end
