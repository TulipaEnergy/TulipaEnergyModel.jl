export ModelParameters

"""
    ModelParameters(connection)

Structure to hold the model parameters.

Create parameters by reading from the `model_parameters` table in the DuckDB
connection. Default values for `discount_rate` and `power_system_base` come from
the input schema. The `discount_year` is always computed as the minimum between
the provided discount year (table value if present, otherwise schema default) and
the minimum year in `rep_periods_data`.

## Fields

- `discount_rate::Float64`: The model discount rate.
- `discount_year::Int`: The model discount year.
- `power_system_base::Float64`: The power system base in MVA.
- `risk_aversion_weight_lambda::Float64`: Weight reflecting the risk aversion of the objective
- `risk_aversion_confidence_level_alpha::Float64`: Confidence level that system costs will not exceed the VaR_alpha
"""
mutable struct ModelParameters
    discount_rate::Float64
    discount_year::Int32
    power_system_base::Float64
    risk_aversion_weight_lambda::Float64
    risk_aversion_confidence_level_alpha::Float64
end

function _default_discount_year(connection::DuckDB.DB)
    return minimum(
        row.year for row in
        DuckDB.query(connection, "SELECT milestone_year::INT32 AS year FROM rep_periods_data")
    )
end

function _read_model_parameters(connection::DuckDB.DB)
    if !_check_if_table_exists(connection, "model_parameters")
        return Dict{Symbol,Union{Float64,Int32,Int64}}()
    end

    rows = collect(DuckDB.query(
        connection,
        "SELECT *
        FROM model_parameters",
    ))

    if length(rows) > 1
        error("Table `model_parameters` must contain at most one row.")
    end

    if isempty(rows)
        return Dict{Symbol,Union{Float64,Int32,Int64}}()
    end

    table_parameters = Dict{Symbol,Union{Float64,Int32,Int64}}()
    row = only(rows)

    for (key, value) in pairs(row)
        if !ismissing(value)
            table_parameters[key] = value
        end
    end

    return table_parameters
end

function _schema_defaults()
    model_params_schema = schema["model_parameters"]
    defaults = Dict{Symbol,Union{Float64,Int32,Int64}}()
    for (col_name, props) in model_params_schema
        if haskey(props, "default") && !isnothing(props["default"])
            defaults[Symbol(col_name)] = props["default"]
        end
    end
    return defaults
end

function ModelParameters(connection::DuckDB.DB)
    schema_defaults = _schema_defaults()
    table_parameters = _read_model_parameters(connection)

    # Merge: table values override schema defaults
    params = merge(schema_defaults, table_parameters)

    # discount_year is the minimum between the input/default value and the first milestone year.
    milestone_discount_year = _default_discount_year(connection)
    params[:discount_year] =
        min(Int32(get(params, :discount_year, milestone_discount_year)), milestone_discount_year)

    return ModelParameters(
        Float64(params[:discount_rate]),
        Int32(params[:discount_year]),
        Float64(params[:power_system_base]),
        Float64(params[:risk_aversion_weight_lambda]),
        Float64(params[:risk_aversion_confidence_level_alpha]),
    )
end
