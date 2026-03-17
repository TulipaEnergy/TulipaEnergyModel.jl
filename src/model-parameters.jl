export ModelParameters

"""
    ModelParameters(connection)

Structure to hold the model parameters.

Create parameters by reading from the `model_parameters` table in the DuckDB
connection. Default values for `discount_rate` and `power_system_base` come from
the input schema. If `discount_year` is missing, it defaults to the minimum year
in `year_data` where `is_milestone` is true.

## Fields

- `discount_rate::Float64`: The model discount rate.
- `discount_year::Int`: The model discount year.
- `power_system_base::Float64`: The power system base in MVA.
- `risk_aversion_weight_lambda::Float64`: Weight reflecting the risk aversion of the objective
- `risk_aversion_confidence_level_alpha::Float64`: Confidence level that system costs will not exceed the VaR_alpha
"""
mutable struct ModelParameters
    discount_rate::Float64
    discount_year::Int
    power_system_base::Float64
    risk_aversion_weight_lambda::Float64
    risk_aversion_confidence_level_alpha::Float64
end

function _default_discount_year(connection::DuckDB.DB)
    return minimum(
        row.year for
        row in DuckDB.query(connection, "SELECT year FROM year_data WHERE is_milestone = true")
    )
end

function _read_model_parameters(connection::DuckDB.DB)
    if !_check_if_table_exists(connection, "model_parameters")
        return Dict{Symbol,Any}()
    end

    rows = collect(
        DuckDB.query(
            connection,
            "SELECT discount_rate, discount_year, power_system_base FROM model_parameters",
        ),
    )

    if length(rows) > 1
        error("Table `model_parameters` must contain at most one row.")
    end

    if isempty(rows)
        return Dict{Symbol,Any}()
    end

    table_parameters = Dict{Symbol,Any}()
    row = only(rows)

    if !ismissing(row.discount_rate)
        table_parameters[:discount_rate] = row.discount_rate
    end
    if !ismissing(row.discount_year)
        table_parameters[:discount_year] = row.discount_year
    end
    if !ismissing(row.power_system_base)
        table_parameters[:power_system_base] = row.power_system_base
    end

    return table_parameters
end

function _schema_defaults()
    model_params_schema = schema["model_parameters"]
    defaults = Dict{Symbol,Any}()
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

    # Compute discount_year default if still missing
    if !haskey(params, :discount_year)
        params[:discount_year] = _default_discount_year(connection)
    end

    return ModelParameters(
        Float64(params[:discount_rate]),
        Int(params[:discount_year]),
        Float64(params[:power_system_base]),
        Float64(params[:risk_aversion_weight_lambda]),
        Float64(params[:risk_aversion_confidence_level_alpha]),
    )
end
