# Repository of data to be used for the tests
# All data should be NamedTuples of

function _create_connection_from_dict(data::Dict{String,DataFrame})
    connection = DBInterface.connect(DuckDB.DB)

    for (table_name::String, table::DataFrame) in data
        # Check that these `table_name` exist in the schema
        if !haskey(TulipaEnergyModel.schema_per_table_name, table_name)
            error("Table '$table_name' does not exist")
        end
        DuckDB.register_data_frame(connection, table, table_name)
    end

    return connection
end

module TestData
using DataFrames

const simplest_data = Dict(
    # Basic asset data
    "asset" => DataFrame(
        :asset => ["some_producer", "some_consumer"],
        :type => ["producer", "consumer"],
    ),
    "asset_both" => DataFrame(
        :asset => ["some_producer", "some_consumer"],
        :commission_year => [2030, 2030],
        :milestone_year => [2030, 2030],
    ),
    "asset_commission" => DataFrame(
        :asset => ["some_producer", "some_consumer"],
        :commission_year => [2030, 2030],
        :fixed_cost => [1.0, 2.0],
        :fixed_cost_storage_energy => [1.0, 2.0],
        :investment_cost => [1.0, 2.0],
        :investment_cost_storage_energy => [1.0, 2.0],
        :investment_limit => [1.0, 2.0],
        :investment_limit_storage_energy => [1.0, 2.0],
    ),
    "asset_milestone" => DataFrame(
        :asset => ["some_producer", "some_consumer"],
        :milestone_year => [2030, 2030],
        :min_energy_timeframe_partition => [1.0, 1.0],
        :max_energy_timeframe_partition => [2.0, 2.0],
    ),

    # Basic flow data
    "flow" => DataFrame(:from_asset => ["some_producer"], :to_asset => ["some_consumer"]),
    "flow_both" => DataFrame(
        :from_asset => ["some_producer"],
        :to_asset => ["some_consumer"],
        :commission_year => [2030],
        :milestone_year => [2030],
    ),
    "flow_commission" => DataFrame(
        :from_asset => ["some_producer"],
        :to_asset => ["some_consumer"],
        :commission_year => [2030],
        :fixed_cost => [1.0],
        :investment_cost => [1.0],
        :investment_limit => [1.0],
    ),
    "flow_milestone" => DataFrame(
        :from_asset => ["some_producer"],
        :to_asset => ["some_consumer"],
        :milestone_year => [2030],
    ),

    # Basic time information
    "year_data" => DataFrame(:year => [2030], :length => [8760], :is_milestone => [true]),
    "rep_periods_data" =>
        DataFrame(:year => [2030, 2030], :rep_period => [1, 2], :num_timesteps => [24, 24]),
    "timeframe_data" => DataFrame(:year => 2030, :period => 1:365, :num_timesteps => 24),
    "rep_periods_mapping" =>
        DataFrame(:year => 2030, :period => 1:365, :rep_period => mod1.(1:365, 2)),

    # Profiles
    "assets_profiles" => DataFrame(
        "asset" => ["some_producer"],
        "commission_year" => [2030],
        "profile_name" => ["some_producer_profile"],
        "profile_type" => ["availability"],
    ),
    "flows_profiles" => DataFrame(
        "from_asset" => ["some_producer"],
        "to_asset" => ["some_consumer"],
        "year" => [2030],
        "profile_name" => ["some_flow_profile"],
        "profile_type" => ["availability"],
    ),
    "profiles_rep_periods" => DataFrame(
        "profile_name" => "some_producer_profile",
        "year" => 2030,
        "rep_period" => [fill(1, 24); fill(2, 24)],
        "timestep" => [1:24; 1:24],
        "value" => ones(48),
    ),
)
end
