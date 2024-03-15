# At the end of the file, there is a reference relating schemas and files

const schemas = (
    assets = (
        # Schema for the assets-data.csv file.
        data = OrderedDict(
            :name => Symbol,                                       # Name of Asset (geographical?)
            :type => Symbol,                                       # Producer/Consumer/Storage/Conversion
            :active => Bool,                                       # Active or decomissioned
            :investable => Bool,                                   # Whether able to invest
            :investment_integer => Bool,                           # Whether investment is integer or continuous
            :investment_cost => Float64,                           # kEUR/MW/year
            :investment_limit => Union{Missing,Float64},           # MW (Missing -> no limit)
            :capacity => Float64,                                  # MW
            :initial_capacity => Float64,                          # MW
            :peak_demand => Float64,                               # MW
            :is_seasonal => Bool,                                  # Whether seasonal storage (e.g. hydro) or not (e.g. battery)
            :storage_inflows => Float64,                           # MWh/year
            :initial_storage_capacity => Float64,                  # MWh
            :initial_storage_level => Union{Missing,Float64},      # MWh (Missing -> free initial level)
            :energy_to_power_ratio => Float64,                     # Hours
        ),

        # Schema for the assets-profiles.csv file.
        profiles_reference = OrderedDict(
            :asset => Symbol,               # Asset ID
            :profile_type => Symbol,        # Type of profile, used to determine dataframe with source profile
            :profile_name => Symbol,        # Name of profile, used to determine data inside the dataframe
        ),

        # Schema for the assets-base-periods-partitions.csv file.
        base_periods_partition = OrderedDict(
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
    base_periods = (
        # Schema for the profiles-base-periods-<type>.csv file.
        profiles_data = OrderedDict(
            :profile_name => Symbol,        # Asset ID
            :base_period => Int,            # Base period ID
            :value => Float64,              # p.u. (per unit)
        ),
    ),

    # Schema for the rep-periods-data.csv file.
    rep_periods = (
        data = OrderedDict(
            :id => Int,                     # Representative period ID
            :num_time_steps => Int,         # Numer of time steps
            :resolution => Float64,         # Duration of each time steps (hours)
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
            :time_step => Int,              # Time step ID
            :value => Float64,              # p.u. (per unit)
        ),
    ),
)

const schema_per_file = OrderedDict(
    "assets-base-periods-partitions.csv" => schemas.assets.base_periods_partition,
    "assets-data.csv" => schemas.assets.data,
    "assets-base-periods-profiles.csv" => schemas.assets.profiles_reference,
    "assets-rep-periods-profiles.csv" => schemas.assets.profiles_reference,
    "assets-rep-periods-partitions.csv" => schemas.assets.rep_periods_partition,
    "flows-data.csv" => schemas.flows.data,
    "flows-rep-periods-profiles.csv" => schemas.flows.profiles_reference,
    "flows-rep-periods-partitions.csv" => schemas.flows.rep_periods_partition,
    "profiles-base-periods-<type>.csv" => schemas.base_periods.profiles_data,
    "profiles-rep-periods-<type>.csv" => schemas.rep_periods.profiles_data,
    "rep-periods-data.csv" => schemas.rep_periods.data,
    "rep-periods-mapping.csv" => schemas.rep_periods.mapping,
)
