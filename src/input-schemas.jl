# At the end of the file, there is a reference relating schemas and files

const schemas = (
    graph = (
        assets = (
            :name => "VARCHAR",                              # Name of Asset (geographical?)
            :type => "VARCHAR",                              # Producer/Consumer/Storage/Conversion
            :group => "VARCHAR",                             # Group to which the asset belongs to (missing -> no group)
            :investment_method => "VARCHAR",                 # Which method of investment (simple/compact)
            :capacity => "DOUBLE",                           # MW
            :technical_lifetime => "INTEGER",                # years
            :economic_lifetime => "INTEGER",                 # years
            :discount_rate => "DOUBLE",                      # p.u.
            :capacity_storage_energy => "DOUBLE",            # MWh
        ),
        flows = (
            :from_asset => "VARCHAR",                        # Name of Asset
            :to_asset => "VARCHAR",                          # Name of Asset
            :carrier => "VARCHAR",                           # (Optional?) Energy carrier
            :is_transport => "BOOLEAN",                      # Whether a transport flow
            :capacity => "DOUBLE",
            :technical_lifetime => "INTEGER",
            :economic_lifetime => "INTEGER",
            :discount_rate => "DOUBLE",
        ),
    ),
    assets = (
        # Schema for the assets-data.csv file.
        data = OrderedDict(
            :name => "VARCHAR",                              # Name of Asset (geographical?)
            :active => "BOOLEAN",                            # Active or decomissioned
            :year => "INTEGER",                              # Year
            :commission_year => "INTEGER",                   # Year of commissioning
            :investable => "BOOLEAN",                        # Whether able to invest
            :investment_integer => "BOOLEAN",                # Whether investment is integer or continuous
            :investment_limit => "DOUBLE",                   # MW (Missing -> no limit)
            :initial_units => "DOUBLE",                      # units
            :peak_demand => "DOUBLE",                        # MW
            :consumer_balance_sense => "VARCHAR",            # Sense of the consumer balance constraint (default ==)
            :is_seasonal => "BOOLEAN",                       # Whether seasonal storage (e.g. hydro) or not (e.g. battery)
            :storage_inflows => "DOUBLE",                    # MWh/year
            :initial_storage_units => "DOUBLE",              # units
            :initial_storage_level => "DOUBLE",              # MWh (Missing -> free initial level)
            :energy_to_power_ratio => "DOUBLE",              # Hours
            :storage_method_energy => "BOOLEAN",             # Whether storage method is energy or not (i.e., fixed_ratio)
            :investment_limit_storage_energy => "DOUBLE",    # MWh (Missing -> no limit)
            :investment_integer_storage_energy => "BOOLEAN", # Whether investment for storage energy is integer or continuous
            :use_binary_storage_method => "VARCHAR",         # Whether to use an extra binary variable for the storage assets to avoid charging and discharging simultaneously (missing;binary;relaxed_binary)
            :max_energy_timeframe_partition => "DOUBLE",     # MWh (Missing -> no limit)
            :min_energy_timeframe_partition => "DOUBLE",     # MWh (Missing -> no limit)
            :unit_commitment => "BOOLEAN",                   # Whether asset has unit commitment constraints
            :unit_commitment_method => "VARCHAR",            # Which unit commitment method to use (i.e., basic)
            :units_on_cost => "DOUBLE",                      # Objective function coefficient on `units_on` variable. e.g., no-load cost or idling cost
            :unit_commitment_integer => "BOOLEAN",           # Whether the unit commitment variables are integer or not
            :min_operating_point => "DOUBLE",                # Minimum operating point or minimum stable generation level defined as a portion of the capacity of asset [p.u.]
            :ramping => "BOOLEAN",                           # Whether asset has ramping constraints
            :max_ramp_up => "DOUBLE",                        # Maximum ramping up rate as a portion of the capacity of asset [p.u./h]
            :max_ramp_down => "DOUBLE",                      # Maximum ramping down rate as a portion of the capacity of asset [p.u./h]
        ),

        # Schema for the vintage-assets-data.csv
        vintage_assets_data = OrderedDict(
            :name => "VARCHAR",
            :commission_year => "INTEGER",                   # Year of commissioning
            :fixed_cost => "DOUBLE",                         # kEUR/MW/year
            :investment_cost => "DOUBLE",                    # kEUR/MW
            :fixed_cost_storage_energy => "DOUBLE",          # kEUR/MWh/year
            :investment_cost_storage_energy => "DOUBLE",     # kEUR/MWh
        ),

        # Schema for the vintage-flows-data.csv
        vintage_flows_data = OrderedDict(
            :from_asset => "VARCHAR",                        # Name of Asset
            :to_asset => "VARCHAR",                          # Name of Asset
            :commission_year => "INTEGER",                   # Year of commissioning
            :fixed_cost => "DOUBLE",                         # kEUR/MWh/year
            :investment_cost => "DOUBLE",                    # kEUR/MW
        ),

        # Schema for the assets-profiles.csv and assets-timeframe-profiles.csv file.
        profiles_reference = OrderedDict(
            :asset => "VARCHAR",               # Asset name
            :commission_year => "INTEGER",
            :profile_type => "VARCHAR",        # Type of profile, used to determine dataframe with source profile
            :profile_name => "VARCHAR",        # Name of profile, used to determine data inside the dataframe
        ),

        # Schema for the assets-timeframe-partitions.csv file.
        timeframe_partition = OrderedDict(
            :asset => "VARCHAR",
            :year => "INTEGER",
            :specification => "VARCHAR",
            :partition => "VARCHAR",
        ),

        # Schema for the assets-rep-periods-partitions.csv file.
        rep_periods_partition = OrderedDict(
            :asset => "VARCHAR",
            :year => "INTEGER",
            :rep_period => "INTEGER",
            :specification => "VARCHAR",
            :partition => "VARCHAR",
        ),
    ),
    groups = (
        # Schema for the groups-data.csv file.
        data = OrderedDict(
            :name => "VARCHAR",                # Name of the Group
            :year => "INTEGER",
            :invest_method => "BOOLEAN",       # true -> activate group constraints; false -> no group investment constraints
            :min_investment_limit => "DOUBLE", # MW (Missing -> no limit)
            :max_investment_limit => "DOUBLE", # MW (Missing -> no limit)
        ),
    ),
    flows = (
        # Schema for the flows-data.csv file.
        data = OrderedDict(
            :from_asset => "VARCHAR",               # Name of Asset
            :to_asset => "VARCHAR",                 # Name of Asset
            :year => "INTEGER",
            :active => "BOOLEAN",                   # Active or decomissioned
            :investable => "BOOLEAN",               # Whether able to invest
            :investment_integer => "BOOLEAN",       # Whether investment is integer or continuous
            :variable_cost => "DOUBLE",             # kEUR/MWh
            :investment_limit => "DOUBLE",          # MW
            :initial_export_units => "DOUBLE",   # MW
            :initial_import_units => "DOUBLE",   # MW
            :efficiency => "DOUBLE",                # p.u. (per unit)
        ),

        # Schema for the flows-profiles file.
        profiles_reference = OrderedDict(
            :from_asset => "VARCHAR",          # Name of Asset
            :to_asset => "VARCHAR",            # Name of Asset
            :year => "INTEGER",
            :profile_type => "VARCHAR",        # Type of profile, used to determine dataframe with source profile
            :profile_name => "VARCHAR",        # Name of profile, used to determine data inside the dataframe
        ),

        # Schema for the flows-rep-periods-partitions.csv file.
        rep_periods_partition = OrderedDict(
            :from_asset => "VARCHAR",          # Name of Asset
            :to_asset => "VARCHAR",            # Name of Asset
            :year => "INTEGER",
            :rep_period => "INTEGER",
            :specification => "VARCHAR",
            :partition => "VARCHAR",
        ),
    ),
    year = (
        # Schema for year-data.csv
        data = (
            :year => "INTEGER",                       # Unique identifier (currently, the year itself)
            :length => "INTEGER",
            :is_milestone => "BOOLEAN",             # Whether the year is a milestone year of a vintage year
        ),
    ),
    timeframe = (
        # Schema for the profiles-timeframe-<type>.csv file.
        profiles_data = OrderedDict(
            :profile_name => "VARCHAR",      # Profile name
            :year => "INTEGER",
            :period => "INTEGER",            # Period
            :value => "DOUBLE",              # p.u. (per unit)
        ),
    ),
    rep_periods = (
        # Schema for the rep-periods-data.csv file.
        data = OrderedDict(
            :year => "INTEGER",
            :rep_period => "INTEGER",        # Representative period number
            :num_timesteps => "INTEGER",     # Numer of timesteps
            :resolution => "DOUBLE",         # Duration of each timestep (hours)
        ),

        # Schema for the rep-periods-mapping.csv file.
        mapping = OrderedDict(
            :year => "INTEGER",
            :period => "INTEGER",            # Period number
            :rep_period => "INTEGER",        # Representative period number
            :weight => "DOUBLE",             # Hours
        ),

        # Schema for the profiles-rep-periods-<type>.csv file.
        profiles_data = OrderedDict(
            :profile_name => "VARCHAR",  # Profile name
            :year => "INTEGER",
            :rep_period => "INTEGER",    # Representative period number
            :timestep => "INTEGER",      # Timestep number
            :value => "DOUBLE",          # p.u. (per unit)
        ),
    ),
)

const schema_per_table_name = OrderedDict(
    "assets_timeframe_partitions" => schemas.assets.timeframe_partition,
    "assets_data" => schemas.assets.data,
    "assets_timeframe_profiles" => schemas.assets.profiles_reference,
    "assets_profiles" => schemas.assets.profiles_reference,
    "assets_rep_periods_partitions" => schemas.assets.rep_periods_partition,
    "flows_data" => schemas.flows.data,
    "flows_profiles" => schemas.flows.profiles_reference,
    "flows_rep_periods_partitions" => schemas.flows.rep_periods_partition,
    "graph_assets_data" => schemas.graph.assets,
    "graph_flows_data" => schemas.graph.flows,
    "groups_data" => schemas.groups.data,
    "profiles_timeframe" => schemas.timeframe.profiles_data,
    "profiles_rep_periods" => schemas.rep_periods.profiles_data,
    "rep_periods_data" => schemas.rep_periods.data,
    "rep_periods_mapping" => schemas.rep_periods.mapping,
    "vintage_assets_data" => schemas.assets.vintage_assets_data,
    "vintage_flows_data" => schemas.assets.vintage_flows_data,
    "year_data" => schemas.year.data,
)
