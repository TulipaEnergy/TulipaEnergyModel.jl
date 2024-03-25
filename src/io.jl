export create_energy_problem_from_csv_folder,
    create_graph_and_representative_periods_from_csv_folder,
    save_solution_to_file,
    compute_assets_partitions!,
    compute_flows_partitions!

"""
    energy_problem = create_energy_problem_from_csv_folder(input_folder; strict = false)

Returns the [`TulipaEnergyModel.EnergyProblem`](@ref) reading all data from CSV files
in the `input_folder`.
This is a wrapper around `create_graph_and_representative_periods_from_csv_folder` that creates
the `EnergyProblem` structure.
Set strict = true to error if assets are missing from partition data.
"""
function create_energy_problem_from_csv_folder(input_folder::AbstractString; strict = false)
    graph, representative_periods, timeframe =
        create_graph_and_representative_periods_from_csv_folder(input_folder; strict = strict)
    return EnergyProblem(graph, representative_periods, timeframe)
end

"""
    graph, representative_periods, timeframe = create_graph_and_representative_periods_from_csv_folder(input_folder; strict = false)

Returns the `graph` structure that holds all data, and the `representative_periods` array.
Set strict = true to error if assets are missing from partition data.

The following files are expected to exist in the input folder:

  - `assets-timeframe-partitions.csv`: Following the schema `schemas.assets.timeframe_partition`.
  - `assets-data.csv`: Following the schema `schemas.assets.data`.
  - `assets-timeframe-profiles.csv`: Following the schema `schemas.assets.profiles_reference`.
  - `assets-rep-periods-profiles.csv`: Following the schema `schemas.assets.profiles_reference`.
  - `assets-rep-periods-partitions.csv`: Following the schema `schemas.assets.rep_periods_partition`.
  - `flows-data.csv`: Following the schema `schemas.flows.data`.
  - `flows-rep-periods-profiles.csv`: Following the schema `schemas.flows.profiles_reference`.
  - `flows-rep-periods-partitions.csv`: Following the schema `schemas.flows.rep_periods_partition`.
  - `profiles-timeframe-<type>.csv`: Following the schema `schemas.timeframe.profiles_data`.
  - `profiles-rep-periods-<type>.csv`: Following the schema `schemas.rep_periods.profiles_data`.
  - `rep-periods-data.csv`: Following the schema `schemas.rep_periods.data`.
  - `rep-periods-mapping.csv`: Following the schema `schemas.rep_periods.mapping`.

The returned structures are:

  - `graph`: a MetaGraph with the following information:

      + `labels(graph)`: All assets.
      + `edge_labels(graph)`: All flows, in pair format `(u, v)`, where `u` and `v` are assets.
      + `graph[a]`: A [`TulipaEnergyModel.GraphAssetData`](@ref) structure for asset `a`.
      + `graph[u, v]`: A [`TulipaEnergyModel.GraphFlowData`](@ref) structure for flow `(u, v)`.

  - `representative_periods`: An array of
    [`TulipaEnergyModel.RepresentativePeriod`](@ref) ordered by their IDs.

  - `timeframe`: Information of
    [`TulipaEnergyModel.Timeframe`](@ref).
"""
function create_graph_and_representative_periods_from_csv_folder(
    input_folder::AbstractString;
    strict = false,
)
    df_assets_data = read_csv_with_implicit_schema(input_folder, "assets-data.csv")
    df_flows_data  = read_csv_with_implicit_schema(input_folder, "flows-data.csv")
    df_rep_period  = read_csv_with_implicit_schema(input_folder, "rep-periods-data.csv")
    df_rp_mapping  = read_csv_with_implicit_schema(input_folder, "rep-periods-mapping.csv")

    df_assets_profiles = Dict(
        profile_type =>
            read_csv_with_implicit_schema(input_folder, "assets-$profile_type-profiles.csv") for
        profile_type in ["timeframe", "rep-periods"]
    )
    df_flows_profiles =
        read_csv_with_implicit_schema(input_folder, "flows-rep-periods-profiles.csv")
    df_assets_partitions = Dict(
        "timeframe" =>
            read_csv_with_implicit_schema(input_folder, "assets-timeframe-partitions.csv"),
        "rep-periods" =>
            read_csv_with_implicit_schema(input_folder, "assets-rep-periods-partitions.csv"),
    )
    df_flows_partitions =
        read_csv_with_implicit_schema(input_folder, "flows-rep-periods-partitions.csv")

    df_profiles = Dict(
        period_type => Dict(
            begin
                regex = "profiles-$(period_type)-(.*).csv"
                # Sanitized key: Spaces and dashes convert to underscore
                key = Symbol(replace(match(Regex(regex), filename)[1], r"[ -]" => "_"))
                value = read_csv_with_implicit_schema(input_folder, filename)
                key => value
            end for filename in readdir(input_folder) if
            startswith("profiles-$period_type-")(filename)
        ) for period_type in ["rep-periods", "timeframe"]
    )

    # Error if partition data is missing assets (if strict)
    if strict
        missing_assets =
            setdiff(df_assets_data[!, :name], df_assets_partitions["rep-periods"][!, :asset])
        if length(missing_assets) > 0
            msg = "Error: Partition data missing for these assets: \n"
            for a in missing_assets
                msg *= "- $a\n"
            end
            msg *= "To assume missing asset resolutions follow the representative period's time resolution, set strict = false.\n"

            error(msg)
        end
    end

    # Sets and subsets that depend on input data

    # TODO: Depending on the outcome of issue #294, this can be done more efficiently with DataFrames, e.g.,
    # combine(groupby(df_rp_mapping, :rep_period), :weight => sum => :weight)

    # Create a dictionary of weights and populate it.
    weights = Dict{Int,Dict{Int,Float64}}()
    for sub_df ∈ DataFrames.groupby(df_rp_mapping, :rep_period)
        rp = first(sub_df.rep_period)
        weights[rp] = Dict(Pair.(sub_df.period, sub_df.weight))
    end

    representative_periods = [
        RepresentativePeriod(weights[row.id], row.num_timesteps, row.resolution) for
        row in eachrow(df_rep_period)
    ]

    timeframe = Timeframe(maximum(df_rp_mapping.period), df_rp_mapping)

    asset_data = [
        row.name => GraphAssetData(
            row.type,
            row.investable,
            row.investment_integer,
            row.investment_cost,
            row.investment_limit,
            row.capacity,
            row.initial_capacity,
            row.peak_demand,
            row.is_seasonal,
            row.storage_inflows,
            row.initial_storage_capacity,
            row.initial_storage_level,
            row.energy_to_power_ratio,
        ) for row in eachrow(df_assets_data)
    ]

    flow_data = [
        (row.from_asset, row.to_asset) => GraphFlowData(
            row.carrier,
            row.active,
            row.is_transport,
            row.investable,
            row.investment_integer,
            row.variable_cost,
            row.investment_cost,
            row.investment_limit,
            row.capacity,
            row.initial_export_capacity,
            row.initial_import_capacity,
            row.efficiency,
        ) for row in eachrow(df_flows_data)
    ]

    num_assets = length(asset_data)
    name_to_id = Dict(name => i for (i, name) in enumerate(df_assets_data.name))

    _graph = Graphs.DiGraph(num_assets)
    for flow in flow_data
        from_id, to_id = flow[1]
        Graphs.add_edge!(_graph, name_to_id[from_id], name_to_id[to_id])
    end

    graph = MetaGraphsNext.MetaGraph(_graph, asset_data, flow_data, nothing, nothing, nothing)

    for a in MetaGraphsNext.labels(graph)
        compute_assets_partitions!(
            graph[a].rep_periods_partitions,
            df_assets_partitions["rep-periods"],
            a,
            representative_periods,
        )
    end

    for (u, v) in MetaGraphsNext.edge_labels(graph)
        compute_flows_partitions!(
            graph[u, v].rep_periods_partitions,
            df_flows_partitions,
            u,
            v,
            representative_periods,
        )
    end

    # For timeframe, only the assets where is_seasonal is true are selected
    for row in eachrow(df_assets_data)
        if row.is_seasonal
            # Search for this row in the df_assets_partitions and error if it is not found
            found = false
            for partition_row in eachrow(df_assets_partitions["timeframe"])
                if row.name == partition_row.asset
                    graph[row.name].timeframe_partitions = _parse_rp_partition(
                        Val(partition_row.specification),
                        partition_row.partition,
                        1:timeframe.num_periods,
                    )
                    found = true
                    break
                end
            end
            if !found
                graph[row.name].timeframe_partitions =
                    _parse_rp_partition(Val(:uniform), "1", 1:timeframe.num_periods)
            end
        end
    end

    for asset_profile_row in eachrow(df_assets_profiles["rep-periods"]) # row = asset, profile_type, profile_name
        gp = DataFrames.groupby( # 3. group by RP
            filter(
                row -> row.profile_name == asset_profile_row.profile_name, # 2. Filter profile_name
                df_profiles["rep-periods"][asset_profile_row.profile_type], # 1. Get the profile of given type
            ),
            :rep_period,
        )
        for ((rp,), df) in pairs(gp) # Loop over filtered DFs by RP
            graph[asset_profile_row.asset].rep_periods_profiles[(
                asset_profile_row.profile_type,
                rp,
            )] = df.value
        end
    end

    for flow_profile_row in eachrow(df_flows_profiles)
        gp = DataFrames.groupby(
            filter(
                row -> row.profile_name == flow_profile_row.profile_name,
                df_profiles["rep-periods"][flow_profile_row.profile_type],
            ),
            :rep_period,
        )
        for ((rp,), df) in pairs(gp)
            graph[flow_profile_row.from_asset, flow_profile_row.to_asset].rep_periods_profiles[(
                flow_profile_row.profile_type,
                rp,
            )] = df.value
        end
    end

    for asset_profile_row in eachrow(df_assets_profiles["timeframe"]) # row = asset, profile_type, profile_name
        df = filter(
            row -> row.profile_name == asset_profile_row.profile_name, # 2. Filter profile_name
            df_profiles["timeframe"][asset_profile_row.profile_type], # 1. Get the profile of given type
        )
        graph[asset_profile_row.asset].timeframe_profiles[asset_profile_row.profile_type] = df.value
    end

    return graph, representative_periods, timeframe
