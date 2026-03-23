#= Script version of test-bids.jl
=#

# CommonSetup
using CSV: CSV
using DataFrames: DataFrames, DataFrame
using DuckDB: DuckDB, DBInterface
using GLPK: GLPK
using HiGHS: HiGHS
using JuMP: JuMP
using MathOptInterface: MathOptInterface
using Test: Test, @test, @testset, @test_throws, @test_logs
using TOML: TOML
using TulipaEnergyModel: TulipaEnergyModel
using TulipaIO: TulipaIO

const TEM = TulipaEnergyModel

INPUT_FOLDER = joinpath(@__DIR__, "inputs")
export INPUT_FOLDER

function _create_connection_from_dict(data::Dict{String,DataFrame})
    connection = DBInterface.connect(DuckDB.DB)

    for (table_name::String, table::DataFrame) in data
        # Check that these `table_name` exist in the schema
        if !haskey(TulipaEnergyModel.schema_per_table_name, table_name)
            error("Table '$table_name' does not exist")
        end
        DuckDB.register_data_frame(connection, table, table_name)
    end

    return connection
end

function _read_csv_folder(connection, input_dir)
    schemas = TulipaEnergyModel.schema_per_table_name
    return TulipaIO.read_csv_folder(connection, input_dir; schemas)
end

function _tiny_fixture()
    connection = DBInterface.connect(DuckDB.DB)
    _read_csv_folder(connection, joinpath(@__DIR__, "inputs", "Tiny"))
    return connection
end

function _storage_fixture()
    connection = DBInterface.connect(DuckDB.DB)
    _read_csv_folder(connection, joinpath(@__DIR__, "inputs", "Storage"))
    return connection
end

function _multi_year_fixture()
    connection = DBInterface.connect(DuckDB.DB)
    _read_csv_folder(connection, joinpath(@__DIR__, "inputs", "Multi-year Investments"))
    return connection
end

function _is_constraint_equal(left, right)
    if !_is_constraint_equal_kernel(left, right)
        println("LEFT")
        _show_constraint(left)
        println("RIGHT")
        _show_constraint(right)
        return false
    else
        return true
    end
end

function _is_constraint_equal(expected_vec::Vector, observed_vec::Vector)
    if length(expected_vec) != length(observed_vec)
        @error "Vector lengths differ: expected $(length(expected_vec)), observed $(length(observed_vec))"
        return false
    end

    for (i, (expected, observed)) in enumerate(zip(expected_vec, observed_vec))
        if !_is_constraint_equal(expected, observed)
            @error "Constraint $i differs"
            return false
        end
    end
    return true
end

function _show_constraint(con)
    for (var, coef) in sort(con.func.terms; by = JuMP.name)
        println(_signed_string(coef), " ", var)
    end
    println(_signed_string(con.func.constant))
    println(_sense_string(con.set))
    println(_signed_string(con.set))
    return println("")
end

_signed_string(x) = string(x >= 0 ? "+" : "-", " ", abs(x))
_signed_string(s::MathOptInterface.LessThan) = _signed_string(s.upper)
_signed_string(s::MathOptInterface.EqualTo) = _signed_string(s.value)
_signed_string(s::MathOptInterface.GreaterThan) = _signed_string(s.lower)

_sense_string(::MathOptInterface.LessThan) = "<="
_sense_string(::MathOptInterface.EqualTo) = "=="
_sense_string(::MathOptInterface.GreaterThan) = ">="

function _is_constraint_equal_kernel(left, right)
    left_terms, right_terms = left.func.terms, right.func.terms
    missing_in_right = setdiff(keys(left_terms), keys(right_terms))
    if !isempty(missing_in_right)
        @error string("missing in right constraint: ", missing_in_right)
        return false
    end
    missing_in_left = setdiff(keys(right_terms), keys(left_terms))
    if !isempty(missing_in_left)
        @error string("missing in left constraint: ", missing_in_left)
        return false
    end
    result = true
    for k in keys(left_terms)
        if !isapprox(left_terms[k], right_terms[k])
            @error string(left_terms[k], " != ", right_terms[k])
            result = false
        end
    end
    if left.set != right.set
        @error string(left.set, " != ", right.set)
        result = false
    end
    return result
