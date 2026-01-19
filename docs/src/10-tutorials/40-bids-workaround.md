# [Bids via workaround using consumer unit commitment](@id bids-tutorial)

In this tutorial we will learn how to create bids using consumer unit commitment.
Bids are not explicitly supported in Tulipa (yet), but they can be modeled with a few workarounds.

This is an advanced tutorial. It assumes some basic knowledge of Tulipa, so going through some of the earlier tutorials might be beneficial.
Furthermore, it deals with the underlying model of Tulipa, so it

## Introduction

In our context, a bid is a proposal to buy energy at a given price at one or more time steps.
If the proposal is for a single time step, then we are going to call it a "simple bid", as opposed to a "profile bid", when it involves more than one time step.
The price is constant in both cases, which allow us to always use vectors to represent the required quantities.
In a "simple bid", the vectors of time steps and quantities both have 1 element.

Furthermore, the bid can be part of an "exclusive group". Inside each exclusive group, a single bid is accepted.
Finally, some bids also have a curtailment possibility, i.e., they can be supplied with less energy than the maximum desired, but no less than a given percentage of the maximum (given by `curtailment_minimum`).

Here are some example bids:

```@example bids
bid_blocks = [
    (
        customer = "A",
        exclusive_group = 1,
        profile_block = 1,
        timestep = 4:4,
        quantity = [10],
        price = 5.0,
        curtailment_minimum = 1.0,
    ),
    (
        customer = "A",
        exclusive_group = 2,
        profile_block = 1,
        timestep = 2:3,
        quantity = [40, 30],
        price = 2.5,
        curtailment_minimum = 1.0,
    ),
    (
        customer = "A",
        exclusive_group = 2,
        profile_block = 2,
        timestep = 2:3,
        quantity = [20, 20],
        price = 1.5,
        curtailment_minimum = 0.8,
    ),
    (
        customer = "B",
        exclusive_group = 1,
        profile_block = 1,
        timestep = 1:6,
        quantity = [5, 10, 15, 25, 30, 15],
        price = 0.8,
        curtailment_minimum = 1.0,
    ),
]
```

Each bid has the following data:

- `customer`, identifying who is the asking party;
- `exclusive_group`, identifying each group of exclusive bids;
- `profile_block`, identifying each block of bids;
- `timestep`, indicating the time steps of a bid;
- `quantity`, indicating the vector of requested quantities;
- `price`, indicating the price;
- `curtailment_minimum`, indicating the minimum percentage of energy that can be delivered under curtailment.

Notice that `(customer, exclusive_group, profile_block)` form a unique identifier for this bid.

In words, we can say:

- The first bid, `(A, 1, 1)`, requests 10 KW at time step 4 and is willing to pay \$5.0 per KW. No curtailment allowed.
- The second bid, `(A, 2, 1)`, requests 40 KW at time step 2 and 30 KW at time step 3 and is willing to pay \$2.5 per KW. No curtailment allowed.
- The third bid, `(A, 2, 2)`, requests 20 KW at time step 2 and 20 KW at time step 3 and is willing to pay \$1.5 per KW. At least 80% of the requested quantity per day must be satisfied.
- The fourth bid, `(B, 1, 1)`, requests 5 KW, 10 KW, 15 KW, 25 KW, 30 KW, and 15 KW from time steps 1 to 6, in order. It is willing to pay \$0.8 per KW, and no curtailment is allowed.

Finally, notice that the second and third bids share the same `exclusive_group`, so **at most one of them can be accepted**.

## Modeling

We don't have an underlying energy system to make these bids, so let's create a fake scenario with

