export ModelParameters

"""
    ModelParameters(;key = value, ...)
    ModelParameters(path; ...)
    ModelParameters(connection; ...)
    ModelParameters(connection, path; ...)

Structure to hold the model parameters.
Some values are defined by default and some required explicit definition.

If `path` is passed, it is expected to be a string pointing to a TOML file with
a `key = value` list of parameters. Explicit keyword arguments take precedence.

If `connection` is passed, the default `discount_year` is set to the
minimum of all milestone years. In other words, we check for the table
`year_data` for the column `year` where the column `is_milestone` is true.
Explicit keyword arguments take precedence.

If both are passed, then `path` has preference. Explicit keyword arguments take precedence.

## Parameters

- `discount_rate::Float64 = 0.0`: The model discount rate.
- `discount_year::Int`: The model discount year.
- `power_system_base::Float64 = 100.0`: The power system base in MVA.
"""
Base.@kwdef mutable struct ModelParameters
    discount_rate::Float64 = 0.0
    discount_year::Int # Explicit definition expected
    power_system_base::Float64 = 100.0
end

# Using `@kwdef` defines a default constructor based on keywords

function _read_model_parameters(path)
    if length(path) > 0 && !isfile(path)
        throw(ArgumentError("path `$path` does not contain a file"))
    end

    file_data = length(path) > 0 ? TOML.parsefile(path) : Dict{String,Any}()
    file_parameters = Dict(Symbol(k) => v for (k, v) in file_data)

    return file_parameters
end

function ModelParameters(path::String; kwargs...)
    file_parameters = _read_model_parameters(path)

    return ModelParameters(; file_parameters..., kwargs...)
end

function ModelParameters(connection::DuckDB.DB, path::String = ""; kwargs...)
    discount_year = minimum(
        row.year for
        row in DuckDB.query(connection, "SELECT year FROM year_data WHERE is_milestone = true")
    )
    # This can't be naively refactored to reuse the function above because of
    # the order of preference of the parameters.
    file_parameters = _read_model_parameters(path)

    return ModelParameters(; discount_year, file_parameters..., kwargs...)
end
