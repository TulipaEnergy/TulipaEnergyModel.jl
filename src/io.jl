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
    graph, representative_periods, base_periods =
        create_graph_and_representative_periods_from_csv_folder(input_folder; strict = strict)
    return EnergyProblem(graph, representative_periods, base_periods)
end

"""
    graph, representative_periods, base_periods = create_graph_and_representative_periods_from_csv_folder(input_folder; strict = false)

Returns the `graph` structure that holds all data, and the `representative_periods` array.
Set strict = true to error if assets are missing from partition data.

The following files are expected to exist in the input folder:

  - `assets-data.csv`: Following the [`TulipaEnergyModel.AssetData`](@ref) specification.
  - `assets-base-periods-profiles.csv`: Following the [`TulipaEnergyModel.AssetProfiles`](@ref) specification.
  - `assets-rep-periods-profiles.csv`: Following the [`TulipaEnergyModel.AssetProfiles`](@ref) specification.
  - `assets-base-periods-partitions.csv`: Following the [`TulipaEnergyModel.AssetBasePeriodPartitionData`](@ref) specification.
  - `assets-rep-periods-partitions.csv`: Following the [`TulipaEnergyModel.AssetRepPeriodPartitionData`](@ref) specification.
  - `flows-data.csv`: Following the [`TulipaEnergyModel.FlowData`](@ref) specification.
  - `flows-base-periods-profiles.csv`: Following the [`TulipaEnergyModel.FlowProfiles`](@ref) specification.
  - `flows-rep-periods-profiles.csv`: Following the [`TulipaEnergyModel.FlowProfiles`](@ref) specification.
  - `flows-base-periods-partitions.csv`: Following the [`TulipaEnergyModel.FlowBasePeriodPartitionData`](@ref) specification.
  - `flows-rep-periods-partitions.csv`: Following the [`TulipaEnergyModel.FlowRepPeriodPartitionData`](@ref) specification.
  - `rep-periods-data.csv`: Following the [`TulipaEnergyModel.RepPeriodData`](@ref) specification.
  - `rep-periods-mapping.csv`: Following the [`TulipaEnergyModel.RepPeriodMapping`](@ref) specification.
  - `profiles-base-periods-<type>.csv`: Following the [`TulipaEnergyModel.BasePeriodsProfilesData`](@ref) specification.
  - `profiles-rep-periods-<type>.csv`: Following the [`TulipaEnergyModel.RepPeriodsProfilesData`](@ref) specification.

The returned structures are:

  - `graph`: a MetaGraph with the following information:

      + `labels(graph)`: All assets.
      + `edge_labels(graph)`: All flows, in pair format `(u, v)`, where `u` and `v` are assets.
      + `graph[a]`: A [`TulipaEnergyModel.GraphAssetData`](@ref) structure for asset `a`.
      + `graph[u, v]`: A [`TulipaEnergyModel.GraphFlowData`](@ref) structure for flow `(u, v)`.

  - `representative_periods`: An array of
    [`TulipaEnergyModel.RepresentativePeriod`](@ref) ordered by their IDs.

  - `base_periods`: Information of
    [`TulipaEnergyModel.BasePeriod`](@ref).
"""
function create_graph_and_representative_periods_from_csv_folder(
    input_folder::AbstractString;
    strict = false,
)
    # Read data
    fillpath(filename) = joinpath(input_folder, filename)

    assets_data_df = read_csv_with_schema(fillpath("assets-data.csv"), AssetData)
    flows_data_df  = read_csv_with_schema(fillpath("flows-data.csv"), FlowData)
    rep_period_df  = read_csv_with_schema(fillpath("rep-periods-data.csv"), RepPeriodData)
    rp_mapping_df  = read_csv_with_schema(fillpath("rep-periods-mapping.csv"), RepPeriodMapping)

    assets_profiles_df = Dict(
        profile_type => read_csv_with_schema(
            fillpath("assets-$profile_type-periods-profiles.csv"),
            AssetProfiles,
        ) for profile_type in ["base", "rep"]
    )
    flows_profiles_df = Dict(
        profile_type => read_csv_with_schema(
            fillpath("flows-$profile_type-periods-profiles.csv"),
            FlowProfiles,
        ) for profile_type in ["base", "rep"]
    )
    assets_partitions_df = Dict(
        "base" => read_csv_with_schema(
            fillpath("assets-base-periods-partitions.csv"),
            AssetBasePeriodPartitionData,
        ),
        "rep" => read_csv_with_schema(
            fillpath("assets-rep-periods-partitions.csv"),
            AssetRepPeriodPartitionData,
        ),
    )
    flows_partitions_df = Dict(
        "base" => read_csv_with_schema(
            fillpath("flows-base-periods-partitions.csv"),
            FlowBasePeriodPartitionData,
        ),
        "rep" => read_csv_with_schema(
            fillpath("flows-rep-periods-partitions.csv"),
            FlowRepPeriodPartitionData,
        ),
    )

    profile_input_data_type =
        Dict("base" => BasePeriodsProfilesData, "rep" => RepPeriodsProfilesData)

    profiles_dfs = Dict(
        period_type => Dict(
            begin
                key = match(Regex("profiles-$(period_type)-periods-(.*).csv"), filename)[1]
                value = read_csv_with_schema(
                    fillpath(filename),
                    profile_input_data_type[period_type],
                )
                key => value
            end for filename in readdir(input_folder) if
            startswith("profiles-$period_type-periods-")(filename)
        ) for period_type in ["rep", "base"]
    )

    # Error if partition data is missing assets (if strict)
    if strict
        missing_assets = setdiff(assets_data_df[!, "name"], assets_partitions_df["rep"][!, "asset"])
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
    # combine(groupby(rp_mapping_df, :rep_period), :weight => sum => :weight)

    # Create a dictionary of weights and populate it.
    weights = Dict{Int,Dict{Int,Float64}}()
    for sub_df ∈ groupby(rp_mapping_df, :rep_period)
        rp = first(sub_df.rep_period)
        weights[rp] = Dict(Pair.(sub_df.period, sub_df.weight))
    end

    representative_periods = [
        RepresentativePeriod(weights[row.id], row.num_time_steps, row.resolution) for
        row in eachrow(rep_period_df)
    ]

    base_periods = BasePeriod(maximum(rp_mapping_df.period), rp_mapping_df)

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
        ) for row in eachrow(assets_data_df)
    ]

    flow_data = [
        (row.from_asset, row.to_asset) => GraphFlowData(FlowData(row...)) for
        row in eachrow(flows_data_df)
    ]

    num_assets = length(asset_data)
    name_to_id = Dict(name => i for (i, name) in enumerate(assets_data_df.name))

    _graph = Graphs.DiGraph(num_assets)
    for flow in flow_data
        from_id, to_id = flow[1]
        Graphs.add_edge!(_graph, name_to_id[from_id], name_to_id[to_id])
    end

    graph = MetaGraphsNext.MetaGraph(_graph, asset_data, flow_data, nothing, nothing, nothing)

    for a in labels(graph)
        compute_assets_partitions!(
            graph[a].rep_periods_partitions,
            assets_partitions_df["rep"],
            a,
            representative_periods,
        )
    end

    for (u, v) in edge_labels(graph)
        compute_flows_partitions!(
            graph[u, v].rep_periods_partitions,
            flows_partitions_df["rep"],
            u,
            v,
            representative_periods,
        )
    end

    # For base periods, only the explicitly mentioned assets and flows have partitions defined
    for row in eachrow(assets_partitions_df["base"])
        graph[row.asset].base_periods_partitions = _parse_rp_partition(
            Val(row.specification),
            row.partition,
            1:base_periods.num_base_periods,
        )
    end

    for row in eachrow(flows_partitions_df["base"])
        graph[row.from_asset, row.to_asset].base_periods_partitions = _parse_rp_partition(
            Val(row.specification),
            row.partition,
            1:base_periods.num_base_periods,
        )
    end

    for asset_profile_row in eachrow(assets_profiles_df["rep"]) # row = asset, profile_type, profile_name
        gp = groupby( # 3. group by RP
            filter(
                row -> row.profile_name == asset_profile_row.profile_name, # 2. Filter profile_name
                profiles_dfs["rep"][asset_profile_row.profile_type], # 1. Get the profile of given type
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

    for flow_profile_row in eachrow(flows_profiles_df["rep"])
        gp = groupby(
            filter(
                row -> row.profile_name == flow_profile_row.profile_name,
                profiles_dfs["rep"][flow_profile_row.profile_type],
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

    for asset_profile_row in eachrow(assets_profiles_df["base"]) # row = asset, profile_type, profile_name
        df = filter(
            row -> row.profile_name == asset_profile_row.profile_name, # 2. Filter profile_name
            profiles_dfs["base"][asset_profile_row.profile_type], # 1. Get the profile of given type
        )
        graph[asset_profile_row.asset].base_periods_profiles[asset_profile_row.profile_type] =
            df.value
    end

    for flow_profile_row in eachrow(flows_profiles_df["base"]) # row = flow, profile_type, profile_name
        df = filter(
            row -> row.profile_name == flow_profile_row.profile_name, # 2. Filter profile_name
            profiles_dfs["base"][flow_profile_row.profile_type], # 1. Get the profile of given type
        )
        graph[flow_profile_row.from_asset, flow_profile_row.to_asset].base_periods_profiles[flow_profile_row.profile_type] =
            df.value
    end
    return graph, representative_periods, base_periods
end

"""
    read_csv_with_schema(file_path, schema)

Reads the csv with file_name at location path validating the data using the schema.
It assumes that the file's header is at the second row.
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
    and `time_step`. Since the flow is in power, the value at a time step is equal to the value
    at the corresponding time block, i.e., if flow[1:3] = 30, then flow[1] = flow[2] = flow[3] = 30.
  - `storage-level.csv`: The value of each storage level, per `asset`, `rp` representative period,
    and `time_step`. Since the storage level is in energy, the value at a time step is a
    proportional fraction of the value at the corresponding time block, i.e., if level[1:3] = 30,
    then level[1] = level[2] = level[3] = 10.
"""
function save_solution_to_file(output_folder, graph, dataframes, solution)
    output_file = joinpath(output_folder, "assets-investments.csv")
    output_table = DataFrame(; asset = String[], InstalUnits = Float64[], InstalCap_MW = Float64[])
    for a in labels(graph)
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
        from_asset = String[],
        to_asset = String[],
        InstalUnits = Float64[],
        InstalCap_MW = Float64[],
    )
    for (u, v) in edge_labels(graph)
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
    I.e., if a row shows `time_block = 3:5` and `value = 30`, then we transform into
    three rows with values `time_step = [3, 4, 5]` and `value` equal to 30 / 3 for storage,
    or 30 for flows.
    =#

    output_file = joinpath(output_folder, "flows.csv")
    output_table = select(dataframes[:flows], :from, :to, :rp, :time_block => :time_step)
    output_table.value = solution.flow
    output_table = flatten(
        transform(
            output_table,
            [:time_step, :value] =>
                ByRow((time_block, value) -> begin # transform each row using these two columns
                    n = length(time_block)
                    (time_block, Iterators.repeated(value, n)) # e.g., (3:5, [30, 30, 30])
                end) => [:time_step, :value],
        ),
        [:time_step, :value], # flatten, e.g., [(3, 30), (4, 30), (5, 30)]
    )
    output_table |> CSV.write(output_file)

    output_file = joinpath(output_folder, "storage-level-intra-rp.csv")
    output_table =
        select(dataframes[:lowest_storage_level_intra_rp], :asset, :rp, :time_block => :time_step)
    output_table.value = solution.storage_level_intra_rp
    output_table = flatten(
        transform(
            output_table,
            [:time_step, :value] =>
                ByRow((time_block, value) -> begin
                        n = length(time_block)
                        (time_block, Iterators.repeated(value / n, n))
                    end) => [:time_step, :value],
        ),
        [:time_step, :value],
    )
    output_table |> CSV.write(output_file)

    output_file = joinpath(output_folder, "storage-level-inter-rp.csv")
    output_table =
        select(dataframes[:storage_level_inter_rp], :asset, :base_period_block => :time_step)
    output_table.value = solution.storage_level_inter_rp
    output_table = flatten(
        transform(
            output_table,
            [:time_step, :value] =>
                ByRow(
                    (base_period_block, value) -> begin
                        n = length(base_period_block)
                        (base_period_block, Iterators.repeated(value / n, n))
                    end,
                ) => [:time_step, :value],
        ),
        [:time_step, :value],
    )
    output_table |> CSV.write(output_file)

    return
end

"""
    _parse_rp_partition(Val(specification), time_step_string, rp_time_steps)

Parses the time_step_string according to the specification.
The representative period time steps (`rp_time_steps`) might not be used in the computation,
but it will be used for validation.

The specification defines what is expected from the `time_step_string`:

  - `:uniform`: The `time_step_string` should be a single number indicating the duration of
    each block. Examples: "3", "4", "1".
  - `:explicit`: The `time_step_string` should be a semicolon-separated list of integers.
    Each integer is a duration of a block. Examples: "3;3;3;3", "4;4;4",
    "1;1;1;1;1;1;1;1;1;1;1;1", and "3;3;4;2".
  - `:math`: The `time_step_string` should be an expression of the form `NxD+NxD…`, where `D`
    is the duration of the block and `N` is the number of blocks. Examples: "4x3", "3x4",
    "12x1", and "2x3+1x4+1x2".

The generated blocks will be ranges (`a:b`). The first block starts at `1`, and the last
block ends at `length(rp_time_steps)`.

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

function _parse_rp_partition(::Val{:uniform}, time_step_string, rp_time_steps)
    duration = parse(Int, time_step_string)
    partition = [i:i+duration-1 for i ∈ 1:duration:length(rp_time_steps)]
    @assert partition[end][end] == length(rp_time_steps)
    return partition
end

function _parse_rp_partition(::Val{:explicit}, time_step_string, rp_time_steps)
    partition = UnitRange{Int}[]
    block_begin = 1
    block_lengths = parse.(Int, split(time_step_string, ";"))
    for block_length in block_lengths
        block_end = block_begin + block_length - 1
        push!(partition, block_begin:block_end)
        block_begin = block_end + 1
    end
    @assert block_begin - 1 == length(rp_time_steps)
    return partition
end

function _parse_rp_partition(::Val{:math}, time_step_string, rp_time_steps)
    partition = UnitRange{Int}[]
    block_begin = 1
    block_instruction = split(time_step_string, "+")
    for R in block_instruction
        num, len = parse.(Int, split(R, "x"))
        for _ ∈ 1:num
            block = (1:len) .+ (block_begin - 1)
            block_begin += len
            push!(partition, block)
        end
    end
    @assert block_begin - 1 == length(rp_time_steps)
    return partition
end

"""
    compute_assets_partitions!(partitions, df, a, representative_periods)

Parses the time blocks in the DataFrame `df` for the asset `a` and every
representative period in the `time_steps_per_rp` dictionary, modifying the
input `partitions`.

`partitions` must be a dictionary indexed by the representative periods,
possibly empty.

`time_steps_per_rp` must be a dictionary indexed by `rp` and its values are the
time steps of that `rp`.

To obtain the partitions, the columns `specification` and `partition` from `df`
are passed to the function [`_parse_rp_partition`](@ref).
"""
function compute_assets_partitions!(partitions, df, a, representative_periods)
    for (rp_id, rp) in enumerate(representative_periods)
        # Look for index in df that matches this asset and rp
        j = findfirst((df.asset .== a) .& (df.rep_period .== rp_id))
        partitions[rp_id] = if j === nothing
            N = length(rp.time_steps)
            # If there is no time block specification, use default of 1
            [k:k for k ∈ 1:N]
        else
            _parse_rp_partition(Val(df[j, :specification]), df[j, :partition], rp.time_steps)
        end
    end
end

"""
    compute_flows_partitions!(partitions, df, u, v, representative_periods)

Parses the time blocks in the DataFrame `df` for the flow `(u, v)` and every
representative period in the `time_steps_per_rp` dictionary, modifying the
input `partitions`.

`partitions` must be a dictionary indexed by the representative periods,
possibly empty.

`time_steps_per_rp` must be a dictionary indexed by `rp` and its values are the
time steps of that `rp`.

To obtain the partitions, the columns `specification` and `partition` from `df`
are passed to the function [`_parse_rp_partition`](@ref).
"""
function compute_flows_partitions!(partitions, df, u, v, representative_periods)
    for (rp_id, rp) in enumerate(representative_periods)
        # Look for index in df that matches this asset and rp
        j = findfirst((df.from_asset .== u) .& (df.to_asset .== v) .& (df.rep_period .== rp_id))
        partitions[rp_id] = if j === nothing
            N = length(rp.time_steps)
            # If there is no time block specification, use default of 1
            [k:k for k ∈ 1:N]
        else
            _parse_rp_partition(Val(df[j, :specification]), df[j, :partition], rp.time_steps)
        end
    end
end
