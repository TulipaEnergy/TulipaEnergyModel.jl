# read schema from file

schema = JSON.parsefile("src/input-schemas.json"; dicttype = OrderedDict);

const schema_per_table_name = OrderedDict(
    "asset" => OrderedDict(key => value["type"] for (key, value) in schema["asset"]),
    "asset_both" => OrderedDict(key => value["type"] for (key, value) in schema["asset_both"]),
    "asset_commission" =>
        OrderedDict(key => value["type"] for (key, value) in schema["asset_commission"]),
    "asset_milestone" =>
        OrderedDict(key => value["type"] for (key, value) in schema["asset_milestone"]),
    "assets_profiles" =>
        OrderedDict(key => value["type"] for (key, value) in schema["assets_profiles"]),
    "assets_rep_periods_partitions" => OrderedDict(
        key => value["type"] for (key, value) in schema["assets_rep_periods_partitions"]
    ),
    "assets_timeframe_partitions" => OrderedDict(
        key => value["type"] for (key, value) in schema["assets_timeframe_partitions"]
    ),
    "assets_timeframe_profiles" =>
        OrderedDict(key => value["type"] for (key, value) in schema["assets_profiles"]),
    "flow" => OrderedDict(key => value["type"] for (key, value) in schema["flow"]),
    "flow_both" => OrderedDict(key => value["type"] for (key, value) in schema["flow_both"]),
    "flow_commission" =>
        OrderedDict(key => value["type"] for (key, value) in schema["flow_commission"]),
    "flow_milestone" =>
        OrderedDict(key => value["type"] for (key, value) in schema["flow_milestone"]),
    "flows_profiles" =>
        OrderedDict(key => value["type"] for (key, value) in schema["flows_profiles"]),
    "flows_rep_periods_partitions" => OrderedDict(
        key => value["type"] for (key, value) in schema["flows_rep_periods_partitions"]
    ),
    "group_asset" =>
        OrderedDict(key => value["type"] for (key, value) in schema["group_asset"]),
    "profiles_rep_periods" =>
        OrderedDict(key => value["type"] for (key, value) in schema["profiles_rep_periods"]),
    "profiles_timeframe" =>
        OrderedDict(key => value["type"] for (key, value) in schema["profiles_timeframe"]),
    "rep_periods_data" =>
        OrderedDict(key => value["type"] for (key, value) in schema["rep_periods_data"]),
    "rep_periods_mapping" =>
        OrderedDict(key => value["type"] for (key, value) in schema["rep_periods_mapping"]),
    "year_data" => OrderedDict(key => value["type"] for (key, value) in schema["year_data"]),
)
