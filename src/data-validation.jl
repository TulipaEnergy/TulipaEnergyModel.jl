export DataValidationException

# TODO: Remove after https://github.com/TulipaEnergy/TulipaIO.jl/pull/105 is released
TulipaIO.FmtSQL.fmt_quote(::Nothing) = "NULL"

"""
    DataValidationException

Exception related to data validation of the Tulipa Energy Model input data.
"""
mutable struct DataValidationException <: Exception
    error_messages::Vector{String}
end

function Base.showerror(io::IO, ex::DataValidationException)
    println(io, "DataValidationException: The following issues were found in the data:")
    for error_message in ex.error_messages
        println(io, "- " * error_message)
    end
end

"""
    validate_data!(connection)

Raises an error if the data is not valid.
"""
function validate_data!(connection)
    error_messages = String[]

    for (log_msg, validation_function, fail_fast) in (
        ("has all tables and columns", _validate_has_all_tables_and_columns!, true),
        ("no duplicate rows", _validate_no_duplicate_rows!, false),
        ("valid schema's oneOf constraints", _validate_schema_one_of_constraints!, false),
        (
            "only transport flows are investable",
            _validate_only_transport_flows_are_investable!,
            false,
        ),
        ("group consistency between tables", _validate_group_consistency!, false),
        (
            "data consistency for simple investment",
            _validate_simple_method_data_consistency!,
            false,
        ),
        (
            "investable storage assets using binary method should have investment limit > 0",
            _validate_use_binary_storage_method_has_investment_limit!,
            false,
        ),
    )
        @timeit to "$log_msg" append!(error_messages, validation_function(connection))
        if fail_fast && length(error_messages) > 0
            break
        end
    end

    if length(error_messages) > 0
        throw(DataValidationException(error_messages))
    end

    return
end

function _validate_has_all_tables_and_columns!(connection)
    error_messages = String[]
    for (table_name, table) in TulipaEnergyModel.schema_per_table_name
        columns_from_connection = [
            row.column_name for row in DuckDB.query(
                connection,
                "SELECT column_name FROM duckdb_columns() WHERE table_name = '$table_name'",
            )
        ]
        if length(columns_from_connection) == 0
            # Just to make sure that this is not a random case with no columns but the table exists
            count_tables = get_single_element_from_query_and_ensure_its_only_one(
                DuckDB.query(
                    connection,
                    "SELECT COUNT(table_name) as count FROM duckdb_tables() WHERE table_name = '$table_name'",
                ),
            )
            has_table = count_tables == 1
            if !has_table
                push!(error_messages, "Table '$table_name' expected but not found")
                continue
            end
        end

        for (column, _) in table
            if !(column in columns_from_connection)
                push!(error_messages, "Column '$column' is missing from table '$table_name'")
            end
        end
    end

    return error_messages
end

function _validate_no_duplicate_rows!(connection)
    # It should be possible to add a primary key to the tables below to avoid this validation.
    # However, where to add this, and how to ensure it was added is not clear.
    duplicates = String[]
    for (table, primary_keys) in (
        ("asset", (:asset,)),
        ("asset_both", (:asset, :milestone_year, :commission_year)),
        ("asset_commission", (:asset, :commission_year)),
        ("asset_milestone", (:asset, :milestone_year)),
        ("assets_profiles", (:asset, :commission_year, :profile_type)),
        ("assets_rep_periods_partitions", (:asset, :year, :rep_period)),
        ("assets_timeframe_partitions", (:asset, :year)),
        ("assets_timeframe_profiles", (:asset, :commission_year, :profile_type)),
        ("flow", (:from_asset, :to_asset)),
        ("flow_both", (:from_asset, :to_asset, :milestone_year, :commission_year)),
        ("flow_commission", (:from_asset, :to_asset, :commission_year)),
        ("flow_milestone", (:from_asset, :to_asset, :milestone_year)),
        ("flows_profiles", (:from_asset, :to_asset, :year, :profile_type)),
        ("flows_rep_periods_partitions", (:from_asset, :to_asset, :year, :rep_period)),
        ("group_asset", (:name, :milestone_year)),
        ("profiles_rep_periods", (:profile_name, :year, :rep_period, :timestep)),
        ("profiles_timeframe", (:profile_name, :year, :period)),
        ("rep_periods_data", (:year, :rep_period)),
        ("rep_periods_mapping", (:year, :period, :rep_period)),
        ("timeframe_data", (:year, :period)),
        ("year_data", (:year,)),
    )
        append!(duplicates, _validate_no_duplicate_rows!(connection, table, primary_keys))
    end

    return duplicates
