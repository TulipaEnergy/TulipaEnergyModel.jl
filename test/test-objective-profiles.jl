@testitem "Commodity price part of flows_operational_cost is correct" tags = [:unit, :objective] setup =
    [CommonSetup] begin
    using DuckDB: DuckDB
    using TulipaBuilder: TulipaBuilder as TB
    using TulipaClustering: TulipaClustering as TC
    using Statistics

    commodity_price = 3.14
    producer_efficiency = 0.95
    operational_cost = 6.66
    commodity_price_profile = collect(1.0:6.0)

    function full_run(; add_commodity_price, add_commodity_price_profile)
        tulipa = TB.TulipaData()
        TB.add_asset!(tulipa, "Producer", :producer)
        TB.add_asset!(tulipa, "Consumer", :consumer)
        if add_commodity_price
            TB.add_flow!(
                tulipa,
                "Producer",
                "Consumer";
                commodity_price,
                producer_efficiency,
                operational_cost,
            )
        else
            TB.add_flow!(tulipa, "Producer", "Consumer"; producer_efficiency, operational_cost)
        end
        if add_commodity_price_profile
            TB.attach_profile!(
                tulipa,
                "Producer",
                "Consumer",
                :commodity_price,
                2030,
                commodity_price_profile,
            )
        else
            TB.attach_profile!(
                tulipa,
                "Producer",
                :availability,
                2030,
                zeros(length(commodity_price_profile)),
            )  # At least one profile is necessary (Maybe TulipaBuilder should allow it?)
        end
        TB.set_partition!(tulipa, "Producer", "Consumer", 2030, 1, "explicit", "1;2;3")

        connection = TB.create_connection(tulipa)
        TC.dummy_cluster!(connection)
        TEM.populate_with_defaults!(connection)
        energy_problem = TEM.EnergyProblem(connection)
        TEM.create_model!(energy_problem)

        var_flow = energy_problem.variables[:flow]
        partitions =
            Dict(row.id => row.time_block_start:row.time_block_end for row in var_flow.indices)
        flow_lookup = Dict(row.id => var_flow.container[row.id] for row in var_flow.indices)
        observed = energy_problem.model[:flows_operational_cost]

        return energy_problem, var_flow, partitions, flow_lookup, observed
    end

    # Without commodity_price
    energy_problem, var_flow, partitions, flow_lookup, observed =
        full_run(; add_commodity_price = false, add_commodity_price_profile = false)
    expected =
        sum(flow_lookup[i] * length(partitions[i]) * operational_cost for i in keys(partitions))
    @test expected == observed

    # Traditional commodity_price
    energy_problem, var_flow, partitions, flow_lookup, observed =
        full_run(; add_commodity_price = true, add_commodity_price_profile = false)
    expected = sum(
        flow_lookup[i] *
        length(partitions[i]) *
        (commodity_price / producer_efficiency + operational_cost) for i in keys(partitions)
    )
    @test expected == observed

    # Profile only, (default commodity_price = 0.0)
    @test_throws TEM.DataValidationException full_run(
        add_commodity_price = false,
        add_commodity_price_profile = true,
    )

    # Profile and commodity_price = 3.14
    energy_problem, var_flow, partitions, flow_lookup, observed =
        full_run(; add_commodity_price = true, add_commodity_price_profile = true)
    commodity_price_agg = Dict(
        i => commodity_price * Statistics.mean(commodity_price_profile[p]) for (i, p) in partitions
    )
    expected = sum(
        flow_lookup[i] *
        length(partitions[i]) *
        (commodity_price_agg[i] / producer_efficiency + operational_cost) for
        i in keys(partitions)
    )

    @test expected == observed
end

@testitem "Commodity price part of flows_operational_cost when one flow has profiles and the other doesn't" tags =
    [:unit, :objective] setup = [CommonSetup] begin
    using DuckDB: DuckDB
    using TulipaBuilder: TulipaBuilder as TB
    using TulipaClustering: TulipaClustering as TC
    using Statistics

    commodity_price = [3.14, 1.23]
    producer_efficiency = [0.95, 0.99]
    operational_cost = [6.66, 9.11]
    commodity_price_profile = collect(1.0:6.0)

    function full_run()
        tulipa = TB.TulipaData()
        TB.add_asset!(tulipa, "Consumer", :consumer)
        for i in 1:2
            producer_name = "Producer$i"
            TB.add_asset!(tulipa, producer_name, :producer)
            TB.add_flow!(
                tulipa,
                producer_name,
                "Consumer";
                commodity_price = commodity_price[i],
                producer_efficiency = producer_efficiency[i],
                operational_cost = operational_cost[i],
            )
        end
        # (Producer1,Consumer) doesn't have a commidity_price profile
        TB.attach_profile!(
            tulipa,
            "Producer2",
            "Consumer",
            :commodity_price,
            2030,
            commodity_price_profile,
        )
        TB.set_partition!(tulipa, "Producer1", "Consumer", 2030, 1, "explicit", "1;2;3")
        TB.set_partition!(tulipa, "Producer2", "Consumer", 2030, 1, "explicit", "3;1;2")

        connection = TB.create_connection(tulipa)
        TC.dummy_cluster!(connection)
        TEM.populate_with_defaults!(connection)
        energy_problem = TEM.EnergyProblem(connection)
        TEM.create_model!(energy_problem)

        var_flow = energy_problem.variables[:flow]
        partitions = [
            Dict(
                row.id => row.time_block_start:row.time_block_end for
                row in var_flow.indices if row.from_asset == "Producer$producer"
            ) for producer in 1:2
        ]
        flow_lookup = [
            Dict(
                row.id => var_flow.container[row.id] for
                row in var_flow.indices if row.from_asset == "Producer$producer"
            ) for producer in 1:2
        ]
        observed = energy_problem.model[:flows_operational_cost]

        return energy_problem, var_flow, partitions, flow_lookup, observed
    end

    energy_problem, var_flow, partitions, flow_lookup, observed = full_run()

    expected1 = sum(
        flow_lookup[1][i] *
        length(partitions[1][i]) *
        (commodity_price[1] / producer_efficiency[1] + operational_cost[1]) for
        i in keys(partitions[1])
    )
    commodity_price_agg = Dict(
        i => commodity_price[2] * Statistics.mean(commodity_price_profile[p]) for
        (i, p) in partitions[2]
    )
    expected2 = sum(
        flow_lookup[2][i] *
        length(partitions[2][i]) *
        (commodity_price_agg[i] / producer_efficiency[2] + operational_cost[2]) for
        i in keys(partitions[2])
    )

    @test expected1 + expected2 == observed
end
