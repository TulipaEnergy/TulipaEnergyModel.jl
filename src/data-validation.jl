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
        (
            "flow_both only contain transport flows",
            _validate_flow_both_table_does_not_contain_non_transport_flows!,
            false,
        ),
        ("group consistency between tables", _validate_group_consistency!, false),
        (
            "stochastic scenario probabilities sum to 1",
            _validate_stochastic_scenario_probabilities_sum_to_one!,
            false,
        ),
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
        ("check DC OPF data", _validate_dc_opf_data!, false),
        (
            "consistency between asset types and investment methods",
            _validate_certain_asset_types_can_only_have_none_investment_methods!,
            false,
        ),
        (
            "consistency between asset_commission and asset_both",
            _validate_asset_commission_and_asset_both_consistency!,
            false,
        ),
        (
            "consistency between flow_commission and asset_both",
            _validate_flow_commission_and_asset_both_consistency!,
            false,
        ),
        (
            "consumer unit commitment used as bids has right data",
            _validate_bid_related_data!,
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
        ("assets_timeframe_profiles", (:asset, :year, :profile_type)),
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
        ("rep_periods_mapping", (:year, :scenario, :period, :rep_period)),
        ("stochastic_scenario", (:scenario,)),
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
            valid_types_string =
                join([TulipaIO.FmtSQL.fmt_quote(s) for s in valid_types if !isnothing(s)], ", ")

            query_str = "SELECT $col FROM $table_name WHERE $col NOT IN ($valid_types_string)"
            # The query above alone does not catch NULL. So if NULLs are not in the list, improve the query
            if !(nothing in valid_types)
                query_str *= " OR $col IS NULL"
            end
            for row in DuckDB.query(connection, query_str)
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

function _validate_flow_both_table_does_not_contain_non_transport_flows!(connection)
    # In principle, we should also check all transport flows are covered.
    # But that is tested elsewhere, i.e., in _validate_simple_method_data_consistency!()
    error_messages = String[]

    for row in DuckDB.query(
        connection,
        "SELECT flow_both.from_asset, flow_both.to_asset, flow_both.milestone_year, flow_both.commission_year
        FROM flow_both
        LEFT JOIN flow
            ON flow.from_asset = flow_both.from_asset
            AND flow.to_asset = flow_both.to_asset
        WHERE flow.is_transport = FALSE
        ",
    )
        push!(
            error_messages,
            "Unexpected (flow=('$(row.from_asset)', '$(row.to_asset)'), milestone_year=$(row.milestone_year), commission_year=$(row.commission_year)) in 'flow_both' because 'flow_both' should only contain transport flows.",
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
        _validate_foreign_key!(connection, "asset", :investment_group, "group_asset", :name),
    )

    # Second, these that the values are used
    for row in DuckDB.query(
        connection,
        "FROM (
            SELECT group_asset.name, COUNT(asset.investment_group) AS group_count
            FROM group_asset
            LEFT JOIN asset
                ON asset.investment_group = group_asset.name
            GROUP BY group_asset.name
        ) WHERE group_count = 0",
    )
        push!(
            error_messages,
            "Group '$(row.name)' in 'group_asset' has no members in 'asset', column 'investment_group'",
        )
    end

    return error_messages
end