- One generator, with 1 initial unit, where the **capacity** is given by us;
- One consumer, with no demand (because we don't care for this problem);
- A flow between the generator and the consumer, with an **operational cost** given by us;

### Creating initial problem with TulipaBuilder

We will use [TulipaBuilder.jl](https://github.com/TulipaEnergy/TulipaBuilder.jl) to create the Tulipa problem for this problem:

```@example bids
using TulipaBuilder

year = 2030 # We don't need the year for anything, but we need to set it
num_timesteps = 6

function create_new_problem(;capacity = 60.0, operational_cost = 0.5)
    tulipa = TulipaData()

    add_asset!(tulipa, "Generator", :producer; capacity, operational_cost, initial_units = 1.0)
    add_asset!(tulipa, "Consumer", :consumer; peak_demand = 0.0)
    add_flow!(tulipa, "Generator", "Consumer"; operational_cost)
    # Because we need at least one profile, we explicitly set demand to 0
    attach_profile!(tulipa, "Consumer", :demand, year, zeros(num_timesteps))
end
```

Notice that this is already a valid Tulipa problem, but the solution is to have no flow.

```@example bids
using TulipaClustering: TulipaClustering as TC
using TulipaEnergyModel: TulipaEnergyModel as TEM

tulipa = create_new_problem()

# Convert TulipaBuilder's data to TulipaEnergyModel format in the connection
connection = create_connection(tulipa)

# (Fake) cluster the profiles to generate representative periods
TC.dummy_cluster!(connection)

# Solve the scenario
TEM.populate_with_defaults!(connection)
energy_problem = TEM.run_scenario(connection, show_log=false)

energy_problem
```

### Input modification for bids

The trick to have bids is to create a new asset for each of the bids.
Each of these bid assets is a consumer asset requesting the profile bid as a "demand" bid.
In Tulipa, the `:consumer` assets also work as hubs, i.e., they are allowed to provide energy to other assets connected via outgoing flows.
So, to satisfy the "demand" of the bid assets, we create a flow from the `"Consumer"` asset to these bid assets.
To simulate the `price` willing to be paid by a bid, we use the `operational_cost` between the "Consumer" and the bid asset.
In summary:

- For each `(consumer, exclusive_group, profile_block)` bid, create a new ':consumer' asset.
- Attach a profile with the quantities per time steps of the bid to this asset.
  - The profiles in Tulipa have to be complete, so the remaining hours are simply completed with 0.
- Create a flow between an existing `:consumer` and this bid asset and set `operational_cost = -price`.

However, this by itself is not sufficient, because there is nothing yet forcing this bid to accepted or not.

If the bid is accepted, the requested quantity is treated as a demand to be satisfied for every time step.
If the bid is not accepted, there should be no flow to this asset for every time step.

The missing link is to have some kind of variable that indicates whether the bid is accepted or not.
For that, we will use an existing feature of TulipaEnergyModel, [Unit Commitment](@ref unit-commitment-setup), but we will apply it to consumers.

By itself, however, this is not enough, because the consumer balance constraint still forces the requested bid to be satisfied, and there is nothing tying that to the unit commitment variables.
Therefore, we use a special condition inside the consumer balance constraint created specifically for this case, which is to create a **loop flow** in the bid asset.
This existence of a loop flow changes the balance constraint tying the incoming flow to the loop flow, and the loop flow is tied to the unit commitment variables by the minimum and maximum output flow ramping constraints.

These are the modifications:

- For each bid, create a new asset. We'll name it "Bid". Set
  - `capacity = 1.0`
  - `consumer_balance_sense = "=="` (which is the default)
  - `initial_units = 1.0`
  - `peak_demand` as anything positive (`1.0` makes it easier to understand the results, `maximum(bid_block.profile)` is the common normalized way)
  - `type = :consumer`
  - `unit_commitment = true`
  - `unit_commitment_integer = true`
  - `unit_commitment_method = "basic"`
- Set the time resolution of the asset to the full length of the profile (`assets_rep_periods_partitions.partition = rep_periods_data.num_timesteps`)
- Find an existing consumer, we'll name it "Bid Manager".
- Connect a flow from the "Bid Manager" to "Bid", with `flow_milestone.operational_cost = -price`.
- Create a loop flow, connecting the asset "Bid" to itself.
- Create a profile in `profiles_rep_periods` or `profiles`, depending on whether you still have to cluster or not.
  - Use the bid's quantities, normalized by `peak_demand`, as `value`, for the corresponding time steps as `timestep`.
  - Use 0 as `value` for the missing `timestep`.
  - Choose a `profile_name`
- Relate the profile above to the asset "Bid" in `assets_profiles`, with `profile_type = 'demand'`.

We can create a function to help us create a bid with the above characteristics based on a given bid_block:

```@example bids
function add_new_bid!(tulipa, bid_id, bid_block)
    bid_name = "bid$bid_id"
    bid_manager = "Consumer"
    peak_demand = 1.0
    add_asset!(
        tulipa,
        bid_name,
        :consumer,
        capacity = 1.0,
        consumer_balance_sense = "==",
        initial_units = 1.0,
        min_operating_point = bid_block.curtailment_minimum,
        peak_demand = peak_demand,
        unit_commitment = true,
        unit_commitment_integer = true,
        unit_commitment_method = "basic",
    )
    set_partition!(tulipa, bid_name, year, 1, num_timesteps) # 1 = rep_period, there is only one
    add_flow!(tulipa, bid_manager, bid_name, operational_cost = -bid_block.price)
    add_flow!(tulipa, bid_name, bid_name)
    profile = zeros(num_timesteps)
    profile[bid_block.timestep] = bid_block.quantity / peak_demand
    attach_profile!(tulipa, bid_name, :demand, year, profile)

    return tulipa
end
```

With this function, we can go back to our initial problem and add the bid blocks from the beginning:

```@example bids
tulipa = create_new_problem(capacity = 60, operational_cost = 0.5)
for (bid_id, bid_block) in enumerate(bid_blocks)
    add_new_bid!(tulipa, bid_id, bid_block)
end

# Convert TulipaBuilder's data to TulipaEnergyModel format in the connection
connection = create_connection(tulipa)

# (Fake) cluster the profiles to generate representative periods
TC.dummy_cluster!(connection)

# Solve the scenario
TEM.populate_with_defaults!(connection)
energy_problem = TEM.run_scenario(connection, show_log=false)

energy_problem
```

We can see that the objective value is different, but let's investigate the solution in more details.
First, we can check which flows are not 0:

```@example bids
using DuckDB, DataFrames

# Helper function
df_sql(con, s) = DataFrame(DuckDB.query(con, s))

df_sql(
    connection,
    """
    SELECT from_asset, to_asset, time_block_start AS timestep, solution,
    FROM var_flow
    WHERE solution != 0
    """,
)
```

Second, we can also check the unit commitment variables:

```@example bids
df_sql(
    connection,
    """
    SELECT asset, solution,
    FROM var_units_on
    WHERE solution != 0
    """,
)
```

We can see from these two tables that bids 1, 2, and 3 were accepted.
This mostly makes sense, **except** that bids 2 and 3 should not be accepted at the same time, since
they are in the same exclusivity group (same `exclusive_group` for a given `customer`).
This means that we have one least modification to make.

### Model modification for exclusivity of the bids

This modification has to be done directly in the **underlying JuMP model**.
The required change is to add a constraint $\displaystyle \sum_{i: i \in G_k} u_i \leq 1$, where $u_i$ are the unit commitment variables (i.e., the bid-acceptance variables), and $G_k$ are the exclusive groups.

The function below modifies a model with this constraint:

```@example bids
using JuMP

function add_exclusive_groups!(energy_problem, bid_blocks)
    exclusive_groups = Dict{Tuple{String,Int},Vector{Int}}() # (customer, exclusive_group) -> [bid_ids...]
    for (bid_id, bid) in enumerate(bid_blocks)
        key = (bid.customer, bid.exclusive_group)
        if !haskey(exclusive_groups, key)
            exclusive_groups[key] = Int[]
        end
        push!(exclusive_groups[key], bid_id)
    end

    for ((customer, exclusive_group), bid_ids) in exclusive_groups
        if length(bid_ids) == 1 # There is only one bid in this group, there is no need to further constrain
            continue
        end
        var = energy_problem.variables[:units_on].container
        JuMP.@constraint(
            energy_problem.model,
            sum(var[id] for id in bid_ids) <= 1,
            base_name = "exclusive_bid_group[$(customer),$(exclusive_group)]",
        )
    end
end
```

We now modify our little script with this additional step:

```@example bids
tulipa = create_new_problem(capacity = 60, operational_cost = 0.5)
for (bid_id, bid_block) in enumerate(bid_blocks)
    add_new_bid!(tulipa, bid_id, bid_block)
end

# Convert TulipaBuilder's data to TulipaEnergyModel format in the connection
connection = create_connection(tulipa)

# (Fake) cluster the profiles to generate representative periods
TC.dummy_cluster!(connection)

# Create the mode
TEM.populate_with_defaults!(connection)
energy_problem = TEM.EnergyProblem(connection)
TEM.create_model!(energy_problem)

# Modify the model
add_exclusive_groups!(energy_problem, bid_blocks)

# Solve the model
TEM.solve_model!(energy_problem)
TEM.save_solution!(energy_problem; compute_duals = true)

energy_problem
```

Once again, we investigate the flow and unit commitment solution:

```@example bids
using DuckDB, DataFrames

# Helper function
df_sql(con, s) = DataFrame(DuckDB.query(con, s))

df_sql(
    connection,
    """
    SELECT from_asset, to_asset, time_block_start AS timestep, solution,
    FROM var_flow
    WHERE solution != 0
    """,
)
```

and

```@example bids
df_sql(
    connection,
    """
    SELECT asset, solution,
    FROM var_units_on
    WHERE solution != 0
    """,
)
```

Now, we can see that bids 1, 2, and 4 are accepted.

### Testing more cases

To play around a little more, we can wrap this is a function and try a few cases:

```@example bids
function full_bid_run(bid_blocks; capacity, operational_cost)
    tulipa = create_new_problem(; capacity, operational_cost)
    for (bid_id, bid_block) in enumerate(bid_blocks)
        add_new_bid!(tulipa, bid_id, bid_block)
    end

    # Convert TulipaBuilder's data to TulipaEnergyModel format in the connection
    connection = create_connection(tulipa)

    # (Fake) cluster the profiles to generate representative periods
    TC.dummy_cluster!(connection)

    # Create the mode
    TEM.populate_with_defaults!(connection)
    energy_problem = TEM.EnergyProblem(connection)
    TEM.create_model!(energy_problem)

    # Modify the model
    add_exclusive_groups!(energy_problem, bid_blocks)

    # Solve the model
    TEM.solve_model!(energy_problem)
    TEM.save_solution!(energy_problem; compute_duals = true)

    flow_solution = Dict(
        (row.from_asset, row.to_asset, row.timestep) => row.solution
        for row in DuckDB.query(
            connection,
            """
            SELECT from_asset, to_asset, time_block_start AS timestep, solution,
            FROM var_flow
            WHERE solution != 0
            """,
        )
    )

    bid_id_lookup = Dict("bid$bid_id" => bid_id for bid_id = 1:length(bid_blocks))

    accepted_bids = [
        round(Int, bid_id_lookup[row.asset]) # The solution is returned as float
        for row in DuckDB.query(
            connection,
            """
            SELECT asset, solution,
            FROM var_units_on
            WHERE solution != 0
            """,
        )
    ]

    return energy_problem.objective_value, flow_solution, accepted_bids
end

energy_problem
```

Now that we have a function that runs the whole process based on the given bid blocks, the generator capacity, and the operational cost to deliver the generated energy, we can verify these cases:

- There is enough capacity to accept all bids and there is no generation cost, so we expect the all bids to be accepted. Notice that bids 2 and 3 are exclusive, so only bids 1, 2, and 4 are accepted.

```@example bids
_, _, accepted_bids = full_bid_run(bid_blocks; capacity = 999.9, operational_cost = 0.0)
@assert accepted_bids == [1, 2, 4]
```

- By restricting the capacity, we accepted bids will eventually change. The first breakpoint is at capacity = 50, because bids 2 and 4 requires 50 KW at time steps 2 and 3.
When capacity is slightly less than 50, bid 3 is dropped:

```@example bids
_, _, accepted_bids = full_bid_run(bid_blocks; capacity = 49.9, operational_cost = 0.0)
@assert accepted_bids == [1, 2]
```

- We also expect bid 4 to be dropped if the price is not higher than the operational cost:

```@example bids
_, _, accepted_bids = full_bid_run(bid_blocks; capacity = 999.9, operational_cost = 1.0)
@assert accepted_bids == [1, 2]
```

- Decreasing the capacity to slightly less than 40 KW, also makes us drop bid 2, but allows us to have more space to accept bids 3 and 4:

```@example bids
_, _, accepted_bids = full_bid_run(bid_blocks; capacity = 39.9, operational_cost = 0.0)
@assert accepted_bids == [1, 3, 4]
```

- In fact, because bid 3 can be curtailed to 80%, we can further decrease the capacity. Up to 35 KW, the same bids are still accepted:

```@example bids
a, b, accepted_bids = full_bid_run(bid_blocks; capacity = 35.0, operational_cost = 0.0)
@assert accepted_bids == [1, 3, 4]
```

- Slight less capacity forces the model to drop another bid. Although bid 4 is cheaper per KW, is requests more energy, to it is better.

```@example bids
a, b, accepted_bids = full_bid_run(bid_blocks; capacity = 34.9, operational_cost = 0.0)
@assert accepted_bids == [3, 4]
```

- But if the generation cost is too high, then bid 4 is dropped in favour of bid 1.

```@example bids
a, b, accepted_bids = full_bid_run(bid_blocks; capacity = 34.9, operational_cost = 1.0)
@assert accepted_bids == [1, 3]
```

### Visualization of the results

To help visualize the use of bids, we will vary the value of generator's capacity and the operational cost to get from the generator to the bid and create a few plots of the solutions.
We are doing the same as in the previous section, but systematically.

We will use some longer code that we'll hide, but that can be inspected in the [code for this file](https://github.com/TulipaEnergy/TulipaEnergyModel.jl/something). The code simply loops over many cases, like the section above, and saves data to be used in the plots below:

```@setup bids
using Plots

function compute_per_capacity(capacity_vector, operational_cost_vector)
    dim1 = length(capacity_vector)
    dim2 = length(operational_cost_vector)
    dim3 = length(bid_blocks)
    data = (
        row = Any[0 for _ in 1:dim1, _ in 1:dim2],
        capacity = capacity_vector .* ones(dim2)',
        operational_cost = ones(dim1) .* operational_cost_vector',
        total_flow = zeros(dim1, dim2),
        objective_value = zeros(dim1, dim2),
        maximum_flow = zeros(dim1, dim2),
        objective_value_per_bid = zeros(dim1, dim2, dim3),
        accepted_bids = fill(NaN, dim1, dim2, dim3),
    )

    for (idx1, capacity) in enumerate(capacity_vector),
        (idx2, operational_cost) in enumerate(operational_cost_vector)

        tulipa = create_new_problem(; capacity, operational_cost)
        for (bid_id, bid_block) in enumerate(bid_blocks)
            add_new_bid!(tulipa, bid_id, bid_block)
        end

        # Convert TulipaBuilder's data to TulipaEnergyModel format in the connection
        connection = create_connection(tulipa)

        # (Fake) cluster the profiles to generate representative periods
        TC.dummy_cluster!(connection)

        # Solve the scenario
        TEM.populate_with_defaults!(connection)
        energy_problem = TEM.EnergyProblem(connection)
        TEM.create_model!(energy_problem)

        # Modify the model
        add_exclusive_groups!(energy_problem, bid_blocks)

        # Solve the model
        TEM.solve_model!(energy_problem)
        TEM.save_solution!(energy_problem; compute_duals = true)

        data.objective_value[idx1, idx2] = energy_problem.objective_value
        for row in DuckDB.query(
            connection,
            """
            SELECT var_flow.from_asset, var_flow.to_asset, flow_milestone.operational_cost, var_flow.solution,
            FROM var_flow
            LEFT JOIN flow_milestone
                ON var_flow.from_asset = flow_milestone.from_asset
                AND var_flow.to_asset = flow_milestone.to_asset
            WHERE
                var_flow.from_asset = 'Consumer'
                AND var_flow.to_asset LIKE 'bid%'
                AND var_flow.solution != 0
            """,
        )
            bid_name = row.to_asset
            bid_id = parse(Int, bid_name[4:end])
            data.total_flow[idx1, idx2] += row.solution
            data.maximum_flow[idx1, idx2] = max(data.maximum_flow[idx1, idx2], row.solution)
            data.accepted_bids[idx1, idx2, bid_id] = bid_id
            data.objective_value_per_bid[idx1, idx2, bid_id] +=
                row.solution * (operational_cost + row.operational_cost)
            data.row[idx1, idx2] = row
        end
    end
    return data
end

capacity_vector = 0:55
operational_cost_vector = [0.1; 0.6; 1.1]
data = compute_per_capacity(capacity_vector, operational_cost_vector)
dim2 = length(operational_cost_vector)
dim3 = length(bid_blocks)

plts = Any[0 for _ in 1:dim2, _ in 1:3]
for (idx2, operational_cost) in enumerate(operational_cost_vector)
    plts[idx2, 1] = plot(
        capacity_vector,
        -data.objective_value[:, idx2];
        l = :steppost,
        lab = "profit",
        m = (1, :circle, stroke(0)),
        title = "operational cost = $operational_cost",
        ylabel = idx2 == 1 ? "profit = -objective" : "",
        ylims = (-10.0, 410.0),
        yticks = 0:100:400,
    )
    plts[idx2, 2] = scatter(
        capacity_vector,
        data.accepted_bids[:, idx2, :] .* [4; 1.5; 2 / 3; 0.25]';
        lab = ["bid$i" for _ in 1:1, i in 1:4],
        legend = :left,
        lw = 2,
        m = (3, :circle, stroke(0)),
        ylabel = idx2 == 1 ? "Accepted bids" : "",
        ylims = (0.5, 4.5),
        yticks = (1:4, ["4", "3", "2", "1"]),
    )
    plts[idx2, 3] = areaplot(
        capacity_vector,
        -data.objective_value_per_bid[:, idx2, :];
        fillalpha = 0.7,
        l = :steppost,
        lab = "bid" .* string.((1:dim3)'),
        legend = :left,
        lw = 0,
        xlabel = "capacity",
        ylabel = idx2 == 1 ? "profit per bid" : "",
        ylims = (-5.0, 305.0),
    )
end
```

```@example bids
# plts and dim2 are defined in the hidden code
plot(
    plts...;
    size = (300 * dim2, 3 * 200),
    layout = grid(3, dim2),
    leftmargin = 5Plots.mm,
    bottommargin = 4Plots.mm,
)
```

The plot has three columns and three rows.
The columns vary in operational cost, and the rows show three different kinds of plots.
The x-axis of all plots is the capacity.

The first row of plots show the profit made accepting these bids, per capacity.
The second row of plots show the accepted bids per capacity.
The plots in the third row show the profit made per capacity, but grouped per bid.

Some noteworthy points in the plots above:

- For operational cost = \$ 0.1 / KW, around capacity 35, bid 1 is slightly less profitable than bid 4, and there is only capacity for one of them (and bid 3), so the accepted bids change accordingly.
- For operational cost = \$ 0.6 / KW, this is not the case anymore, and thus bid 1 is always accepted.
- For operational cost = \$ 1.1 / KW, then it is never profitable to accept bid 4.
- The profit generated by bid 3 around capacity 16 to 20, and 31 to 35 is linearly increasing, since the bid 3 can be curtailed.