end

"""
    read_csv_with_schema(file_path, schema; csvargs...)

Reads the csv at `file_path` validating the data using the `schema`.
It assumes that the file's header is at the second row.
The first row of the file contains some metadata information that is not used.
Additional keywords arguments can be passed to `CSV.read`.
"""
function read_csv_with_schema(file_path, schema; csvargs...)
    df = CSV.read(file_path, DataFrame; header = 2, types = schema, strict = true, csvargs...)

    return df
end

"""
    read_csv_with_implicit_schema(dir, filename; csvargs...)

Reads the csv at direcory `dir` named `filename` validating the data using a schema
chosen based on `filename`.
The function [`read_csv_with_schema`](@ref) is responsible for actually reading the file.
Additional keywords arguments can be passed to `CSV.read`.
"""
function read_csv_with_implicit_schema(dir, filename; csvargs...)
    schema = if haskey(schema_per_file, filename)
        schema_per_file[filename]
    else
        if startswith("profiles-timeframe")(filename)
            schema_per_file["profiles-timeframe-<type>.csv"]
        elseif startswith("profiles-rep-periods")(filename)
            schema_per_file["profiles-rep-periods-<type>.csv"]
        else
            error("No implicit schema for file $filename")
        end
    end
    read_csv_with_schema(joinpath(dir, filename), schema)