end

function _get_cons_object(model::JuMP.GenericModel, name::Symbol)
    return [JuMP.constraint_object(con) for con in model[name]]
end

function _test_variable_properties(
    variable::JuMP.GenericVariableRef,
    lower_bound::Union{Nothing,Float64},
    upper_bound::Union{Nothing,Float64};
    is_integer::Bool = false,
    is_binary::Bool = false,
)
    if isnothing(lower_bound)
        @test !JuMP.has_lower_bound(variable)
    else
        @test JuMP.lower_bound(variable) == lower_bound
    end

    if isnothing(upper_bound)
        @test !JuMP.has_upper_bound(variable)
    else
        @test JuMP.upper_bound(variable) == upper_bound
    end

    @test JuMP.is_integer(variable) == is_integer
    @test JuMP.is_binary(variable) == is_binary

    return nothing
end

"""
    _create_table_for_tests(connection, table_name, table_rows, columns)

Create a non-empty table for tests.
"""
function _create_table_for_tests(
    connection::DuckDB.DB,
    table_name::String,
    table_rows::Vector{<:Tuple},
    columns::Vector{Symbol},
)
    df = DataFrame(table_rows, columns)
    DuckDB.register_data_frame(connection, df, table_name)
    return nothing
end

"""
    _create_empty_table_for_tests(connection, table_name, columns_with_types)

Create an empty table with a specific schema for tests. The `columns_with_types` can be a dictionary or a vector of pairs.
"""
function _create_empty_table_for_tests(
    connection::DuckDB.DB,
    table_name::String,
    columns_with_types::Union{Dict{Symbol,DataType},Vector{Pair{Symbol,DataType}}},
)
    df = DataFrame(Dict(name => col_type[] for (name, col_type) in columns_with_types))
    DuckDB.register_data_frame(connection, df, table_name)
    return nothing
end
# End of CommonSetup

# BidsSetup
using TulipaBuilder
using TulipaClustering: TulipaClustering

insert_into(connection, table, what) =
    DuckDB.query(connection, "INSERT INTO $table BY NAME ($what)")
insert_into(connection, table, columns, from) =
    insert_into(connection, table, "SELECT $columns FROM $from")
from_bids_insert_into(connection, table, columns) = insert_into(connection, table, columns, "bids")

bid_blocks = [
    (
        customer = "A",
        exclusive_group = 1,
        profile_block = 1,
        timestep = 6:6,
        quantity = [10],                # 0, 0, 10, ....
        price = 500.0,
    ),
    (
        customer = "A",
        exclusive_group = 2,
        profile_block = 1,
        timestep = 4:5,
        quantity = [70, 30],            # 70, 30, 0, ....
        price = 2.5,
    ),
    (
        customer = "A",
        exclusive_group = 2,
        profile_block = 2,
        timestep = 4:5,
        quantity = [60, 20],            # 60, 20, 0, ...
        price = 1.5,
    ),
    (
        customer = "B",
        exclusive_group = 3,
        profile_block = 1,
        timestep = 4:10,
        quantity = (1:7) .* (7:-1:1),   # 7, 12, 15, 16, 15, 12, 7
        price = 0.001,
    ),
]

"""
    connection = create_problem(; capacity, operational_cost)

Creates a simple problem via TulipaBuilder with given capacity and operational_cost.

The problem has one `producer` named "Generator", one `consumer` named "Bid Manager" and flow between them.
The producer has capacity given by the input and `initial_units = 1`.
The consumer has `peak_demand = 0`.
Since we don't have a profile, we explicitly define a milestone year with 12 timesteps.
After this problem is created, we "dummy cluster" it and populate with defaults.
"""
function create_problem(; capacity = 1.0, operational_cost = 1.0)
    tulipa = TulipaData{String}()
    add_asset!(tulipa, "Generator", :producer; capacity = capacity, initial_units = 1.0)
    add_asset!(tulipa, "Bid Manager", :consumer; peak_demand = 0.0) # no demand
    add_flow!(tulipa, "Generator", "Bid Manager"; operational_cost = operational_cost)
    # Because we at least one profile
    attach_profile!(tulipa, "Bid Manager", :demand, 2030, zeros(12))

    connection = create_connection(tulipa, TEM.schema)
    TulipaClustering.dummy_cluster!(connection)
    TulipaEnergyModel.populate_with_defaults!(connection)

    return connection
