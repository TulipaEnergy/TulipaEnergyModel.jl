export create_parameters_and_sets_from_file,
    create_graph, save_solution_to_file, compute_time_intervals

"""
    parameters, sets = create_parameters_and_sets_from_file(input_folder)

Returns two NamedTuples with all parameters and sets read and created from the
input files in the `input_folder`.
"""
function create_parameters_and_sets_from_file(input_folder::AbstractString)
    # Read data
    fillpath(filename) = joinpath(input_folder, filename)

    assets_data_df      = read_csv_with_schema(fillpath("assets-data.csv"), AssetData)
    assets_profiles_df  = read_csv_with_schema(fillpath("assets-profiles.csv"), AssetProfiles)
    flows_data_df       = read_csv_with_schema(fillpath("flows-data.csv"), FlowData)
    flows_profiles_df   = read_csv_with_schema(fillpath("flows-profiles.csv"), FlowProfiles)
    rep_period_df       = read_csv_with_schema(fillpath("rep-periods-data.csv"), RepPeriodData)
    assets_intervals_df = read_csv_with_schema(fillpath("assets-time-intervals.csv"), TimeIntervalsData)
    flows_intervals_df  = read_csv_with_schema(fillpath("flows-time-intervals.csv"), TimeIntervalsData)

    # Sets and subsets that depend on input data
    assets                   = assets_data_df[assets_data_df.active.==true, :].name         #assets in the energy system that are active
    assets_producer          = assets_data_df[assets_data_df.type.=="producer", :].name  #producer assets in the energy system
    assets_consumer          = assets_data_df[assets_data_df.type.=="consumer", :].name  #consumer assets in the energy system
    assets_storage           = assets_data_df[assets_data_df.type.=="storage", :].name  #storage assets in the energy system
    assets_hub               = assets_data_df[assets_data_df.type.=="hub", :].name  #hub assets in the energy system
    assets_conversion        = assets_data_df[assets_data_df.type.=="conversion", :].name  #conversion assets in the energy system
    assets_investment        = assets_data_df[assets_data_df.investable.==true, :].name  #assets with investment method in the energy system
    rep_periods              = unique(assets_profiles_df.rep_period_id)  #representative periods
    time_steps               = Dict(row.id => 1:row.num_time_steps for row in eachrow(rep_period_df))   #time steps in the RP (e.g., hours), that are dependent on RP
    flows                    = [(row.from_asset, row.to_asset) for row in eachrow(flows_data_df)]
    time_intervals_per_asset = compute_time_intervals(assets_intervals_df, assets, time_steps)
    time_intervals_per_flow  = compute_time_intervals(flows_intervals_df, flows, time_steps)

    # From balance equations:
    # Every asset a ∈ A and every rp ∈ RP will define a collection of flows, and therefore the time steps
    # can be defined a priori.
    constraints_time_periods = Dict(
        (a, rp) => begin
            compute_rp_periods(
                [
                    [
                        time_intervals_per_flow[(f, rp)] for
                        f in flows if f[1] == a || f[2] == a
                    ]
                    [time_intervals_per_asset[(a, rp)]]
                ],
            )
        end for a in assets, rp in rep_periods
    )

    # Parameters for system
    rp_weight = Dict((row.id) => row.weight for row in eachrow(rep_period_df)) #representative period weight [h]
    rp_resolution = Dict(row.id => row.resolution for row in eachrow(rep_period_df))

    # Parameter for profile of assets
    assets_profile = Dict(
        (assets[row.id], row.rep_period_id, row.time_step) => row.value for
        row in eachrow(assets_profiles_df)
    ) # asset profile [p.u.]

    # Parameter for profile of flow
    flows_profile = Dict(
        (flows[row.id], row.rep_period_id, row.time_step) => row.value for
        row in eachrow(flows_profiles_df)
    )

    # Parameters for assets
    assets_investment_cost = Dict{String,Float64}()
    assets_unit_capacity = Dict{String,Float64}()
    assets_init_capacity = Dict{String,Float64}()
    for row in eachrow(assets_data_df)
        if row.name in assets
            assets_investment_cost[row.name] = row.investment_cost
            assets_unit_capacity[row.name]   = row.capacity
            assets_init_capacity[row.name]   = row.initial_capacity
        end
    end

    # Parameters for consumers
    peak_demand = Dict{String,Float64}()
    for row in eachrow(assets_data_df)
        if row.name in assets_consumer
            peak_demand[row.name] = row.peak_demand
        end
    end

    # Parameters for storage
    initial_storage_capacity = Dict{String,Float64}()
    energy_to_power_ratio    = Dict{String,Float64}()
    for row in eachrow(assets_data_df)
        if row.name in assets_storage
            initial_storage_capacity[row.name] = row.initial_storage_capacity
            energy_to_power_ratio[row.name]    = row.energy_to_power_ratio
        end
    end

    # Read from flows data
    flows_variable_cost   = Dict{Tuple{String,String},Float64}()
    flows_investment_cost = Dict{Tuple{String,String},Float64}()
    flows_export_capacity = Dict{Tuple{String,String},Float64}()
    flows_import_capacity = Dict{Tuple{String,String},Float64}()
    flows_unit_capacity   = Dict{Tuple{String,String},Float64}()
    flows_init_capacity   = Dict{Tuple{String,String},Float64}()
    flows_efficiency      = Dict{Tuple{String,String},Float64}()
    flows_investable      = Dict{Tuple{String,String},Bool}()
    flows_is_transport    = Dict{Tuple{String,String},Bool}()
    for row in eachrow(flows_data_df)
        flows_variable_cost[(row.from_asset, row.to_asset)]   = row.variable_cost
        flows_investment_cost[(row.from_asset, row.to_asset)] = row.investment_cost
        flows_export_capacity[(row.from_asset, row.to_asset)] = row.export_capacity
        flows_import_capacity[(row.from_asset, row.to_asset)] = row.import_capacity
        flows_init_capacity[(row.from_asset, row.to_asset)]   = row.initial_capacity
        flows_efficiency[(row.from_asset, row.to_asset)]      = row.efficiency
        flows_investable[(row.from_asset, row.to_asset)]      = row.investable
        flows_is_transport[(row.from_asset, row.to_asset)]    = row.is_transport
        flows_unit_capacity[(row.from_asset, row.to_asset)]   = max(row.export_capacity, row.import_capacity)
    end

    # Define time intervals
    params = (
        assets_init_capacity = assets_init_capacity,
        assets_investment_cost = assets_investment_cost,
        assets_profile = assets_profile,
        assets_type = assets_data_df.type,
        assets_unit_capacity = assets_unit_capacity,
        flows_variable_cost = flows_variable_cost,
        flows_init_capacity = flows_init_capacity,
        flows_investment_cost = flows_investment_cost,
        flows_profile = flows_profile,
        flows_export_capacity = flows_export_capacity,
        flows_import_capacity = flows_import_capacity,
        flows_unit_capacity = flows_unit_capacity,
        flows_efficiency = flows_efficiency,
        flows_investable = flows_investable,
        flows_is_transport = flows_is_transport,
        peak_demand = peak_demand,
        initial_storage_capacity = initial_storage_capacity,
        energy_to_power_ratio = energy_to_power_ratio,
        rp_weight = rp_weight,
        rp_resolution = rp_resolution,
    )
    sets = (
        assets = assets,
        assets_consumer = assets_consumer,
        assets_investment = assets_investment,
        assets_producer = assets_producer,
        assets_storage = assets_storage,
        assets_hub = assets_hub,
        assets_conversion = assets_conversion,
        flows = flows,
        rep_periods = rep_periods,
        time_steps = time_steps,
        time_intervals_per_asset = time_intervals_per_asset,
        time_intervals_per_flow = time_intervals_per_flow,
        constraints_time_periods = constraints_time_periods,
    )

    return params, sets
