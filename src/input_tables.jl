struct NodeData
    id::Int                     # Node ID
    name::String                # Name of node (geographical?)
    type::String                # Producer/Consumer - maybe an enum?
    active::Bool                # Active or decomissioned
    investable::Bool            # Whether able to invest
    variable_cost::Float32      # kEUR/MWh
    investment_cost::Float32    # kEUR/MW/year
    capacity::Float32           # MW
    initial_capacity::Float32   # MW
    peak_demand::Float32        # MW
end

struct EdgeData
    id::Int                     # Edge ID
    carrier::String             # (Optional?) Energy carrier
    from_node_id::Int           # Node ID
    to_node_id::Int             # Node ID
    active::Bool                # Active or decomissioned
    investable::Bool            # Whether able to invest
    variable_cost::Float32      # kEUR/MWh
    investment_cost::Float32    # kEUR/MW/year
    capacity::Float32           # MW
    initial_capacity::Float32   # MW
end

struct EdgeProfiles
    id::Int                     # Edge ID
    rep_period_id::Int
    time_step::Int
    value::Float32              # p.u.
end

struct NodeProfiles
    id::Int                     # Node ID
    rep_period_id::Int
    time_step::Int
    value::Float32              # p.u.
end

struct RepPeriodData
    id::Int
    weight::Float32
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
