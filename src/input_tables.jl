struct AssetData
    id::Int                     # Asset ID
    name::String                # Name of Asset (geographical?)
    type::String                # Producer/Consumer - maybe an enum?
    active::Bool                # Active or decomissioned
    investable::Bool            # Whether able to invest
    variable_cost::Float64      # kEUR/MWh
    investment_cost::Float64    # kEUR/MW/year
    capacity::Float64           # MW
    initial_capacity::Float64   # MW
    peak_demand::Float64        # MW
end

struct FlowData
    id::Int                     # Flow ID
    carrier::String             # (Optional?) Energy carrier
    from_asset_id::Int           # Asset ID
    to_asset_id::Int             # Asset ID
    active::Bool                # Active or decomissioned
    investable::Bool            # Whether able to invest
    variable_cost::Float64      # kEUR/MWh
    investment_cost::Float64    # kEUR/MW/year
    capacity::Float64           # MW
    initial_capacity::Float64   # MW
end

struct FlowProfiles
    id::Int                     # Flow ID
    rep_period_id::Int
    time_step::Int
    value::Float64              # p.u.
end

struct AssetProfiles
    id::Int                     # Asset ID
    rep_period_id::Int
    time_step::Int
    value::Float64              # p.u.
end

struct RepPeriodData
    id::Int
    weight::Float64
end

function validate_df(df::DataFrame, schema::DataType; fname::String = "", silent = false)
    df_t = describe(df) # relevant columns: variable::Symbol, eltype::DataType
    cols = [i for i in fieldnames(schema)]
    col_types = [i for i in fieldtypes(schema)]

    col_error = collect(Iterators.filter(x -> !(x in df_t[!, :variable]), cols))

    cols_t2 = collect(
        Iterators.map(
            ((col, expect),) -> (
                col,
                expect,
                first(collect(Iterators.filter(r -> r[:variable] == col, eachrow(df_t))))[:eltype],
            ),
            Iterators.filter(
                ((col, _),) -> !(col in col_error),
                Iterators.zip(cols, col_types),
            ),
        ),
    )

    col_type_err = collect(
        Iterators.filter(
            ((_, expect, col_t),) -> if (supertype(expect) == supertype(col_t))
                false
            else
                ((promote_type(expect, col_t) == Any) ? true : false)
            end,
            cols_t2,
        ),
    )

    if !silent
        msg = length(col_error) > 0 ? "\n [1] missing columns: $(col_error)" : ""
        if length(col_type_err) > 0
            msg *= length(msg) > 0 ? "\n [2] " : " [1] "
            msg *= "incompatible column types:"
            msg *= join(
                Iterators.map(
                    ((col, expect, col_t),) ->
                        "\n     - $col::$col_t (expected: $expect)",
                    col_type_err,
                ),
            )
        end
        if length(msg) > 0
            error("$fname failed validation", msg)
        end
    end
    return (col_error, col_type_err)
end
