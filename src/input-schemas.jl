# At the end of the file, there is a reference relating schemas and files

const schemas = (
    assets = (
        # Schema for the assets-data.csv file.
        data = OrderedDict(
            :name => String,                                            # Name of Asset (geographical?)
            :type => String,                                            # Producer/Consumer/Storage/Conversion
            :active => Bool,                                            # Active or decomissioned
            :investable => Bool,                                        # Whether able to invest
            :investment_integer => Bool,                                # Whether investment is integer or continuous
            :investment_cost => Float64,                                # kEUR/MW/year
            :investment_limit => Union{Missing,Float64},                # MW (Missing -> no limit)
            :capacity => Float64,                                       # MW
            :initial_capacity => Float64,                               # MW
            :peak_demand => Float64,                                    # MW
            :consumer_balance_sense => Union{Missing,String},           # Sense of the consumer balance constraint (default ==)
            :is_seasonal => Bool,                                       # Whether seasonal storage (e.g. hydro) or not (e.g. battery)
            :storage_inflows => Float64,                                # MWh/year
            :initial_storage_capacity => Float64,                       # MWh
            :initial_storage_level => Union{Missing,Float64},           # MWh (Missing -> free initial level)
            :energy_to_power_ratio => Float64,                          # Hours
            :storage_method_energy => Bool,                             # Whether storage method is energy or not (i.e., fixed_ratio)
            :investment_cost_storage_energy => Float64,                 # kEUR/MWh/year
            :investment_limit_storage_energy => Union{Missing,Float64}, # MWh (Missing -> no limit)
            :capacity_storage_energy => Float64,                        # MWh
            :investment_integer_storage_energy => Bool,                 # Whether investment for storage energy is integer or continuous
            :use_binary_storage_method => Union{String,Missing},        # Whether to use an extra binary variable for the storage assets to avoid charging and discharging simultaneously (missing;binary;relaxed_binary)
            :max_energy_timeframe_partition => Union{Missing,Float64},  # MWh (Missing -> no limit)
            :min_energy_timeframe_partition => Union{Missing,Float64},  # MWh (Missing -> no limit)
        ),

        # Schema for the assets-profiles.csv file.
        profiles_reference = OrderedDict(
            :asset => String,               # Asset name
            :profile_type => String,        # Type of profile, used to determine dataframe with source profile
            :profile_name => String,        # Name of profile, used to determine data inside the dataframe
        ),

        # Schema for the assets-timeframe-partitions.csv file.
        timeframe_partition = OrderedDict(
            :asset => String,
            :specification => String,
            :partition => String,
        ),

        # Schema for the assets-rep-periods-partitions.csv file.
        rep_periods_partition = OrderedDict(
            :asset => String,
            :rep_period => Int,
            :specification => String,
            :partition => String,
        ),
    ),
    flows = (
        # Schema for the flows-data.csv file.
        data = OrderedDict(
            :carrier => String,                             # (Optional?) Energy carrier
            :from_asset => String,                          # Name of Asset
            :to_asset => String,                            # Name of Asset
            :active => Bool,                                # Active or decomissioned
            :is_transport => Bool,                          # Whether a transport flow
            :investable => Bool,                            # Whether able to invest
            :investment_integer => Bool,                    # Whether investment is integer or continuous
            :variable_cost => Float64,                      # kEUR/MWh
            :investment_cost => Float64,                    # kEUR/MW/year
            :investment_limit => Union{Missing,Float64},    # MW
            :capacity => Float64,                           # MW
            :initial_export_capacity => Float64,            # MW
            :initial_import_capacity => Float64,            # MW
            :efficiency => Float64,                         # p.u. (per unit)
        ),

        # Schema for the flows-profiles file.
        profiles_reference = OrderedDict(
            :from_asset => String,          # Name of Asset
            :to_asset => String,            # Name of Asset
            :profile_type => String,        # Type of profile, used to determine dataframe with source profile
            :profile_name => String,        # Name of profile, used to determine data inside the dataframe
        ),

        # Schema for the flows-rep-periods-partitions.csv file.
        rep_periods_partition = OrderedDict(
            :from_asset => String,          # Name of Asset
            :to_asset => String,            # Name of Asset
            :rep_period => Int,
            :specification => String,
            :partition => String,
        ),
    ),
    timeframe = (
        # Schema for the profiles-timeframe-<type>.csv file.
        profiles_data = OrderedDict(
            :profile_name => String,        # Profile name
            :period => Int,                 # Period
            :value => Float64,              # p.u. (per unit)
        ),
    ),

    # Schema for the rep-periods-data.csv file.
    rep_periods = (
        data = OrderedDict(
            :rep_period => Int,             # Representative period number
            :num_timesteps => Int,          # Numer of timesteps
            :resolution => Float64,         # Duration of each timestep (hours)
        ),

        # Schema for the rep-periods-mapping.csv file.
        mapping = OrderedDict(
            :period => Int,                 # Period number
            :rep_period => Int,             # Representative period number
            :weight => Float64,             # Hours
        ),

        # Schema for the profiles-rep-periods-<type>.csv file.
        profiles_data = OrderedDict(
            :profile_name => String,        # Profile name
            :rep_period => Int,             # Representative period number
            :timestep => Int,               # Timestep number
            :value => Float64,              # p.u. (per unit)
        ),
    ),
)

const schema_per_file = OrderedDict(
    "assets_timeframe_partitions" => schemas.assets.timeframe_partition,
    "assets_data" => schemas.assets.data,
    "assets_timeframe_profiles" => schemas.assets.profiles_reference,
    "assets_profiles" => schemas.assets.profiles_reference,
    "assets_rep_periods_partitions" => schemas.assets.rep_periods_partition,
    "flows_data" => schemas.flows.data,
    "flows_profiles" => schemas.flows.profiles_reference,
    "flows_rep_periods_partitions" => schemas.flows.rep_periods_partition,
    "profiles_timeframe" => schemas.timeframe.profiles_data,
    "profiles_rep_periods" => schemas.rep_periods.profiles_data,
    "rep_periods_data" => schemas.rep_periods.data,
    "rep_periods_mapping" => schemas.rep_periods.mapping,
)
