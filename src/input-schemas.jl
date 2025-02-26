# read schema from file

schema = JSON.parsefile("src/input-schemas.json"; dicttype = OrderedDict);

const schema_per_table_name = OrderedDict(
    "asset" => OrderedDict(key => value["type"] for (key, value) in schema["asset"]["basic"]),
    "asset_both" =>
        OrderedDict(key => value["type"] for (key, value) in schema["asset"]["both"]),
    "asset_commission" =>
        OrderedDict(key => value["type"] for (key, value) in schema["asset"]["commission"]),
    "asset_milestone" =>
        OrderedDict(key => value["type"] for (key, value) in schema["asset"]["milestone"]),
    "assets_profiles" => OrderedDict(
        key => value["type"] for (key, value) in schema["asset"]["profiles_reference"]
    ),
    "assets_rep_periods_partitions" => OrderedDict(
        key => value["type"] for (key, value) in schema["asset"]["rep_periods_partition"]
    ),
    "assets_timeframe_partitions" => OrderedDict(
        key => value["type"] for (key, value) in schema["asset"]["timeframe_partition"]
    ),
    "assets_timeframe_profiles" => OrderedDict(
        key => value["type"] for (key, value) in schema["asset"]["profiles_reference"]
    ),
    "flow" => OrderedDict(key => value["type"] for (key, value) in schema["flow"]["basic"]),
    "flow_both" => OrderedDict(key => value["type"] for (key, value) in schema["flow"]["both"]),
    "flow_commission" =>
        OrderedDict(key => value["type"] for (key, value) in schema["flow"]["commission"]),
    "flow_milestone" =>
        OrderedDict(key => value["type"] for (key, value) in schema["flow"]["milestone"]),
    "flows_profiles" => OrderedDict(
        key => value["type"] for (key, value) in schema["flow"]["profiles_reference"]
    ),
    "flows_rep_periods_partitions" => OrderedDict(
        key => value["type"] for (key, value) in schema["flow"]["rep_periods_partition"]
    ),
    "group_asset" =>
        OrderedDict(key => value["type"] for (key, value) in schema["group"]["data"]),
    "profiles_rep_periods" => OrderedDict(
        key => value["type"] for (key, value) in schema["rep_period"]["profiles_data"]
    ),
    "profiles_timeframe" => OrderedDict(
        key => value["type"] for (key, value) in schema["timeframe"]["profiles_data"]
    ),
    "rep_periods_data" =>
        OrderedDict(key => value["type"] for (key, value) in schema["rep_period"]["data"]),
    "rep_periods_mapping" =>
        OrderedDict(key => value["type"] for (key, value) in schema["rep_period"]["mapping"]),
    "year_data" => OrderedDict(key => value["type"] for (key, value) in schema["year"]["data"]),
)