end

"""
    create_bids_tables!(connection, bids)

Given a NamedTuple array `bids` with a format similar to what is created in
DEMOSES, we create the `bids` and `bids_profiles` tables in the DuckDB `connection`.

Each bid has a (consumer, exclusive_group, profile_block) identifier.
Under the same `(consumer, exclusive_group)` group, at most one of the `profile_block`s is selected.

Each bid has two vector of the same size, `timestep` and `quantity`,
indicating the bid block's desired quantities per timestep.
The whole block sells for the price `price`.

These tables' schema are:
- `bids`: `bid_id INT, asset TEXT, customer TEXT, exclusive_group INT, profile_block INT, price REAL`
- `bids_profiles`: `bid_id INT, profile_name TEXT, timestep INT, quantity INT`

The `bids` table has an entry per bid block, with basic bid information and
the `bid_id` for cross-referencing with the `bids_profiles` table, where
the quantities per timestep are stored.
"""
function create_bids_tables!(connection, bids)
    # Bids
    # bidding_window = 1:24
    lookup = Dict(
        (bid.customer, bid.exclusive_group, bid.profile_block) => bid_id for
        (bid_id, bid) in enumerate(bids)
    )
    bids_df = DataFrame([
        (;
            bid_id = lookup[bid.customer, bid.exclusive_group, bid.profile_block],
            asset = "bid$(lookup[bid.customer, bid.exclusive_group, bid.profile_block])",
            bid.customer,
            bid.exclusive_group,
            bid.profile_block,
            bid.price,
            peak_demand = maximum(bid.quantity),
        ) for bid in bids
    ])
    bids_profiles_df = DataFrame([
        (;
            bid_id = lookup[bid.customer, bid.exclusive_group, bid.profile_block],
            profile_name = "bid_profiles-bid$(lookup[bid.customer, bid.exclusive_group, bid.profile_block])-demand",
            timestep = ti,
            quantity = qi / maximum(bid.quantity),
        ) for bid in bids for (ti, qi) in zip(bid.timestep, bid.quantity)
    ])
    DuckDB.register_table(connection, bids_df, "bids")
    DuckDB.register_table(connection, bids_profiles_df, "bids_profiles")

    return nothing
end

"""
    compute_solution_from_selected_bids(bid_blocks, expected_bids_ids)

Given the array of NamedTuples of bids, and the array of ids of selected
bids, this will compute the supply and demand values and return the
expected solution.
"""
function compute_solution_from_selected_bids(bid_blocks, expected_bids_ids, operational_cost)
    bids = bid_blocks[expected_bids_ids]
    expected_total_quantity = sum(sum(bid.quantity) for bid in bids; init = 0.0)
    expected_demand_value = sum(sum(bid.quantity * bid.price) for bid in bids; init = 0.0)
    expected_supply_value = operational_cost * expected_total_quantity

    return expected_supply_value - expected_demand_value
end

"""
    modify_input_for_bids!(connection)

Modify the input tables in `connection` to add the bids.
"""
function modify_input_for_bids!(connection)
    # Modifications to make bids work
    year = only([
        row.year for row in
        DuckDB.query(connection, "SELECT DISTINCT milestone_year AS year FROM asset_milestone")
    ])

    timestep_window = only([
        row for row in DuckDB.query(
            connection,
            "SELECT MIN(timestep) AS timestep_start, MAX(timestep) AS timestep_end
            FROM profiles_rep_periods",
        )
    ])

    create_assets_for_bids!(connection, year, timestep_window)
    create_flows_for_bids!(connection, year, timestep_window)
    create_profiles_for_bids!(connection, year, timestep_window)

    return connection
end