end

"""
    save_solution_to_file(output_folder, energy_problem)

Saves the solution from `energy_problem` in CSV files inside `output_file`.
"""
function save_solution_to_file(output_folder, energy_problem::EnergyProblem)
    if !energy_problem.solved
        error("The energy_problem has not been solved yet.")
    end
    save_solution_to_file(
        output_folder,
        energy_problem.graph,
        energy_problem.dataframes,
        energy_problem.solution,
    )
end

"""
    save_solution_to_file(output_file, graph, solution)

Saves the solution in CSV files inside `output_folder`.

The following files are created:

  - `assets-investment.csv`: The format of each row is `a,v,p*v`, where `a` is the asset name,
    `v` is the corresponding asset investment value, and `p` is the corresponding
    capacity value. Only investable assets are included.
  - `flows-investment.csv`: Similar to `assets-investment.csv`, but for flows.
  - `flows.csv`: The value of each flow, per `(from, to)` flow, `rp` representative period
    and `timestep`. Since the flow is in power, the value at a time step is equal to the value
    at the corresponding time block, i.e., if flow[1:3] = 30, then flow[1] = flow[2] = flow[3] = 30.
  - `storage-level.csv`: The value of each storage level, per `asset`, `rp` representative period,
    and `timestep`. Since the storage level is in energy, the value at a time step is a
    proportional fraction of the value at the corresponding time block, i.e., if level[1:3] = 30,
    then level[1] = level[2] = level[3] = 10.
"""
function save_solution_to_file(output_folder, graph, dataframes, solution)
    output_file = joinpath(output_folder, "assets-investments.csv")
    output_table = DataFrame(; asset = Symbol[], InstalUnits = Float64[], InstalCap_MW = Float64[])
    for a in MetaGraphsNext.labels(graph)
        if !graph[a].investable
            continue
        end
        investment = solution.assets_investment[a]
        capacity = graph[a].capacity
        push!(output_table, (a, investment, capacity * investment))
    end
    CSV.write(output_file, output_table)

    output_file = joinpath(output_folder, "flows-investments.csv")
    output_table = DataFrame(;
        from_asset = Symbol[],
        to_asset = Symbol[],
        InstalUnits = Float64[],
        InstalCap_MW = Float64[],
    )
    for (u, v) in MetaGraphsNext.edge_labels(graph)
        if !graph[u, v].investable
            continue
        end
        investment = solution.flows_investment[(u, v)]
        capacity = graph[u, v].capacity
        push!(output_table, (u, v, investment, capacity * investment))
    end
    CSV.write(output_file, output_table)

    #=
    In both cases below, we select the relevant columns from the existing dataframes,
    then, we append the solution column.
    After that, we transform and flatten, by rows, the time block values into a long version.
    I.e., if a row shows `timesteps_block = 3:5` and `value = 30`, then we transform into
    three rows with values `timestep = [3, 4, 5]` and `value` equal to 30 / 3 for storage,
    or 30 for flows.
    =#

    output_file = joinpath(output_folder, "flows.csv")
    output_table =
        DataFrames.select(dataframes[:flows], :from, :to, :rp, :timesteps_block => :timestep)
    output_table.value = solution.flow
    output_table = DataFrames.flatten(
        DataFrames.transform(
            output_table,
            [:timestep, :value] =>
                DataFrames.ByRow(
                    (timesteps_block, value) -> begin # transform each row using these two columns
                        n = length(timesteps_block)
                        (timesteps_block, Iterators.repeated(value, n)) # e.g., (3:5, [30, 30, 30])
                    end,
                ) => [:timestep, :value],
        ),
        [:timestep, :value], # flatten, e.g., [(3, 30), (4, 30), (5, 30)]
    )
    output_table |> CSV.write(output_file)

    output_file = joinpath(output_folder, "storage-level-intra-rp.csv")
    output_table = DataFrames.select(
        dataframes[:lowest_storage_level_intra_rp],
        :asset,
        :rp,
        :timesteps_block => :timestep,
    )
    output_table.value = solution.storage_level_intra_rp
    if !isempty(output_table.asset)
        output_table = DataFrames.combine(DataFrames.groupby(output_table, :asset)) do subgroup
            _check_initial_storage_level!(subgroup, graph)
            _interpolate_storage_level!(subgroup, :timestep)
        end
    end
    output_table |> CSV.write(output_file)

    output_file = joinpath(output_folder, "storage-level-inter-rp.csv")
    output_table =
        DataFrames.select(dataframes[:storage_level_inter_rp], :asset, :periods_block => :period)
    output_table.value = solution.storage_level_inter_rp
    if !isempty(output_table.asset)
        output_table = DataFrames.combine(DataFrames.groupby(output_table, :asset)) do subgroup
            _check_initial_storage_level!(subgroup, graph)
            _interpolate_storage_level!(subgroup, :period)
        end
    end
    output_table |> CSV.write(output_file)
    return
