export create_parameters_and_sets_from_file,
    create_graph, save_solution_to_file, compute_rp_partitions

"""
    parameters, sets = create_parameters_and_sets_from_file(input_folder)

Returns two NamedTuples with all parameters and sets read and created from the
input files in the `input_folder`.
"""
function create_parameters_and_sets_from_file(input_folder::AbstractString)
    # Read data
    fillpath(filename) = joinpath(input_folder, filename)

    assets_data_df       = read_csv_with_schema(fillpath("assets-data.csv"), AssetData)
    assets_profiles_df   = read_csv_with_schema(fillpath("assets-profiles.csv"), AssetProfiles)
    flows_data_df        = read_csv_with_schema(fillpath("flows-data.csv"), FlowData)
    flows_profiles_df    = read_csv_with_schema(fillpath("flows-profiles.csv"), FlowProfiles)
    rep_period_df        = read_csv_with_schema(fillpath("rep-periods-data.csv"), RepPeriodData)
    assets_partitions_df = read_csv_with_schema(fillpath("assets-partitions.csv"), PartitionData)
    flows_partitions_df  = read_csv_with_schema(fillpath("flows-partitions.csv"), PartitionData)

    # Sets and subsets that depend on input data
    rep_periods   = rep_period_df.id
    rp_time_steps = Dict(row.id => 1:row.num_time_steps for row in eachrow(rep_period_df))   #time steps in the RP (e.g., hours), that are dependent on RP

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
    name_to_id = Dict(zip(assets_data_df.name, assets_data_df.id))

    _graph = Graphs.DiGraph(num_assets)
    for flow in flow_data
        from_id, to_id = flow[1]
        Graphs.add_edge!(_graph, name_to_id[from_id], name_to_id[to_id])
    end

    graph = MetaGraphsNext.MetaGraph(_graph, asset_data, flow_data)

    rp_partitions_assets = compute_rp_partitions(assets_partitions_df, labels(graph), rp_time_steps)
    rp_partitions_flows  = compute_rp_partitions(flows_partitions_df, edge_labels(graph), rp_time_steps)

    # From balance equations:
    # Every asset a ∈ A and every rp ∈ RP will define a collection of flows, and therefore the time steps
    # can be defined a priori.
    constraints_time_periods = Dict(
        (a, rp) => begin
            compute_rp_partition(
                [
                    [
                        rp_partitions_flows[(f, rp)] for
                        f in edge_labels(graph) if f[1] == a || f[2] == a
                    ]
                    [rp_partitions_assets[(a, rp)]]
                ],
            )
        end for a in labels(graph), rp in rep_periods
    )

    # Parameters for system
    rp_weight = Dict((row.id) => row.weight for row in eachrow(rep_period_df)) #representative period weight [h]
    rp_resolution = Dict(row.id => row.resolution for row in eachrow(rep_period_df))

    # Parameter for profile of assets
    assets_profile = Dict(
        (label_for(graph, row.id), row.rep_period_id, row.time_step) => row.value for
        row in eachrow(assets_profiles_df)
    ) # asset profile [p.u.]

    # Parameter for profile of flow
    flows_profile = Dict(
        (flow_data[row.id][1], row.rep_period_id, row.time_step) => row.value for
        row in eachrow(flows_profiles_df)
    )

    # Define parameters and sets
    params = (
        assets_profile = assets_profile,
        flows_profile = flows_profile,
        rp_weight = rp_weight,
        rp_resolution = rp_resolution,
    )
    sets = (
        rep_periods = rep_periods,
        rp_partitions_flows = rp_partitions_flows,
        constraints_time_periods = constraints_time_periods,
    )

    return graph, params, sets
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
    compute_rp_partitions(df, elements, time_steps_per_rp)

For each element in `elements` (assets or flows), parse the representative
period partitions defined in `df`, a DataFrame of the file
`assets-partitions.csv` or `flows-partitions.csv`.

`time_steps_per_rp` must be a dictionary indexed by `rp` and its values are the
time steps of that `rp`.

To obtain the partitions, the columns `specification` and `partition` from `df`
are passed to the function [`_parse_rp_partition`](@ref).
"""
function compute_rp_partitions(df, elements, time_steps_per_rp)
    rp_partitions = Dict(
        (element, rp) => begin
            N = length(rp_time_steps)
            # Look for index in df that matches this element and rp
            j = findfirst((df.id .== element_id) .& (df.rep_period_id .== rp))
            if j === nothing
                # If there is no time block specification, use default of 1
                [k:k for k = 1:N]
            else
                _parse_rp_partition(Val(df[j, :specification]), df[j, :partition], rp_time_steps)
            end
        end for (element_id, element) in enumerate(elements),
        (rp, rp_time_steps) in time_steps_per_rp
    )

    return rp_partitions
end