end

"""
    read_csv_with_schema(file_path, schema)

Reads the csv with file_name at location path validating the data using the schema.
It is assumes that the file's header is at the second row.
The first row of the file contains some metadata information that is not used.
"""
function read_csv_with_schema(file_path, schema; csvargs...)
    # Get the schema names and types in the form of Dictionaries
    col_types = zip(fieldnames(schema), fieldtypes(schema)) |> Dict
    df = CSV.read(
        file_path,
        DataFrames.DataFrame;
        header = 2,
        types = col_types,
        strict = true,
        csvargs...,
    )

    return df
end

"""
    save_solution_to_file(output_file, v_investment, unit_capacity)

Saves the solution variable v_investment to a file "investments.csv" inside `output_file`.
The format of each row is `a,v,p*v`, where `a` is the asset indexing `v_investment`, `v`
is corresponding `v_investment` value, and `p` is the corresponding `unit_capacity` value.
"""
function save_solution_to_file(
    output_folder,
    assets_investment,
    v_investment,
    unit_capacity,
)
    # Writing the investment results to a CSV file
    output_file = joinpath(output_folder, "investments.csv")
    output_table = DataFrame(;
        a = assets_investment,
        InstalUnits = [v_investment[a] for a in assets_investment],
        InstalCap_MW = [unit_capacity[a] * v_investment[a] for a in assets_investment],
    )
    CSV.write(output_file, output_table)

    return
end

"""
    graph = create_graph(assets_path, flows_path)

Read the assets and flows data CSVs and create a graph object.
"""
function create_graph(assets_path, flows_path)
    assets_df = CSV.read(assets_path, DataFrames.DataFrame; header = 2)
    flows_df = CSV.read(flows_path, DataFrames.DataFrame; header = 2)

    num_assets = DataFrames.nrow(assets_df)
    name_to_id = Dict(zip(assets_df.name, assets_df.id))

    graph = Graphs.DiGraph(num_assets)
    for row in eachrow(flows_df)
        from_id = name_to_id[row.from_asset]
        to_id = name_to_id[row.to_asset]
        Graphs.add_edge!(graph, from_id, to_id)
    end

    return graph