end

"""
    _check_initial_storage_level!(df)

Determine the starting value for the initial storage level for interpolating the storage level.
If there is no initial storage level given, we will use the final storage level.
Otherwise, we use the given initial storage level.
"""
function _check_initial_storage_level!(df, graph)
    initial_storage_level = graph[unique(df.asset)[1]].initial_storage_level
    if ismissing(initial_storage_level)
        df[!, :processed_value] = [df.value[end]; df[1:end-1, :value]]
    else
        df[!, :processed_value] = [initial_storage_level; df[1:end-1, :value]]
    end
end

"""
    _interpolate_storage_level!(df, time_column::Symbol)

Tranform the storage level dataframe from grouped timesteps or periods to incremental ones by interpolation.
The starting value is the value of the previous grouped timesteps or periods or the initial value.
The ending value is the value for the grouped timesteps or periods.
"""
function _interpolate_storage_level!(df, time_column::Symbol)
    DataFrames.flatten(
        DataFrames.transform(
            df,
            [time_column, :value, :processed_value] =>
                DataFrames.ByRow(
                    (period, value, start_value) -> begin
                        n = length(period)
                        interpolated_values = range(start_value, value, n + 1)
                        (period, value, interpolated_values[2:end])
                    end,
                ) => [time_column, :value, :processed_value],
        ),
        [time_column, :processed_value],
    )