end

function _validate_no_duplicate_rows!(connection, table, primary_keys)
    keys_as_string = join(primary_keys, ", ")
    duplicates = String[]
    for row in DuckDB.query(
        connection,
        "SELECT $keys_as_string, COUNT(*) FROM $table GROUP BY $keys_as_string HAVING COUNT(*) > 1",
    )
        values = join(["$k=$(row[k])" for k in primary_keys], ", ")
        push!(duplicates, "Table $table has duplicate entries for ($values)")
    end

    return duplicates
end

function _validate_schema_one_of_constraints!(connection)
    error_messages = String[]
    for (table_name, table) in TulipaEnergyModel.schema, (col, attr) in table
        if haskey(attr, "constraints") && haskey(attr["constraints"], "oneOf")
            valid_types = attr["constraints"]["oneOf"]
            valid_types_string = join([TulipaIO.FmtSQL.fmt_quote(s) for s in valid_types], ", ")
            for row in DuckDB.query(
                connection,
                "SELECT $col FROM $table_name WHERE $col NOT IN ($valid_types_string)",
            )
                push!(
                    error_messages,
                    "Table '$table_name' has bad value for column '$col': '$(row[1])'",
                )
            end
        end
    end

    return error_messages
end

function _validate_only_transport_flows_are_investable!(connection)
    error_messages = String[]

    for row in DuckDB.query(
        connection,
        "SELECT flow.from_asset, flow.to_asset,
        FROM flow
        LEFT JOIN flow_milestone
            ON flow.from_asset = flow_milestone.from_asset
            AND flow.to_asset = flow_milestone.to_asset
        WHERE flow.is_transport = FALSE
            AND flow_milestone.investable
        ",
    )
        push!(
            error_messages,
            "Flow ('$(row.from_asset)', '$(row.to_asset)') is investable but is not a transport flow",
        )
    end

    return error_messages
end

function _validate_foreign_key!(
    connection,
    table_name,
    column::Symbol,
    foreign_table_name,
    foreign_key::Symbol;
    allow_missing = true,
)
    error_messages = String[]
    query = "SELECT main.$column
        FROM $table_name AS main
        ANTI JOIN $foreign_table_name AS other
            ON main.$column = other.$foreign_key "

    if allow_missing
        query *= "WHERE main.$column IS NOT NULL"
    end

    for row in DuckDB.query(connection, query)
        push!(
            error_messages,
            "Table '$table_name' column '$column' has invalid value '$(row[1])'. Valid values should be among column '$foreign_key' of '$foreign_table_name'",
        )
    end

    return error_messages
end

function _validate_group_consistency!(connection)
    error_messages = String[]

    # First, check if the values are valid
    append!(
        error_messages,
        _validate_foreign_key!(connection, "asset", :group, "group_asset", :name),
    )

    # Second, these that the values are used
    for row in DuckDB.query(
        connection,
        "FROM (
            SELECT group_asset.name, COUNT(asset.group) AS group_count
            FROM group_asset
            LEFT JOIN asset
                ON asset.group = group_asset.name
            GROUP BY group_asset.name
        ) WHERE group_count = 0",
    )
        push!(
            error_messages,
            "Group '$(row.name)' in 'group_asset' has no members in 'asset', column 'group'",
        )
    end

    return error_messages
end

function _validate_simple_method_data_consistency!(connection)
    error_messages = String[]
    _validate_simple_method_has_only_matching_years!(error_messages, connection)
    _validate_simple_method_all_milestone_years_are_covered!(error_messages, connection)

    return error_messages
end