function _validate_stochastic_scenario_probabilities_sum_to_one!(connection; tolerance = 1e-3)
    error_messages = String[]

    # Check if table is not empty
    row_count_query =
        DuckDB.query(connection, "SELECT COUNT(*) as row_count FROM stochastic_scenario")
    row_count = get_single_element_from_query_and_ensure_its_only_one(row_count_query)
    if row_count == 0
        return error_messages
    end

    # Check if sum of probabilities is equal to 1
    sum_query = DuckDB.query(
        connection,
        "SELECT SUM(probability) as total_probability FROM stochastic_scenario",
    )
    total_probability = get_single_element_from_query_and_ensure_its_only_one(sum_query)
    if abs(total_probability - 1.0) > tolerance
        push!(
            error_messages,
            "Sum of probabilities in 'stochastic_scenario' table is $(total_probability), but should be approximately 1.0 (tolerance: $(tolerance))",
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

function _validate_dc_opf_data!(connection)
    error_messages = String[]
    _validate_reactance_must_be_greater_than_zero!(error_messages, connection)
    _validate_dc_opf_only_apply_to_non_investable_transport_flows!(error_messages, connection)

    return error_messages
end

function _validate_reactance_must_be_greater_than_zero!(error_messages, connection)
    for row in DuckDB.query(
        connection,
        "SELECT flow_milestone.from_asset, flow_milestone.to_asset, flow_milestone.milestone_year, flow_milestone.reactance
        FROM flow_milestone
        WHERE flow_milestone.reactance <= 0
        ",
    )
        push!(
            error_messages,
            "Incorrect reactance = $(row.reactance) for flow ('$(row.from_asset)', '$(row.to_asset)') for year $(row.milestone_year) in 'flow_milestone'. The reactance should be greater than 0.",
        )
    end

    return error_messages
end

function _validate_dc_opf_only_apply_to_non_investable_transport_flows!(error_messages, connection)
    for row in DuckDB.query(
        connection,
        "SELECT flow_milestone.from_asset, flow_milestone.to_asset, flow_milestone.milestone_year
        FROM flow_milestone
        LEFT JOIN flow
            ON flow_milestone.from_asset = flow.from_asset
            AND flow_milestone.to_asset = flow.to_asset
        WHERE flow_milestone.dc_opf
            AND (NOT flow.is_transport OR flow_milestone.investable)
        ",
    )
        push!(
            error_messages,
            "Incorrect use of dc-opf method for flow ('$(row.from_asset)', '$(row.to_asset)') for year $(row.milestone_year) in 'flow_milestone'. This method can only be applied to non-investable transport flows.",
        )
    end

    return error_messages
end

function _validate_certain_asset_types_can_only_have_none_investment_methods!(connection)
    error_messages = String[]

    for row in DuckDB.query(
        connection,
        "SELECT asset.asset, asset.investment_method, asset.type
        FROM asset
        WHERE asset.investment_method != 'none'
            AND asset.type in ('hub', 'consumer')
        ",
    )
        push!(
            error_messages,
            "Incorrect use of investment method '$(row.investment_method)' for asset '$(row.asset)' of type '$(row.type)'. Hub and consumer assets can only have 'none' investment method.",
        )
    end

    return error_messages
end

function _validate_asset_commission_and_asset_both_consistency!(connection)
    error_messages = String[]
    for row in DuckDB.query(
        connection,
        "SELECT asset_both.asset, asset_both.milestone_year, asset_both.commission_year
        FROM asset_both
        LEFT JOIN asset_commission
            ON asset_both.asset = asset_commission.asset
            AND asset_both.commission_year = asset_commission.commission_year
        WHERE asset_commission.commission_year IS NULL
        ",
    )
        push!(
            error_messages,
            "Missing commission_year = $(row.commission_year) for asset '$(row.asset)' in 'asset_commission' given (asset '$(row.asset)', milestone_year = $(row.milestone_year), commission_year = $(row.commission_year)) in 'asset_both'. The commission_year should match the one in 'asset_both'.",
        )
    end

    for row in DuckDB.query(
        connection,
        "SELECT asset_commission.asset, asset_commission.commission_year
        FROM asset_commission
        LEFT JOIN asset_both
            ON asset_commission.asset = asset_both.asset
            AND asset_commission.commission_year = asset_both.commission_year
        WHERE asset_both.commission_year IS NULL
        ",
    )
        push!(
            error_messages,
            "Unexpected commission_year = $(row.commission_year) for asset '$(row.asset)' in 'asset_commission'. The commission_year should match the one in 'asset_both'.",
        )
    end

    return error_messages
end

function _validate_flow_commission_and_asset_both_consistency!(connection)
    error_messages = String[]
    for row in DuckDB.query(
        connection,
        "SELECT asset_both.asset, asset_both.milestone_year, asset_both.commission_year
        FROM asset_both
        LEFT JOIN flow_commission
            ON asset_both.asset = flow_commission.from_asset
            AND asset_both.commission_year = flow_commission.commission_year
        LEFT JOIN asset
            ON asset_both.asset = asset.asset
        WHERE asset.investment_method = 'semi-compact'
            AND flow_commission.commission_year IS NULL
        ",
    )
        push!(
            error_messages,
            "Missing commission_year = $(row.commission_year) for the outgoing flow of asset '$(row.asset)' in 'flow_commission' given (asset '$(row.asset)', milestone_year = $(row.milestone_year), commission_year = $(row.commission_year)) in 'asset_both'. The commission_year should match the one in 'asset_both'.",
        )
    end

    for row in DuckDB.query(
        connection,
        "SELECT flow_commission.from_asset, flow_commission.commission_year
        FROM flow_commission
        LEFT JOIN asset_both
            ON flow_commission.from_asset = asset_both.asset
            AND flow_commission.commission_year = asset_both.commission_year
        LEFT JOIN asset
            ON flow_commission.from_asset = asset.asset
        WHERE asset.investment_method = 'semi-compact'
            AND asset_both.commission_year IS NULL
        ",
    )
        push!(
            error_messages,
            "Unexpected commission_year = $(row.commission_year) for the outgoing flow of asset '$(row.from_asset)' in 'flow_commission'. The commission_year should match the one in 'asset_both'.",
        )
    end

    return error_messages
end

function _validate_bid_related_data!(connection)
    error_messages = String[]

    #= Testing strategy:
    # - For a given `asset`, there are necessary and sufficient conditions that
    #   imply that this asset represents a bid.
    # - We loop over each sufficient condition and get all assets that satisfy that condition
    # - For each of these assets, we verify the necessary conditions.
    =#

    """
        get_bid_data(connection)

    Gets all relevant data related to an asset in dictionary format. Used to
    verify the necessary conditions for a bid to be defined correctly:

    - asset.type = 'consumer'
    - asset.unit_commitment = true
    - asset.unit_commitment_integer = true
    - asset.unit_commitment_method = 'basic'
    - asset.consumer_balance_sense = '=='
    - asset.capacity = 1.0
    - asset_both.initial_units = 1.0
    - assets_rep_periods_partitions.specification = 'uniform' and partition = num_timesteps of rep_period
    - assets_profiles.type = 'demand' (i.e., there is a 'demand' profile for this asset)
    - there is a loop flow.from_asset = flow.to_asset = asset.asset (i.e., the asset has a loop) (by itself is already prohibitive)
    - there is a flow from some consumer to this asset, with operational_cost < 0
    - there is a single rep_period
    - there is a single year
    """
    function get_bid_data(connection)
        has_demand_profile_str = "false"

        if _check_if_table_exists(connection, "assets_profiles")
            has_demand_profile_str = """
            EXISTS (
                FROM assets_profiles
                WHERE assets_profiles.asset = asset.asset
                    AND assets_profiles.profile_type = 'demand'
            )"""
        end

        has_wrong_asset_partition_str = "true" # partition needs to be defined because default is hourly
        if _check_if_table_exists(connection, "assets_rep_periods_partitions")
            has_wrong_asset_partition_str = """
            EXISTS (
                FROM assets_rep_periods_partitions AS partitions
                LEFT JOIN rep_periods_data AS rpdata
                    ON partitions.year = rpdata.year AND partitions.rep_period = rpdata.rep_period
                WHERE partitions.asset = asset.asset
                    AND (
                        partitions.specification != 'uniform'
                        OR partitions.partition != rpdata.num_timesteps
                    )
            )"""
        end

        query = """
        SELECT
            asset.asset,
            asset.type,
            asset.unit_commitment,
            asset.unit_commitment_integer,
            asset.unit_commitment_method,
            asset.consumer_balance_sense,
            asset.capacity,
            asset_both.initial_units,
            EXISTS (
                FROM flow
                WHERE flow.from_asset = asset.asset
                    AND flow.to_asset = asset.asset
            ) AS has_loop,
            flow_milestone.from_asset as bid_manager,
            flow_milestone.operational_cost,
            $has_demand_profile_str AS has_demand_profile,
            $has_wrong_asset_partition_str AS has_wrong_asset_partition,
        FROM asset
        LEFT JOIN asset_both
            ON asset.asset = asset_both.asset
        LEFT JOIN flow_milestone
            ON flow_milestone.to_asset = asset.asset
            AND flow_milestone.operational_cost < 0
        """

        return Dict(row.asset => row for row in DuckDB.query(connection, query))
    end

    """
        get_consumers_with_unit_commitment(connection)

    Gets the assets that satisfy the first sufficient condition that implies
    that this asset represents a bid: It has asset.type = 'consumer' and
    asset.unit_commitment is true.
    """
    function get_consumers_with_unit_commitment(connection)
        return Dict(
            row.asset => row for row in DuckDB.query(
                connection,
                """
                SELECT
                    asset, type, unit_commitment, consumer_balance_sense, capacity
                FROM asset
                WHERE asset.type = 'consumer' AND unit_commitment
                """,
            )
        )
    end

    """
        get_assets_with_loop_flows(connection)

    Gets the assets that satisfy the second sufficient condition that implies
    that this asset represents a bid: It has a loop flow.
    """
    function get_assets_with_loop_flows(connection)
        return Dict(
            row.from_asset => row for row in DuckDB.query(
                connection,
                """
                SELECT
                    from_asset, to_asset,
                FROM flow
                WHERE from_asset = to_asset
                """,
            )
        )
    end

    """
        get_assets_with_negative_operational_cost(connection)

    Gets the assets that satisfy the third sufficient condition that implies
    that this asset represents a bid: It has an incoming flow with negative
    operational_cost.
    """
    function get_assets_with_negative_operational_cost(connection)
        return Dict(
            row.to_asset => row for row in DuckDB.query(
                connection,
                """
                SELECT
                    from_asset, to_asset, operational_cost
                FROM flow_milestone
                WHERE operational_cost < 0
                """,
            )
        )
    end

    bid_data = get_bid_data(connection)
    consumers_with_unit_commitment = get_consumers_with_unit_commitment(connection)
    assets_with_loop_flows = get_assets_with_loop_flows(connection)
    assets_with_negative_operational_cost = get_assets_with_negative_operational_cost(connection)
    num_years = get_single_element_from_query_and_ensure_its_only_one(
        connection,
        "SELECT COUNT(*) FROM year_data",
    )
    num_rep_periods = get_single_element_from_query_and_ensure_its_only_one(
        connection,
        "SELECT COUNT(*) FROM rep_periods_data",
    )

    for (justification, condition_dict) in (
        ("consumer with unit commitment", consumers_with_unit_commitment),
        ("a loop flow", assets_with_loop_flows),
        ("an incoming flow with negative operational_cost", assets_with_negative_operational_cost),
    )
        if length(condition_dict) > 0
            if num_years != 1
                push!(
                    error_messages,
                    "Problem is assumed to have bids because at least 1 asset has $justification, so it should have only 1 year, but found $num_years",
                )
            end
            if num_rep_periods != 1
                push!(
                    error_messages,
                    "Problem is assumed to have bids because at least 1 asset has $justification, so it should have only 1 representative period, but found $num_rep_periods",
                )
            end
        end
        for asset in keys(condition_dict)
            prefix_msg = "Asset '$asset' is a bid because it has $justification, so it should"
            _,
            type,
            unit_commitment,
            unit_commitment_integer,
            unit_commitment_method,
            consumer_balance_sense,
            capacity,
            initial_units,
            has_loop,
            _,
            operational_cost,
            has_demand_profile,
            has_wrong_asset_partition = bid_data[asset]

            if !(type == "consumer" && unit_commitment)
                push!(
                    error_messages,
                    "$prefix_msg have asset.type = 'consumer' and asset.unit_commitment = true",
                )
            end
            if !unit_commitment_integer
                push!(error_messages, "have asset.unit_commitment_integer = true")
            end
            if unit_commitment_method != "basic"
                push!(error_messages, "have asset.unit_commitment_method = \"basic\"")
            end
            if consumer_balance_sense != "=="
                push!(
                    error_messages,
                    "$prefix_msg have asset.consumer_balance_sense = \"==\", but found \"$consumer_balance_sense\"",
                )
            end
            if capacity != 1.0
                push!(error_messages, "$prefix_msg have asset.capacity = 1.0, but found $capacity")
            end
            if initial_units != 1.0
                push!(
                    error_messages,
                    "$prefix_msg have asset_both.initial_units = 1.0, but found $initial_units",
                )
            end
            if !has_loop
                push!(error_messages, "$prefix_msg have a loop flow, but found none")
            end
            if ismissing(operational_cost)
                push!(
                    error_messages,
                    "$prefix_msg to have an incoming flow with negative operational_cost, but found none",
                )
            end
            if !has_demand_profile
                push!(
                    error_messages,
                    "$prefix_msg have a profile in assets_profiles with profile_type = 'demand', but found none",
                )
            end
            if has_wrong_asset_partition
                push!(
                    error_messages,
                    "$prefix_msg has wrong asset partition. It should be uniform and equal to num_timesteps for all representative periods",
                )
            end
        end
    end

    return error_messages
end