"""
    create_assets_for_bids!(connection, year, timestep_window)

Part of [`modify_input_for_bids!`](@ref).

Add a new asset per bid block. Each bid is a `consumer` asset, with some default values.
Here is a list of noteworthy values:

- `asset.capacity = 1.0` (not sure why)
- `asset.consumer_balance_sense = "=="`, balance using equality.
    Curtailment is not controlled here.
- `asset.min_operating_point = 1.0`, to force the lower and upper limit
    constraints to match. Maybe curtailment should be controlled here.
- `asset.unit_commitment = true`, because unit commitment is what controls the bid acceptance.
- `asset.unit_commitment_integer = true`. Possibly not necessary? Curtailment should set this to false?
- `asset.unit_commitment_method = "basic"`. I don't know if other alternatives make sense or not.
- `asset_milestone.peak_demand`, from the normalised profile quantity.
- `asset_both.initial_units = 1.0`, which corresponds to 100% of the bid.
- `assets_rep_periods_partitions.partition = <FULL PERIOD>`, so that a
    single unit commitment variable corresponds to the whole profile block.
- `assets_profiles.profile_name = "bid_profiles-bid<BID_ID>-demand"`, a
    unique profile name per bid, to be referenced later.
"""
function create_assets_for_bids!(connection, year, timestep_window)
    milestone_year = "$year AS milestone_year"
    commission_year = "$year AS commission_year"
    timestep_start = timestep_window.timestep_start
    timestep_end = timestep_window.timestep_end

    from_bids_insert_into(
        connection,
        "asset",
        """asset,
        'consumer' AS type,
        1.0 AS capacity,
        '==' AS consumer_balance_sense,
        1.0 AS min_operating_point,
        true AS unit_commitment,
        true AS unit_commitment_integer,
        'basic' AS unit_commitment_method
        """,
    )
    from_bids_insert_into(connection, "asset_milestone", "asset, $milestone_year, peak_demand")
    from_bids_insert_into(connection, "asset_commission", "asset, $commission_year")
    from_bids_insert_into(
        connection,
        "asset_both",
        "asset, $commission_year, $milestone_year, 1.0 AS initial_units",
    )

    rep_period = "1 AS rep_period"
    specification = "'uniform' AS specification"
    partition = "'$(timestep_end - timestep_start + 1)' AS partition"
    # Creating assets_rep_periods_partitions if necessary
    DuckDB.query(
        connection,
        """CREATE TABLE IF NOT EXISTS assets_rep_periods_partitions
            (asset VARCHAR, year INTEGER, rep_period INTEGER, specification VARCHAR, partition VARCHAR);
        """,
    )
    from_bids_insert_into(
        connection,
        "assets_rep_periods_partitions",
        "asset, $year AS year, $rep_period, $specification, $partition",
    )

    profile_name = "'bid_profiles-bid' || bid_id::VARCHAR || '-demand' AS profile_name"
    from_bids_insert_into(
        connection,
        "assets_profiles",
        "asset, $commission_year, $profile_name, 'demand' AS profile_type",
    )

    return connection
end

"""
    create_flows_for_bids!(connection, year, timestep_window)

Part of [`modify_input_for_bids!`](@ref).

Add the necessary flows per bid block. Each new bid consumer needs two new flows:
One from the bids manager to the bid, and one looping flow from the bid to itself.
The bids manager is selected at random (implicitly by DuckDB) from all the consumer assets.

The flow from the bids manager to the bid asset only has one noteworthy value:
- `flow_milestone.operational_cost = -<PRICE>`. By using a negative value
    for operational cost, "satisfying" the demand means receiving money per
    supplied quantity.
"""
function create_flows_for_bids!(connection, year, timestep_window)
    milestone_year = "$year AS milestone_year"
    commission_year = "$year AS commission_year"

    consumer_used_for_bids = only([
        row.asset for row in DuckDB.query(
            connection,
            "SELECT ANY_VALUE(asset) AS asset FROM asset WHERE type = 'consumer'",
        )
    ])
    from_asset = "'$consumer_used_for_bids' AS from_asset"
    to_asset = "asset AS to_asset"

    from_bids_insert_into(connection, "flow", "$from_asset, $to_asset")
    from_bids_insert_into(
        connection,
        "flow_milestone",
        "$from_asset, $to_asset, $milestone_year, -bids.price AS operational_cost",
    )
    from_bids_insert_into(connection, "flow_commission", "$from_asset, $to_asset, $commission_year")

    # loops
    from_bids_insert_into(connection, "flow", "asset AS from_asset, asset AS to_asset")
    from_bids_insert_into(
        connection,
        "flow_milestone",
        "asset AS from_asset, asset AS to_asset, $milestone_year",
    )
    from_bids_insert_into(
        connection,
        "flow_commission",
        "asset AS from_asset, asset AS to_asset, $commission_year",
    )

    return connection
