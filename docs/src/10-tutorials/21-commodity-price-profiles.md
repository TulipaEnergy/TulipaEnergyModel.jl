# [Commodity Price Profiles](@id commodity-price-profiles)

In this tutorial, we will learn how to make the `commodity_price` of a flow vary over time with a profile.

This is useful when a producer has a time-varying fuel or commodity cost, but the rest of the flow data stays the same.

!!! warning
    A `commodity_price` profile does not replace `flow_milestone.commodity_price`.
    The profile **scales** the base `commodity_price`, so the flow must still have a positive `commodity_price` value.

## Set up the example

We will build a small example with two producers feeding the same demand:

- `"Gas"` has a base `commodity_price` and a `commodity_price` profile;
- `"Peaker"` has a flat operational cost and no `commodity_price` profile;
- `"Demand"` consumes 10 MWh in every time step.

When the commodity price multiplier is low, `"Gas"` should be cheaper.
When the multiplier is high, `"Peaker"` should become cheaper.

```@example commodity-price-profiles
using TulipaBuilder: TulipaBuilder as TB
using TulipaClustering: TulipaClustering as TC
using TulipaEnergyModel: TulipaEnergyModel as TEM
using TulipaIO: TulipaIO as TIO
using DataFrames

year = 2030
num_timesteps = 6
commodity_price_profile = [0.5, 0.5, 0.5, 2.0, 2.0, 2.0]

function create_problem(; use_commodity_price_profile)
    tulipa = TB.TulipaData()

    TB.add_asset!(tulipa, "Gas", :producer; capacity = 10.0, initial_units = 1.0)
    TB.add_asset!(tulipa, "Peaker", :producer; capacity = 10.0, initial_units = 1.0)
    TB.add_asset!(tulipa, "Demand", :consumer; peak_demand = 10.0)

    TB.add_flow!(
        tulipa,
        "Gas",
        "Demand";
        commodity_price = 20.0,
        producer_efficiency = 1.0,
        operational_cost = 5.0,
    )
    TB.add_flow!(
        tulipa,
        "Peaker",
        "Demand";
        operational_cost = 30.0,
    )

    TB.attach_profile!(tulipa, "Demand", :demand, year, ones(num_timesteps))
    if use_commodity_price_profile
        TB.attach_profile!(
            tulipa,
            "Gas",
            "Demand",
            :commodity_price,
            year,
            commodity_price_profile,
        )
    end

    return tulipa
end

function solve_problem(; use_commodity_price_profile)
    tulipa = create_problem(; use_commodity_price_profile)
    connection = TB.create_connection(tulipa, TEM.schema)
    TC.dummy_cluster!(connection; layout = TC.ProfilesTableLayout(year = :milestone_year))
    TEM.populate_with_defaults!(connection)
    energy_problem = TEM.run_scenario(connection; show_log = false)
    return connection, energy_problem
end

function dispatch_by_timestep(connection)
    flows = TIO.get_table(connection, "var_flow")
    filtered_flow = filter(row -> row.to_asset == "Demand", flows)[
        :,
        [:time_block_start, :from_asset, :solution],
    ]
    rename!(filtered_flow, :time_block_start => :timestep)
    sort!(filtered_flow, [:timestep, :from_asset])
    return unstack(filtered_flow, :timestep, :from_asset, :solution; fill = 0.0)
end
```

!!! tip
    If you use representative periods or coarser partitions, Tulipa aggregates the
    `commodity_price` profile inside each time block before using it in the objective.

## Solve without the profile

First, solve the problem without attaching the `commodity_price` profile:

```@example commodity-price-profiles
connection_flat, energy_problem_flat = solve_problem(use_commodity_price_profile = false)

dispatch_by_timestep(connection_flat)
```

The `"Gas"` flow supplies all demand because its flat cost is:

```math
\frac{20.0}{1.0} + 5.0 = 25.0
```

which is lower than the `"Peaker"` cost of `30.0`.

## Attach the commodity price profile

Now solve the same problem with the profile attached to the `"Gas" -> "Demand"` flow:

```@example commodity-price-profiles
connection_profile, energy_problem_profile = solve_problem(use_commodity_price_profile = true)

TIO.get_table(connection_profile, "flows_profiles")
```

The `flows_profiles` table confirms that the profile is linked to the flow with
`profile_type = "commodity_price"`.

Let us inspect the resulting dispatch:

```@example commodity-price-profiles
dispatch_by_timestep(connection_profile)
```

Now `"Gas"` is used in the first three time steps and `"Peaker"` in the last three.
That happens because the profile multiplies the base `commodity_price = 20.0`:

- For time steps 1 to 3, the multiplier is `0.5`, so the total variable cost is `20.0 * 0.5 + 5.0 = 15.0`;
- For time steps 4 to 6, the multiplier is `2.0`, so the total variable cost is `20.0 * 2.0 + 5.0 = 45.0`.

Therefore, `"Gas"` is cheaper at the beginning, but `"Peaker"` is cheaper at the end.

We can also compare the objective values:

```@example commodity-price-profiles
(
    without_profile = energy_problem_flat.objective_value,
    with_profile = energy_problem_profile.objective_value,
)
```

## Summary

To use a `commodity_price` profile:

1. Set a positive `commodity_price` in the flow data;
2. Attach a profile to the flow with `profile_type = :commodity_price`;
3. Run the workflow as usual.

This lets Tulipa account for time-varying commodity costs directly in the operational objective.