end

"""
    _parse_rp_partition(Val(specification), timestep_string, rp_timesteps)

Parses the timestep_string according to the specification.
The representative period time steps (`rp_timesteps`) might not be used in the computation,
but it will be used for validation.

The specification defines what is expected from the `timestep_string`:

  - `:uniform`: The `timestep_string` should be a single number indicating the duration of
    each block. Examples: "3", "4", "1".
  - `:explicit`: The `timestep_string` should be a semicolon-separated list of integers.
    Each integer is a duration of a block. Examples: "3;3;3;3", "4;4;4",
    "1;1;1;1;1;1;1;1;1;1;1;1", and "3;3;4;2".
  - `:math`: The `timestep_string` should be an expression of the form `NxD+NxD…`, where `D`
    is the duration of the block and `N` is the number of blocks. Examples: "4x3", "3x4",
    "12x1", and "2x3+1x4+1x2".

The generated blocks will be ranges (`a:b`). The first block starts at `1`, and the last
block ends at `length(rp_timesteps)`.

The following table summarizes the formats for a `rp_timesteps = 1:12`:

| Output                | :uniform | :explicit               | :math       |
|:--------------------- |:-------- |:----------------------- |:----------- |
| 1:3, 4:6, 7:9, 10:12  | 3        | 3;3;3;3                 | 4x3         |
| 1:4, 5:8, 9:12        | 4        | 4;4;4                   | 3x4         |
| 1:1, 2:2, …, 12:12    | 1        | 1;1;1;1;1;1;1;1;1;1;1;1 | 12x1        |
| 1:3, 4:6, 7:10, 11:12 | NA       | 3;3;4;2                 | 2x3+1x4+1x2 |

## Examples

```jldoctest
using TulipaEnergyModel
TulipaEnergyModel._parse_rp_partition(Val(:uniform), "3", 1:12)

# output

4-element Vector{UnitRange{Int64}}:
 1:3
 4:6
 7:9
 10:12
```

```jldoctest
using TulipaEnergyModel
TulipaEnergyModel._parse_rp_partition(Val(:explicit), "4;4;4", 1:12)

# output

3-element Vector{UnitRange{Int64}}:
 1:4
 5:8
 9:12
```

```jldoctest
using TulipaEnergyModel
TulipaEnergyModel._parse_rp_partition(Val(:math), "2x3+1x4+1x2", 1:12)

# output

4-element Vector{UnitRange{Int64}}:
 1:3
 4:6
 7:10
 11:12
```
"""
function _parse_rp_partition end