end

"""
    create_profiles_for_bids!(connection, year, timestep_window)

Part of [`modify_input_for_bids!`](@ref).

Add a new profile per bid block. The bid block is filled with 0s to match the full size of the profiles.
The profiles' quantity are already normalised and the maximum was captured by peak_demand.
"""
function create_profiles_for_bids!(connection, year, timestep_window)
    rep_period = "1 AS rep_period"
    timestep_start = timestep_window.timestep_start
    timestep_end = timestep_window.timestep_end

    insert_into(
        connection,
        "profiles_rep_periods",
        """
        WITH cte_profile_names AS (SELECT DISTINCT profile_name FROM bids_profiles),
        cte_clean_profiles AS (
            SELECT
                profile_name,
                t AS timestep,
                0.0 AS value,
            FROM cte_profile_names
            CROSS JOIN generate_series(1, $(timestep_end - timestep_start + 1)) s(t)
        )
        SELECT
            cte_clean_profiles.profile_name,
            $year AS year,
            $rep_period,
            cte_clean_profiles.timestep,
            COALESCE(bids_profiles.quantity, 0.0) AS value,
        FROM cte_clean_profiles
        LEFT JOIN bids_profiles
            ON cte_clean_profiles.profile_name = bids_profiles.profile_name
            AND cte_clean_profiles.timestep = bids_profiles.timestep
        """,
    )

    return connection
end

function modify_model_to_add_exclusive_group_constraints!(energy_problem)
    for row in DuckDB.query(
        energy_problem.db_connection,
        """
        SELECT customer, exclusive_group, array_agg(var_units_on.id) AS units_on_ids
        FROM bids
        LEFT JOIN var_units_on
            ON 'bid' || bids.bid_id::VARCHAR = var_units_on.asset
        GROUP BY customer, exclusive_group
        """,
    )
        units_on_ids = row.units_on_ids
        if length(units_on_ids) > 1
            var = energy_problem.variables[:units_on].container
            JuMP.@constraint(
                energy_problem.model,
                sum(var[id] for id in units_on_ids) <= 1,
                base_name = "exclusive_group[$(row.customer),$(row.exclusive_group)]"
            )
        end
    end

    return energy_problem
end

"""
    run_scenario_with_bids(bid_blocks; capacity, operational_cost)

Create a basic problem, modify it with the bids, create the EnergyProblem,
modify the model with the exclusive group constraints, solve it and return
both connection and energy problem.
"""
function run_scenario_with_bids(
    bid_blocks;
    capacity = capacity,
    operational_cost = operational_cost,
)
    connection = create_problem(; capacity = capacity, operational_cost = operational_cost)
    create_bids_tables!(connection, bid_blocks)
    modify_input_for_bids!(connection)

    energy_problem = TulipaEnergyModel.EnergyProblem(connection)
    TulipaEnergyModel.create_model!(energy_problem)

    modify_model_to_add_exclusive_group_constraints!(energy_problem)

    TulipaEnergyModel.solve_model!(energy_problem)
    TulipaEnergyModel.save_solution!(energy_problem; compute_duals = true)

    return connection, energy_problem
end
# End of BidsSetup

# New test
connection, energy_problem =
    run_scenario_with_bids(bid_blocks; capacity = 99.0, operational_cost = 0.5)

