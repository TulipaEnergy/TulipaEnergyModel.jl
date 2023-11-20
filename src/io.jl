export create_energy_model_from_csv_folder,
    create_graph, save_solution_to_file, compute_assets_partitions!, compute_flows_partitions!

"""
    energy_problem = create_energy_model_from_csv_folder(input_folder)

Returns the [`TulipaEnergyModel.EnergyProblem`](@ref) reading all data from CSV files
in the `input_folder`.
"""
function create_energy_model_from_csv_folder(input_folder::AbstractString)
    # Read data
    fillpath(filename) = joinpath(input_folder, filename)

    assets_data_df       = read_csv_with_schema(fillpath("assets-data.csv"), AssetData)
    assets_profiles_df   = read_csv_with_schema(fillpath("assets-profiles.csv"), AssetProfiles)
    flows_data_df        = read_csv_with_schema(fillpath("flows-data.csv"), FlowData)
    flows_profiles_df    = read_csv_with_schema(fillpath("flows-profiles.csv"), FlowProfiles)
    rep_period_df        = read_csv_with_schema(fillpath("rep-periods-data.csv"), RepPeriodData)
    assets_partitions_df = read_csv_with_schema(fillpath("assets-partitions.csv"), AssetPartitionData)
    flows_partitions_df  = read_csv_with_schema(fillpath("flows-partitions.csv"), FlowPartitionData)

    # Sets and subsets that depend on input data
    representative_periods = [
        RepresentativePeriod(row.weight, row.num_time_steps, row.resolution) for
        row in eachrow(rep_period_df)
    ]

    asset_data = [
        row.name => GraphAssetData(
            row.type,
            row.investable,
            row.investment_cost,
            row.capacity,
            row.initial_capacity,
            row.peak_demand,
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
            graph[a].partitions,
            assets_partitions_df,
            a,
            representative_periods,
        )
    end

    for (u, v) in edge_labels(graph)
        compute_flows_partitions!(
            graph[u, v].partitions,
            flows_partitions_df,
            u,
            v,
            representative_periods,
        )
    end

    # Unique (asset, rp) combination on the profiles:
    asset_and_rp_with_profiles = assets_profiles_df[:, [:asset, :rep_period_id]]
    for (a, rp_id) in eachrow(asset_and_rp_with_profiles)
        # Get all profile data for asset=id and rp=rp_id
        matching = (assets_profiles_df.asset .== a) .& (assets_profiles_df.rep_period_id .== rp_id)
        # Sort the matching data by time_step and get the values
        profile_data = sort(assets_profiles_df[matching, :], :time_step).value
        @assert length(profile_data) == length(representative_periods[rp_id].time_steps)
        graph[a].profiles[rp_id] = profile_data
    end

    # Unique (flow, rp) combination on the profiles:
    flow_and_rp_with_profiles = flows_profiles_df[:, [:from_asset, :to_asset, :rep_period_id]]
    for (u, v, rp_id) in eachrow(flow_and_rp_with_profiles)
        matching =
            (flows_profiles_df.from_asset .== u) .&
            (flows_profiles_df.to_asset .== v) .&
            (flows_profiles_df.rep_period_id .== rp_id)
        profile_data = sort(flows_profiles_df[matching, :], :time_step).value
        @assert length(profile_data) == length(representative_periods[rp_id].time_steps)
        graph[u, v].profiles[rp_id] = profile_data
    end

    return EnergyProblem(graph, representative_periods)
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
function save_solution_to_file(output_folder, assets_investment, v_investment, unit_capacity)
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
    name_to_id = Dict(name => i for (i, name) in enumerate(assets_df.name))

    graph = Graphs.DiGraph(num_assets)
    for row in eachrow(flows_df)
        from_id = name_to_id[row.from_asset]
        to_id = name_to_id[row.to_asset]
        Graphs.add_edge!(graph, from_id, to_id)
    end

    return graph
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
    partition = [i:i+duration-1 for i = 1:duration:length(rp_time_steps)]
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
        for _ = 1:num
            block = (1:len) .+ (block_begin - 1)
            block_begin += len
            push!(partition, block)
        end
    end
    @assert block_begin - 1 == length(rp_time_steps)
    partition
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
        j = findfirst((df.asset .== a) .& (df.rep_period_id .== rp_id))
        partitions[rp_id] = if j === nothing
            N = length(rp.time_steps)
            # If there is no time block specification, use default of 1
            [k:k for k = 1:N]
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
        j = findfirst((df.from_asset .== u) .& (df.to_asset .== v) .& (df.rep_period_id .== rp_id))
        partitions[rp_id] = if j === nothing
            N = length(rp.time_steps)
            # If there is no time block specification, use default of 1
            [k:k for k = 1:N]
        else
            _parse_rp_partition(Val(df[j, :specification]), df[j, :partition], rp.time_steps)
        end
    end
end
