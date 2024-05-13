# At the end of the file, there is a reference relating schemas and files

const schemas = (
    assets = (
        # Schema for the assets-data.csv file.
        data = OrderedDict(
            :name => Symbol,                                            # Name of Asset (geographical?)
            :type => Symbol,                                            # Producer/Consumer/Storage/Conversion
            :active => Bool,                                            # Active or decomissioned
            :investable => Bool,                                        # Whether able to invest
            :investment_integer => Bool,                                # Whether investment is integer or continuous
            :investment_cost => Float64,                                # kEUR/MW/year
            :investment_limit => Union{Missing,Float64},                # MW (Missing -> no limit)
            :capacity => Float64,                                       # MW
            :initial_capacity => Float64,                               # MW
            :peak_demand => Float64,                                    # MW
            :consumer_balance_sense => Union{Missing,Symbol},           # Sense of the consumer balance constraint (default ==)
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
            :use_binary_storage_method => Union{Symbol,Missing},                       # Whether to use an extra binary variable for the storage assets to avoid charging and discharging simultaneously (missing;binary;relaxed_binary)
        ),

        # Schema for the assets-profiles.csv file.
        profiles_reference = OrderedDict(
            :asset => Symbol,               # Asset ID
            :profile_type => Symbol,        # Type of profile, used to determine dataframe with source profile
            :profile_name => Symbol,        # Name of profile, used to determine data inside the dataframe
        ),

        # Schema for the assets-timeframe-partitions.csv file.
        timeframe_partition = OrderedDict(
            :asset => Symbol,
            :specification => Symbol,
            :partition => String,
        ),

        # Schema for the assets-rep-periods-partitions.csv file.
        rep_periods_partition = OrderedDict(
            :asset => Symbol,
            :rep_period => Int,
            :specification => Symbol,
            :partition => String,
        ),
    ),
    flows = (
        # Schema for the flows-data.csv file.
        data = OrderedDict(
            :carrier => Symbol,                             # (Optional?) Energy carrier
            :from_asset => Symbol,                          # Name of Asset
            :to_asset => Symbol,                            # Name of Asset
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
            :from_asset => Symbol,          # Name of Asset
            :to_asset => Symbol,            # Name of Asset
            :profile_type => Symbol,        # Type of profile, used to determine dataframe with source profile
            :profile_name => Symbol,        # Name of profile, used to determine data inside the dataframe
        ),

        # Schema for the flows-rep-periods-partitions.csv file.
        rep_periods_partition = OrderedDict(
            :from_asset => Symbol,          # Name of Asset
            :to_asset => Symbol,            # Name of Asset
            :rep_period => Int,
            :specification => Symbol,
            :partition => String,
        ),
    ),
    timeframe = (
        # Schema for the profiles-timeframe-<type>.csv file.
        profiles_data = OrderedDict(
            :profile_name => Symbol,        # Asset ID
            :period => Int,                 # Period
            :value => Float64,              # p.u. (per unit)
        ),
    ),

    # Schema for the rep-periods-data.csv file.
    rep_periods = (
        data = OrderedDict(
            :id => Int,                     # Representative period ID
            :num_timesteps => Int,          # Numer of timesteps
            :resolution => Float64,         # Duration of each timestep (hours)
        ),

        # Schema for the rep-periods-mapping.csv file.
        mapping = OrderedDict(
            :period => Int,                 # Period ID
            :rep_period => Int,             # Representative period ID
            :weight => Float64,             # Hours
        ),

        # Schema for the profiles-rep-periods-<type>.csv file.
        profiles_data = OrderedDict(
            :profile_name => Symbol,        # Asset ID
            :rep_period => Int,             # Representative period ID
            :timestep => Int,               # Timestep ID
            :value => Float64,              # p.u. (per unit)
        ),
    ),
)

const schema_per_file = OrderedDict(
    "assets-timeframe-partitions.csv" => schemas.assets.timeframe_partition,
    "assets-data.csv" => schemas.assets.data,
    "assets-timeframe-profiles.csv" => schemas.assets.profiles_reference,
    "assets-rep-periods-profiles.csv" => schemas.assets.profiles_reference,
    "assets-rep-periods-partitions.csv" => schemas.assets.rep_periods_partition,
    "flows-data.csv" => schemas.flows.data,
    "flows-rep-periods-profiles.csv" => schemas.flows.profiles_reference,
    "flows-rep-periods-partitions.csv" => schemas.flows.rep_periods_partition,
    "profiles-timeframe-<type>.csv" => schemas.timeframe.profiles_data,
    "profiles-rep-periods-<type>.csv" => schemas.rep_periods.profiles_data,
    "rep-periods-data.csv" => schemas.rep_periods.data,
    "rep-periods-mapping.csv" => schemas.rep_periods.mapping,
)