# Year and rep_period are not required below because there's only one of them in this problem

var_flow = energy_problem.variables[:flow]
var_units_on = energy_problem.variables[:units_on]

cons_balance_consumer_lookup = Dict(
    (row.asset, row.time_block_start) => row.id for
    row in energy_problem.constraints[:balance_consumer].indices
)
cons_min_output_flow_with_unit_commitment_lookup = Dict(
    (row.asset, row.time_block_start) => row.id for
    row in energy_problem.constraints[:min_output_flow_with_unit_commitment].indices
)
cons_max_output_flow_with_basic_unit_commitment_lookup = Dict(
    (row.asset, row.time_block_start) => row.id for
    row in energy_problem.constraints[:max_output_flow_with_basic_unit_commitment].indices
)

# TODO: (keys) -> var OR (keys) -> (; id, var, etc.)?
var_flow_lookup = Dict(
    (row.from_asset, row.to_asset, row.time_block_start) => var_flow.container[row.id] for
    row in var_flow.indices
)
var_units_on_lookup =
    Dict(row.asset => var_units_on.container[row.id] for row in var_units_on.indices)

bid_list = ("bid$i" for i in 1:length(bid_blocks))

# balance_consumer
for timestep in 1:12
    ## At the Bid Manager
    incoming = var_flow_lookup[("Generator", "Bid Manager", timestep)]
    outgoing = sum(var_flow_lookup[("Bid Manager", bid, timestep)] for bid in bid_list)
    expected_cons = JuMP.@build_constraint(incoming == outgoing)

    cons_id = cons_balance_consumer_lookup[("Bid Manager", timestep)]
    observed_cons = _get_cons_object(energy_problem.model, :balance_consumer)[cons_id]

    @info _is_constraint_equal(expected_cons, observed_cons)

    ## At the bid itself
    for (bid_id, bid) in enumerate(bid_list)
        incoming = var_flow_lookup[("Bid Manager", bid, timestep)]
        loop = var_flow_lookup[(bid, bid, timestep)]
        peak_demand = maximum(bid_blocks[bid_id].quantity)
        expected_cons = JuMP.@build_constraint(incoming == loop * peak_demand)

        cons_id = cons_balance_consumer_lookup[(bid, timestep)]
        observed_cons = _get_cons_object(energy_problem.model, :balance_consumer)[cons_id]

        @info _is_constraint_equal(expected_cons, observed_cons)
    end
end

# min_output_flow_with_unit_commitment and max_output_flow_with_basic_unit_commitment
for timestep in 1:12
    for (bid_id, bid) in enumerate(bid_list)
        flow = var_flow_lookup[(bid, bid, timestep)]
        units_on = var_units_on_lookup[bid]
        profile_name = "bid_profiles-$bid-demand"
        demand_agg = energy_problem.profiles.rep_period[(profile_name, 2030, 1)].values[timestep]

        # min
        expected_cons = JuMP.@build_constraint(flow >= units_on * demand_agg)

        cons_id = cons_min_output_flow_with_unit_commitment_lookup[(bid, timestep)]
        observed_cons =
            _get_cons_object(energy_problem.model, :min_output_flow_with_unit_commitment)[cons_id]

        @info _is_constraint_equal(expected_cons, observed_cons)

        # max
        expected_cons = JuMP.@build_constraint(flow <= units_on * demand_agg)

        cons_id = cons_max_output_flow_with_basic_unit_commitment_lookup[(bid, timestep)]
        observed_cons =
            _get_cons_object(energy_problem.model, :max_output_flow_with_basic_unit_commitment)[cons_id]

        @info _is_constraint_equal(expected_cons, observed_cons)
    end
end

# limit_units_on_simple_method
for (bid_id, bid) in enumerate(bid_list)
    units_on = var_units_on_lookup[bid]
    expected_cons = JuMP.@build_constraint(units_on <= 1)

    cons_id = bid_id
    observed_cons = _get_cons_object(energy_problem.model, :limit_units_on_simple_method)[cons_id]

    @info _is_constraint_equal(expected_cons, observed_cons)
end
