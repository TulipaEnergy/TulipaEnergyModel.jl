# At the end of the file, there is a reference relating schemas and files

const schemas = (
    assets = (
        # Schema for asset.csv
        basic = (
            :asset => "VARCHAR",                              # Name of Asset (geographical?)
            :type => "VARCHAR",                              # Producer/Consumer/Storage/Conversion
            :group => "VARCHAR",                             # Group to which the asset belongs to (missing -> no group)
            :capacity => "DOUBLE",                           # MW
            :min_operating_point => "DOUBLE",                # Minimum operating point or minimum stable generation level defined as a portion of the capacity of asset [p.u.]
            :investment_method => "VARCHAR",                 # Which method of investment (simple/compact)
            :investment_integer => "BOOLEAN",                # Whether investment is integer or continuous
            :technical_lifetime => "INTEGER",                # years
            :economic_lifetime => "INTEGER",                 # years
            :discount_rate => "DOUBLE",                      # p.u.
            :consumer_balance_sense => "VARCHAR",            # Sense of the consumer balance constraint (default ==)
            :capacity_storage_energy => "DOUBLE",            # MWh
            :is_seasonal => "BOOLEAN",                       # Whether seasonal storage (e.g. hydro) or not (e.g. battery)
            :use_binary_storage_method => "VARCHAR",         # Whether to use an extra binary variable for the storage assets to avoid charging and discharging simultaneously (missing;binary;relaxed_binary)
            :unit_commitment => "BOOLEAN",                   # Whether asset has unit commitment constraints
            :unit_commitment_method => "VARCHAR",            # Which unit commitment method to use (i.e., basic)
            :unit_commitment_integer => "BOOLEAN",           # Whether the unit commitment variables are integer or not
            :ramping => "BOOLEAN",                           # Whether asset has ramping constraints
            :storage_method_energy => "BOOLEAN",             # Whether storage method is energy or not (i.e., fixed_ratio)
            :energy_to_power_ratio => "DOUBLE",              # Hours
            :investment_integer_storage_energy => "BOOLEAN", # Whether investment for storage energy is integer or continuous
            :max_ramp_up => "DOUBLE",                        # Maximum ramping up rate as a portion of the capacity of asset [p.u./h]
            :max_ramp_down => "DOUBLE",                      # Maximum ramping down rate as a portion of the capacity of asset [p.u./h]
        ),

        # Schema for asset-milestone.csv
        milestone = OrderedDict(
            :asset => "VARCHAR",
            :milestone_year => "INTEGER",
            :investable => "BOOLEAN",                        # Whether able to invest
            :peak_demand => "DOUBLE",                        # MW
            :storage_inflows => "DOUBLE",                    # MWh/year
            :initial_storage_level => "DOUBLE",              # MWh (Missing -> free initial level)
            :min_energy_timeframe_partition => "DOUBLE",     # MWh (Missing -> no limit)
            :max_energy_timeframe_partition => "DOUBLE",     # MWh (Missing -> no limit)
            :units_on_cost => "DOUBLE",                      # Objective function coefficient on `units_on` variable. e.g., no-load cost or idling cost
        ),

        # Schema for the asset-commission.csv
        commission = OrderedDict(
            :asset => "VARCHAR",
            :commission_year => "INTEGER",                   # Year of commissioning
            :fixed_cost => "DOUBLE",                         # kEUR/MW/year
            :investment_cost => "DOUBLE",                    # kEUR/MW
            :investment_limit => "DOUBLE",                   # MWh (Missing -> no limit)
            :fixed_cost_storage_energy => "DOUBLE",          # kEUR/MWh/year
            :investment_cost_storage_energy => "DOUBLE",     # kEUR/MWh
            :investment_limit_storage_energy => "DOUBLE",    # MWh (Missing -> no limit)
        ),

        # Schema for the asset-both.csv file.
        both = OrderedDict(
            :asset => "VARCHAR",                              # Name of Asset (geographical?)
            :milestone_year => "INTEGER",                              # Year
            :commission_year => "INTEGER",                   # Year of commissioning
            :active => "BOOLEAN",                            # Active or decomissioned
            :decommissionable => "BOOLEAN",
            :initial_units => "DOUBLE",                      # units
            :initial_storage_units => "DOUBLE",              # units
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
        # Schema for the group-asset.csv file.
        data = OrderedDict(
            :name => "VARCHAR",                # Name of the Group
            :milestone_year => "INTEGER",
            :invest_method => "BOOLEAN",       # true -> activate group constraints; false -> no group investment constraints
            :min_investment_limit => "DOUBLE", # MW (Missing -> no limit)
            :max_investment_limit => "DOUBLE", # MW (Missing -> no limit)
        ),
    ),
    flows = (
        # Schema for flow.csv
        basic = (
            :from_asset => "VARCHAR",                        # Name of Asset
            :to_asset => "VARCHAR",                          # Name of Asset
            :carrier => "VARCHAR",                           # (Optional?) Energy carrier
            :is_transport => "BOOLEAN",                      # Whether a transport flow
            :capacity => "DOUBLE",
            :technical_lifetime => "INTEGER",
            :economic_lifetime => "INTEGER",
            :discount_rate => "DOUBLE",
            :investment_integer => "BOOLEAN",       # Whether investment is integer or continuous
        ),

        # Schema for flow-milestone.csv
        milestone = OrderedDict(
            :from_asset => "VARCHAR",                        # Name of Asset
            :to_asset => "VARCHAR",                          # Name of Asset
            :milestone_year => "INTEGER",                   # Year of commissioning
            :investable => "BOOLEAN",               # Whether able to invest
            :variable_cost => "DOUBLE",             # kEUR/MWh
        ),

        # Schema for the flow-commission.csv
        commission = OrderedDict(
            :from_asset => "VARCHAR",                        # Name of Asset
            :to_asset => "VARCHAR",                          # Name of Asset
            :commission_year => "INTEGER",                   # Year of commissioning
            :fixed_cost => "DOUBLE",                         # kEUR/MWh/year
            :investment_cost => "DOUBLE",                    # kEUR/MW
            :efficiency => "DOUBLE",                # p.u. (per unit)
            :investment_limit => "DOUBLE",          # MW
        ),

        # Schema for the flow-both.csv file.
        both = OrderedDict(
            :from_asset => "VARCHAR",               # Name of Asset
            :to_asset => "VARCHAR",                 # Name of Asset
            :milestone_year => "INTEGER",
            :commission_year => "INTEGER",          # Year of commissioning
            :active => "BOOLEAN",                   # Active or decomissioned
            :decommissionable => "BOOLEAN",
            :initial_export_units => "DOUBLE",   # MW
            :initial_import_units => "DOUBLE",   # MW
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
    "asset" => schemas.assets.basic,
    "asset_both" => schemas.assets.both,
    "asset_commission" => schemas.assets.commission,
    "asset_milestone" => schemas.assets.milestone,
    "assets_profiles" => schemas.assets.profiles_reference,
    "assets_rep_periods_partitions" => schemas.assets.rep_periods_partition,
    "assets_timeframe_partitions" => schemas.assets.timeframe_partition,
    "assets_timeframe_profiles" => schemas.assets.profiles_reference,
    "flow" => schemas.flows.basic,
    "flow_both" => schemas.flows.both,
    "flow_commission" => schemas.flows.commission,
    "flow_milestone" => schemas.flows.milestone,
    "flows_profiles" => schemas.flows.profiles_reference,
    "flows_rep_periods_partitions" => schemas.flows.rep_periods_partition,
    "group_asset" => schemas.groups.data,
    "profiles_rep_periods" => schemas.rep_periods.profiles_data,
    "profiles_timeframe" => schemas.timeframe.profiles_data,
    "rep_periods_data" => schemas.rep_periods.data,
    "rep_periods_mapping" => schemas.rep_periods.mapping,
    "year_data" => schemas.year.data,
)