end

"""
    _parse_time_intervals(Val(specification), time_step_string, rp_time_steps)

Parses the time_step_string according to the specification.
The representative period time steps (`rp_time_steps`) might not be used in the computation,
but it will be used for validation.

The specification defines what is expected from the `time_step_string`:

  - `:uniform`: The `time_step_string` should be a single number indicating the duration of
    each interval. Examples: "3", "4", "1".
  - `:explicit`: The `time_step_string` should be a semicolon-separated list of integers.
    Each integer is a duration of an interval. Examples: "3;3;3;3", "4;4;4",
    "1;1;1;1;1;1;1;1;1;1;1;1", and "3;3;4;2".
  - `:math`: The `time_step_string` should be an expression of the form `NxD+NxD…`, where `D`
    is the duration of the interval and `N` is the number of intervals. Examples: "4x3", "3x4",
    "12x1", and "2x3+1x4+1x2".

The generated intervals will be ranges (`a:b`). The first interval starts at `1`, and the last
interval ends at `length(rp_time_steps)`.

The following table summarizes the formats for a `rp_time_steps = 1:12`:

| Output                | :uniform | :explicit               | :math       |
|:--------------------- |:-------- |:----------------------- |:----------- |
| 1:3, 4:6, 7:9, 10:12  | 3        | 3;3;3;3                 | 4x3         |
| 1:4, 5:8, 9:12        | 4        | 4;4;4                   | 3x4         |
| 1:1, 2:2, …, 12:12    | 1        | 1;1;1;1;1;1;1;1;1;1;1;1 | 12x1        |
| 1:3, 4:6, 7:10, 11:12 | NA       | 3;3;4;2                 | 2x3+1x4+1x2 |

## Examples

```jldoctest
using TulipaEnergyModel
TulipaEnergyModel._parse_time_intervals(Val(:uniform), "3", 1:12)

# output

4-element Vector{UnitRange{Int64}}:
 1:3
 4:6
 7:9
 10:12
```

```jldoctest
using TulipaEnergyModel
TulipaEnergyModel._parse_time_intervals(Val(:explicit), "4;4;4", 1:12)

# output

3-element Vector{UnitRange{Int64}}:
 1:4
 5:8
 9:12
```

```jldoctest
using TulipaEnergyModel
TulipaEnergyModel._parse_time_intervals(Val(:math), "2x3+1x4+1x2", 1:12)

# output

4-element Vector{UnitRange{Int64}}:
 1:3
 4:6
 7:10
 11:12
```
"""
function _parse_time_intervals end

function _parse_time_intervals(::Val{:uniform}, time_step_string, rp_time_steps)
    duration = parse(Int, time_step_string)
    intervals = [i:i+duration-1 for i = 1:duration:length(rp_time_steps)]
    @assert intervals[end][end] == length(rp_time_steps)
    return intervals
end

function _parse_time_intervals(::Val{:explicit}, time_step_string, rp_time_steps)
    intervals = UnitRange{Int}[]
    interval_begin = 1
    interval_lengths = parse.(Int, split(time_step_string, ";"))
    for interval_length in interval_lengths
        interval_end = interval_begin + interval_length - 1
        push!(intervals, interval_begin:interval_end)
        interval_begin = interval_end + 1
    end
    @assert interval_begin - 1 == length(rp_time_steps)
    return intervals
end

function _parse_time_intervals(::Val{:math}, time_step_string, rp_time_steps)
    intervals = UnitRange{Int}[]
    interval_begin = 1
    interval_instruction = split(time_step_string, "+")
    for R in interval_instruction
        num, len = parse.(Int, split(R, "x"))
        for _ = 1:num
            interval = (1:len) .+ (interval_begin - 1)
            interval_begin += len
            push!(intervals, interval)
        end
    end
    @assert interval_begin - 1 == length(rp_time_steps)
    intervals
end

"""
    compute_time_intervals(df, elements, time_steps_per_rp)

For each element in `elements` (assets or flows), parse the time intervals defined in `df`,
a DataFrame of the file `assets-time-intervals.csv` or `flows-time-intervals.csv`.

`time_steps_per_rp` must be a dictionary indexed by `rp` and its values are the time steps of
that `rp`.

To obtain the time intervals, the columns `specification` and `time_intervals` from `df` are passed
to the function [`_parse_time_intervals`](@ref).
"""
function compute_time_intervals(df, elements, time_steps_per_rp)
    time_resolution = Dict(
        (element, rp) => begin
            N = length(time_steps)
            # Look for index in df that matches this element and rp
            j = findfirst((df.id .== element_id) .& (df.rep_period_id .== rp))
            if j === nothing
                # If there is no time interval specification, use default of 1
                [k:k for k = 1:N]
            else
                _parse_time_intervals(
                    Val(df[j, :specification]),
                    df[j, :time_intervals],
                    time_steps,
                )
            end
        end for (element_id, element) in enumerate(elements),
        (rp, time_steps) in time_steps_per_rp
    )

    return time_resolution
end
