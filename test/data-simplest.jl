# Repository of data to be used for the tests
# All data should be NamedTuples of

function _create_connection_from_dict(data::Dict{Tuple{String,String},DataFrame})
    connection = DBInterface.connect(DuckDB.DB)

    for ((schema_name::String, table_name::String), table::DataFrame) in data
        _register_df(connection, table, schema_name, table_name)
    end

    return connection
end

module TestData
using DataFrames

const simplest_data = Dict(
    # Basic asset data
    ("input", "asset") => DataFrame(
        :asset => ["some_producer", "some_consumer"],
        :type => ["producer", "consumer"],
    ),
    ("input", "asset_both") => DataFrame(
        :asset => ["some_producer", "some_consumer"],
        :commission_year => [2030, 2030],
        :milestone_year => [2030, 2030],
    ),
    ("input", "asset_commission") => DataFrame(
        :asset => ["some_producer", "some_consumer"],
        :commission_year => [2030, 2030],
    ),
    ("input", "asset_milestone") => DataFrame(
        :asset => ["some_producer", "some_consumer"],
        :milestone_year => [2030, 2030],
    ),

    # Basic flow data
    ("input", "flow") =>
        DataFrame(:from_asset => ["some_producer"], :to_asset => ["some_consumer"]),
    ("input", "flow_both") => DataFrame(
        :from_asset => ["some_producer"],
        :to_asset => ["some_consumer"],
        :commission_year => [2030],
        :milestone_year => [2030],
    ),
    ("input", "flow_commission") => DataFrame(
        :from_asset => ["some_producer"],
        :to_asset => ["some_consumer"],
        :commission_year => [2030],
    ),
    ("input", "flow_milestone") => DataFrame(
        :from_asset => ["some_producer"],
        :to_asset => ["some_consumer"],
        :milestone_year => [2030],
    ),

    # Basic time information
    ("input", "year_data") => DataFrame(:year => [2030]),
    ("cluster", "rep_periods_data") => DataFrame(:year => [2030, 2030], :rep_period => [1, 2]),
    ("cluster", "timeframe_data") => DataFrame(:year => 2030, :period => 1:365),
    ("cluster", "rep_periods_mapping") =>
        DataFrame(:year => 2030, :period => 1:365, :rep_period => mod1.(1:365, 2)),
)
end