function _parse_rp_partition(::Val{:uniform}, timestep_string, rp_timesteps)
    duration = parse(Int, timestep_string)
    partition = [i:i+duration-1 for i ∈ 1:duration:length(rp_timesteps)]
    @assert partition[end][end] == length(rp_timesteps)
    return partition
end

function _parse_rp_partition(::Val{:explicit}, timestep_string, rp_timesteps)
    partition = UnitRange{Int}[]
    block_begin = 1
    block_lengths = parse.(Int, split(timestep_string, ";"))
    for block_length in block_lengths
        block_end = block_begin + block_length - 1
        push!(partition, block_begin:block_end)
        block_begin = block_end + 1
    end
    @assert block_begin - 1 == length(rp_timesteps)
    return partition
end

function _parse_rp_partition(::Val{:math}, timestep_string, rp_timesteps)
    partition = UnitRange{Int}[]
    block_begin = 1
    block_instruction = split(timestep_string, "+")
    for R in block_instruction
        num, len = parse.(Int, split(R, "x"))
        for _ ∈ 1:num
            block = (1:len) .+ (block_begin - 1)
            block_begin += len
            push!(partition, block)
        end
    end
    @assert block_begin - 1 == length(rp_timesteps)
    return partition
end

"""
    compute_assets_partitions!(partitions, df, a, representative_periods)

Parses the time blocks in the DataFrame `df` for the asset `a` and every
representative period in the `timesteps_per_rp` dictionary, modifying the
input `partitions`.

`partitions` must be a dictionary indexed by the representative periods,
possibly empty.

`timesteps_per_rp` must be a dictionary indexed by `rp` and its values are the
time steps of that `rp`.

To obtain the partitions, the columns `specification` and `partition` from `df`
are passed to the function [`_parse_rp_partition`](@ref).
"""
function compute_assets_partitions!(partitions, df, a, representative_periods)
    for (rp_id, rp) in enumerate(representative_periods)
        # Look for index in df that matches this asset and rp
        j = findfirst((df.asset .== a) .& (df.rep_period .== rp_id))
        partitions[rp_id] = if j === nothing
            N = length(rp.timesteps)
            # If there is no time block specification, use default of 1
            [k:k for k ∈ 1:N]
        else
            _parse_rp_partition(Val(df[j, :specification]), df[j, :partition], rp.timesteps)
        end
    end
end

"""
    compute_flows_partitions!(partitions, df, u, v, representative_periods)

Parses the time blocks in the DataFrame `df` for the flow `(u, v)` and every
representative period in the `timesteps_per_rp` dictionary, modifying the
input `partitions`.

`partitions` must be a dictionary indexed by the representative periods,
possibly empty.

`timesteps_per_rp` must be a dictionary indexed by `rp` and its values are the
time steps of that `rp`.

To obtain the partitions, the columns `specification` and `partition` from `df`
are passed to the function [`_parse_rp_partition`](@ref).
"""
function compute_flows_partitions!(partitions, df, u, v, representative_periods)
    for (rp_id, rp) in enumerate(representative_periods)
        # Look for index in df that matches this asset and rp
        j = findfirst((df.from_asset .== u) .& (df.to_asset .== v) .& (df.rep_period .== rp_id))
        partitions[rp_id] = if j === nothing
            N = length(rp.timesteps)
            # If there is no time block specification, use default of 1
            [k:k for k ∈ 1:N]
        else
            _parse_rp_partition(Val(df[j, :specification]), df[j, :partition], rp.timesteps)
        end
    end
end