function _validate_simple_method_has_only_matching_years!(error_messages, connection)
    # Validate that the data should have milestone year = commission year
    # Error otherwise and point out the unmatched rows
    # - For assets
    for row in DuckDB.query(
        connection,
        "SELECT asset.asset, asset_both.milestone_year, asset_both.commission_year, asset.investment_method
        FROM asset_both
        LEFT JOIN asset
            ON asset.asset = asset_both.asset
        WHERE asset_both.milestone_year != asset_both.commission_year
            AND asset.investment_method in ('simple', 'none')
        ",
    )
        push!(
            error_messages,
            "Unexpected (asset='$(row.asset)', milestone_year=$(row.milestone_year), commission_year=$(row.commission_year)) in 'asset_both' for an asset='$(row.asset)' with investment_method='$(row.investment_method)'. For this investment method, rows in 'asset_both' should have milestone_year=commission_year.",
        )
    end

    # - For flows
    for row in DuckDB.query(
        connection,
        "SELECT flow.from_asset, flow.to_asset, flow_both.milestone_year, flow_both.commission_year,
        FROM flow
        LEFT JOIN flow_both
            ON flow.is_transport
            AND flow.from_asset = flow_both.from_asset
            AND flow.to_asset = flow_both.to_asset
        WHERE flow_both.milestone_year != flow_both.commission_year
        ",
    )
        push!(
            error_messages,
            "Unexpected (from_asset='$(row.from_asset)', to_asset='$(row.to_asset)', milestone_year=$(row.milestone_year), commission_year=$(row.commission_year)) in 'flow_both' for an flow=('$(row.from_asset)', '$(row.to_asset)') with default investment_method='simple/none'. For this investment method, rows in 'flow_both' should have milestone_year=commission_year.",
        )
    end

    return error_messages
end

function _validate_simple_method_all_milestone_years_are_covered!(error_messages, connection)
    # Validate that the data contains all milestone years where milestone year = commission year
    # Error otherwise and point out the missing milestone years
    # - For assets
    for row in DuckDB.query(
        connection,
        "SELECT asset_milestone.asset, asset_milestone.milestone_year, asset.investment_method
        FROM asset_milestone
        LEFT JOIN asset
            ON asset_milestone.asset = asset.asset
        LEFT JOIN asset_both
            ON asset_milestone.asset = asset_both.asset
            AND asset_milestone.milestone_year = asset_both.milestone_year
            AND asset_milestone.milestone_year = asset_both.commission_year
        WHERE asset_both.commission_year IS NULL
            AND asset.investment_method in ('simple', 'none')
        ",
    )
        push!(
            error_messages,
            "Missing information in 'asset_both': Asset '$(row.asset)' has investment_method='$(row.investment_method)' but there is no row (asset='$(row.asset)', milestone_year=$(row.milestone_year), commission_year=$(row.milestone_year)). For this investment method, rows in 'asset_both' should have milestone_year=commission_year.",
        )
    end

    # - For flows
    for row in DuckDB.query(
        connection,
        "SELECT flow_milestone.from_asset, flow_milestone.to_asset, flow_milestone.milestone_year
        FROM flow_milestone
        LEFT JOIN flow
            ON flow_milestone.from_asset = flow.from_asset
            AND flow_milestone.to_asset = flow.to_asset
        LEFT JOIN flow_both
            ON flow_milestone.from_asset = flow_both.from_asset
            AND flow_milestone.to_asset = flow_both.to_asset
            AND flow_milestone.milestone_year = flow_both.milestone_year
            AND flow_milestone.milestone_year = flow_both.commission_year
        WHERE flow_both.commission_year IS NULL
            AND flow.is_transport
        ",
    )
        push!(
            error_messages,
            "Missing information in 'flow_both': Flow ('$(row.from_asset)', '$(row.to_asset)') currently only has investment_method='simple/none' but there is no row (from_asset='$(row.from_asset)', to_asset='$(row.to_asset)', milestone_year=$(row.milestone_year), commission_year=$(row.milestone_year)). For this investment method, rows in 'flow_both' should have milestone_year=commission_year.",
        )
    end

    return error_messages
end

function _validate_use_binary_storage_method_has_investment_limit!(connection)
    error_messages = String[]

    for row in DuckDB.query(
        connection,
        "SELECT asset.asset, asset.use_binary_storage_method, asset_milestone.milestone_year, asset_commission.commission_year, asset_commission.investment_limit
        FROM asset_milestone
        LEFT JOIN asset_commission
            ON asset_milestone.asset = asset_commission.asset
            AND asset_milestone.milestone_year = asset_commission.commission_year
        LEFT JOIN asset
            ON asset_milestone.asset = asset.asset
        WHERE asset.type = 'storage'
            AND asset_milestone.investable
            AND asset.use_binary_storage_method IS NOT NULL
            AND (asset_commission.investment_limit IS NULL OR asset_commission.investment_limit <= 0)
        ",
    )
        push!(
            error_messages,
            "Incorrect investment_limit = $(row.investment_limit) for investable storage asset '$(row.asset)' with use_binary_storage_method = '$(row.use_binary_storage_method)' for year $(row.milestone_year). The investment_limit at year $(row.commission_year) should be greater than 0 in 'asset_commission'.",
        )
    end

    return error_messages
end
