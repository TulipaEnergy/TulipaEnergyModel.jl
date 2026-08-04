@testsnippet ConsCapacityOutgoingCompactEfficienciesSetup begin
    using TulipaClustering: TulipaClustering as TC

    function create_capacity_outgoing_compact_efficiencies_problem()
        tulipa = TB.TulipaData()

        TB.add_asset!(
            tulipa,
            "wind",
            :producer;
            vintage_method = "compact_efficiencies",
            capacity = 50.0,
        )
        TB.add_asset!(tulipa, "demand", :consumer; peak_demand = 0.0)
        TB.add_asset!(tulipa, "battery", :consumer; peak_demand = 0.0)

        # Explicitly define the compact-efficiencies vintages to match the test target.
        TB.attach_milestone_data!(tulipa, "wind", 2030; investable = true)
        TB.attach_milestone_data!(tulipa, "wind", 2050; investable = true)
        TB.attach_commission_data!(tulipa, "wind", 2030)
        TB.attach_commission_data!(tulipa, "wind", 2050)
        TB.attach_both_years_data!(
            tulipa,
            "wind",
            2020,
            2030;
            initial_units = 1.0,
            decommissionable = true,
        )
        TB.attach_both_years_data!(
            tulipa,
            "wind",
            2030,
            2030;
            initial_units = 1.0,
            decommissionable = true,
        )
        TB.attach_both_years_data!(
            tulipa,
            "wind",
            2030,
            2050;
            initial_units = 1.0,
            decommissionable = true,
        )
        TB.attach_both_years_data!(
            tulipa,
            "wind",
            2050,
            2050;
            initial_units = 1.0,
            decommissionable = true,
        )

        TB.add_flow!(tulipa, "wind", "demand")
        TB.add_flow!(tulipa, "wind", "battery")
        for to_asset in ("demand", "battery")
            TB.attach_milestone_data!(tulipa, "wind", to_asset, 2030)
            TB.attach_milestone_data!(tulipa, "wind", to_asset, 2050)
            TB.attach_commission_data!(tulipa, "wind", to_asset, 2020)
            TB.attach_commission_data!(tulipa, "wind", to_asset, 2030)
            TB.attach_commission_data!(tulipa, "wind", to_asset, 2050)
        end

        TB.attach_profile!(tulipa, "wind", :availability, 2020, [1.0])
        TB.attach_profile!(tulipa, "wind", :availability, 2030, [1.0])
        TB.attach_profile!(tulipa, "wind", :availability, 2050, [1.0])

        connection = TB.create_connection(tulipa, TEM.schema)
        layout = TC.ProfilesTableLayout(; year = :milestone_year)
        TC.dummy_cluster!(connection; layout)

        TEM.populate_with_defaults!(connection)
        energy_problem = TEM.EnergyProblem(connection)
        TEM.create_model!(energy_problem)

        return energy_problem
    end
end

@testitem "Test add_capacity_outgoing_compact_efficiencies_vintage_method_constraints!" setup =
    [CommonSetup, ConsCapacityOutgoingCompactEfficienciesSetup] tags = [:unit, :constraint, :fast] begin
    energy_problem = create_capacity_outgoing_compact_efficiencies_problem()

    connection = energy_problem.db_connection
    model = energy_problem.model
    profiles = energy_problem.profiles

    vintage_flow = energy_problem.variables[:vintage_flow].container
    expr_avail_compact_method =
        energy_problem.expressions[:available_asset_units_compact_vintage_method].expressions[:assets]

    selected_rows = DuckDB.query(
        connection,
        "SELECT id, milestone_year, commission_year, rep_period
         FROM cons_capacity_outgoing_compact_efficiencies_vintage_method
         WHERE milestone_year IN (2030, 2050)
         ORDER BY milestone_year, commission_year",
    )
    selected_constraint_ids = [row.id for row in selected_rows]
    selected_rep_periods = [row.rep_period for row in selected_rows]

    selected_var_battery_ids = [
        row.id for row in DuckDB.query(
            connection,
            "SELECT id
             FROM var_vintage_flow
             WHERE from_asset = 'wind' AND to_asset = 'battery' AND milestone_year IN (2030, 2050)
             ORDER BY milestone_year, commission_year",
        )
    ]
    selected_var_demand_ids = [
        row.id for row in DuckDB.query(
            connection,
            "SELECT id
             FROM var_vintage_flow
             WHERE from_asset = 'wind' AND to_asset = 'demand' AND milestone_year IN (2030, 2050)
             ORDER BY milestone_year, commission_year",
        )
    ]
    selected_expr_ids = [
        row.id for row in DuckDB.query(
            connection,
            "SELECT id
             FROM expr_available_asset_units_compact_vintage_method
             WHERE milestone_year IN (2030, 2050)
             ORDER BY milestone_year, commission_year",
        )
    ]

    var_vintage_flow_wind_battery = vintage_flow[selected_var_battery_ids]
    var_vintage_flow_wind_demand = vintage_flow[selected_var_demand_ids]
    selected_expr_avail_compact_method = expr_avail_compact_method[selected_expr_ids]

    expected_profiles = [
        if haskey(profiles.rep_period, ("wind-availability-2020", 2030, selected_rep_periods[1]))
            profiles.rep_period[("wind-availability-2020", 2030, selected_rep_periods[1])].values[1]
        else
            1.0
        end,
        if haskey(profiles.rep_period, ("wind-availability-2030", 2030, selected_rep_periods[2]))
            profiles.rep_period[("wind-availability-2030", 2030, selected_rep_periods[2])].values[1]
        else
            1.0
        end,
        if haskey(profiles.rep_period, ("wind-availability-2030", 2050, selected_rep_periods[3]))
            profiles.rep_period[("wind-availability-2030", 2050, selected_rep_periods[3])].values[1]
        else
            1.0
        end,
        if haskey(profiles.rep_period, ("wind-availability-2050", 2050, selected_rep_periods[4]))
            profiles.rep_period[("wind-availability-2050", 2050, selected_rep_periods[4])].values[1]
        else
            1.0
        end,
    ]
    capacity = 50
    expected_cons = [
        JuMP.@build_constraint(var_battery + var_demand ≤ capacity * profile * expr) for
        (var_battery, var_demand, profile, expr) in zip(
            var_vintage_flow_wind_battery,
            var_vintage_flow_wind_demand,
            expected_profiles,
            selected_expr_avail_compact_method,
        )
    ]

    observed_cons =
        _get_cons_object(model, :max_output_flows_limit_compact_efficiencies_vintage_method)[selected_constraint_ids]
    @test _is_constraint_equal(expected_cons, observed_cons)
end
