@testitem "Test add_limit_decommission_constraints!" setup = [CommonSetup] tags =
    [:unit, :constraint, :fast] begin
    connection = _multi_year_fixture()
    model = JuMP.Model()

    table_name = "var_assets_investment"
    table_rows = [
        (1, "battery", 2030, true, 50, 0, Inf),
        (2, "battery", 2040, true, 50, 0, Inf),
        (3, "battery", 2050, true, 50, 0, Inf),
    ]
    columns = [
        :id,
        :asset,
        :milestone_year,
        :investment_integer,
        :capacity,
        :investment_min_limit,
        :investment_max_limit,
    ]
    _create_table_for_tests(connection, table_name, table_rows, columns)

    # The 2030 vintage can be decommissioned in both 2040 and 2050, so its limit must sum both
    # decisions; the 2040 vintage can only be decommissioned in 2050
    table_name = "var_assets_decommission"
    table_rows = [
        (1, "battery", 2040, 2030, true),
        (2, "battery", 2050, 2030, true),
        (3, "battery", 2050, 2040, true),
    ]
    columns = [:id, :asset, :milestone_year, :commission_year, :investment_integer]
    _create_table_for_tests(connection, table_name, table_rows, columns)

    for table_name in ("var_flows_investment", "var_flows_decommission")
        columns_with_types = [
            :id => Int,
            :from_asset => String,
            :to_asset => String,
            :milestone_year => Int,
            :commission_year => Int,
            :investment_integer => Bool,
            :capacity => Float64,
            :investment_min_limit => Float64,
            :investment_max_limit => Float64,
        ]
        _create_empty_table_for_tests(connection, table_name, columns_with_types)
    end

    for table_name in ("var_assets_investment_energy", "var_assets_decommission_energy")
        columns_with_types = [
            :id => Int,
            :asset => String,
            :milestone_year => Int,
            :commission_year => Int,
            :investment_integer_storage_energy => Bool,
            :capacity_storage_energy => Float64,
            :investment_min_limit_storage_energy => Float64,
            :investment_max_limit_storage_energy => Float64,
        ]
        _create_empty_table_for_tests(connection, table_name, columns_with_types)
    end

    variables = Dict{Symbol,TulipaEnergyModel.TulipaVariable}(
        key => TulipaEnergyModel.TulipaVariable(connection, "var_$key") for key in (
            :assets_investment,
            :assets_decommission,
            :flows_investment,
            :flows_decommission,
            :assets_investment_energy,
            :assets_decommission_energy,
        )
    )
    TulipaEnergyModel.add_investment_variables!(model, variables)
    TulipaEnergyModel.add_decommission_variables!(model, variables)

    table_name = "cons_limit_decommission_assets"
    table_rows = [(1, "battery", 2030), (2, "battery", 2040)]
    columns = [:id, :asset, :commission_year]
    _create_table_for_tests(connection, table_name, table_rows, columns)
    _create_empty_table_for_tests(
        connection,
        "cons_limit_decommission_storage_energy",
        [:id => Int, :asset => String, :commission_year => Int],
    )
    _create_empty_table_for_tests(
        connection,
        "cons_limit_decommission_flows",
        [:id => Int, :from_asset => String, :to_asset => String, :commission_year => Int],
    )

    constraints = Dict{Symbol,TulipaEnergyModel.TulipaConstraint}(
        key => TulipaEnergyModel.TulipaConstraint(connection, "cons_$key") for key in (
            :limit_decommission_assets,
            :limit_decommission_storage_energy,
            :limit_decommission_flows,
        )
    )

    add_limit_decommission_constraints!(connection, model, variables, constraints)

    var_inv = variables[:assets_investment].container
    var_dec = variables[:assets_decommission].container

    @test _is_constraint_equal(
        [
            JuMP.@build_constraint(var_inv[1] - var_dec[1] - var_dec[2] ≥ 0),
            JuMP.@build_constraint(var_inv[2] - var_dec[3] ≥ 0),
        ],
        _get_cons_object(model, :limit_decommission_assets),
    )
    @test isempty(_get_cons_object(model, :limit_decommission_storage_energy))
    @test isempty(_get_cons_object(model, :limit_decommission_flows))
end

@testsnippet LimitDecommissionSetup begin
    # Build the full model for the multi-year fixture, optionally overriding the technical lifetime
    # of some assets, e.g., the battery (aggregated vintage method) or the wind (compact profiles),
    # both investable and decommissionable in 2030 and 2050, or of some transport flows, e.g.,
    # ccgt -> demand, investable and decommissionable in 2030 and 2050.
    # The ccgt (compact efficiencies) is neither investable nor decommissionable in the fixture;
    # `decommissionable_ccgt = true` makes its 2030 vintage investable and decommissionable in 2050
    function _create_multi_year_problem(;
        technical_lifetimes = Dict{String,Int}(),
        flow_technical_lifetimes = Dict{Tuple{String,String},Int}(),
        decommissionable_ccgt = false,
    )
        connection = _multi_year_fixture()
        for (asset, technical_lifetime) in technical_lifetimes
            DuckDB.query(
                connection,
                "UPDATE asset SET technical_lifetime = $technical_lifetime WHERE asset = '$asset'",
            )
        end
        for ((from_asset, to_asset), technical_lifetime) in flow_technical_lifetimes
            DuckDB.query(
                connection,
                "UPDATE flow SET technical_lifetime = $technical_lifetime
                WHERE from_asset = '$from_asset' AND to_asset = '$to_asset'",
            )
        end
        if decommissionable_ccgt
            DuckDB.query(
                connection,
                "UPDATE asset_milestone SET investable = true
                WHERE asset = 'ccgt' AND milestone_year = 2030;
                UPDATE asset_both SET decommissionable = true
                WHERE asset = 'ccgt' AND commission_year = 2030;
                INSERT INTO asset_both
                    (asset, milestone_year, commission_year, decommissionable, initial_units, initial_storage_units)
                VALUES ('ccgt', 2050, 2030, true, 1.0, 0.0);
                ",
            )
        end
        TulipaEnergyModel.populate_with_defaults!(connection)
        energy_problem = TulipaEnergyModel.EnergyProblem(connection)
        TulipaEnergyModel.create_model!(energy_problem)
        return energy_problem
    end

    function _rows(connection, table_name, condition)
        return [
            (row.milestone_year, row.commission_year) for row in DuckDB.query(
                connection,
                "SELECT milestone_year, commission_year FROM $table_name
                WHERE $condition ORDER BY milestone_year, commission_year",
            )
        ]
    end

    function _variable(energy_problem, table_name, variable_name; kwargs...)
        condition = join(
            (
                value isa AbstractString ? "$key = '$value'" : "$key = $value" for
                (key, value) in kwargs
            ),
            " AND ",
        )
        id = only([
            row.id for row in
            DuckDB.query(energy_problem.db_connection, "FROM $table_name WHERE $condition")
        ])
        return energy_problem.variables[variable_name].container[id]
    end

    function _expression(energy_problem, expression_name, sub_expression; kwargs...)
        condition = join(
            (
                value isa AbstractString ? "$key = '$value'" : "$key = $value" for
                (key, value) in kwargs
            ),
            " AND ",
        )
        id = only([
            row.id for row in DuckDB.query(
                energy_problem.db_connection,
                "FROM expr_$expression_name WHERE $condition",
            )
        ])
        return energy_problem.expressions[expression_name].expressions[sub_expression][id]
    end
end

@testitem "Decommission variables exist only for units invested by the model" setup =
    [CommonSetup, LimitDecommissionSetup] tags = [:integration, :variable, :fast] begin
    energy_problem = _create_multi_year_problem()
    connection = energy_problem.db_connection

    # Battery (aggregated, technical lifetime 30): the 2030 investment is alive in 2050 and can be
    # decommissioned there. The existing units of 2030 and 2050 are never decommissioned.
    @test _rows(connection, "var_assets_decommission", "asset = 'battery'") == [(2050, 2030)]
    @test _rows(connection, "var_assets_decommission_energy", "asset = 'battery'") == [(2050, 2030)]

    # Wind (compact profiles): asset_both lists the vintages 2020 and 2030 as decommissionable, but
    # only 2030 is an investable milestone year, and only after its commission year
    @test _rows(connection, "var_assets_decommission", "asset = 'wind'") == [(2050, 2030)]

    # Non-decommissionable assets have no rows
    @test isempty(_rows(connection, "var_assets_decommission", "asset = 'ccgt'"))
    @test isempty(_rows(connection, "var_assets_decommission", "asset = 'ocgt'"))

    # Transport flow ccgt -> demand (technical lifetime 40)
    @test _rows(
        connection,
        "var_flows_decommission",
        "from_asset = 'ccgt' AND to_asset = 'demand'",
    ) == [(2050, 2030)]

    # With a technical lifetime shorter than the gap between milestone years, the 2030 investment
    # is not alive in 2050, so there is nothing to decommission. For the compact method, this
    # holds even though asset_both still lists the 2030 vintage of wind in 2050
    energy_problem =
        _create_multi_year_problem(; technical_lifetimes = Dict("battery" => 15, "wind" => 15))
    connection = energy_problem.db_connection
    @test isempty(_rows(connection, "var_assets_decommission", "asset = 'battery'"))
    @test isempty(_rows(connection, "var_assets_decommission_energy", "asset = 'battery'"))
    @test isempty(_rows(connection, "var_assets_decommission", "asset = 'wind'"))

    # The same holds for the transport flow: the 2030 investment cannot be decommissioned in 2050
    energy_problem =
        _create_multi_year_problem(; flow_technical_lifetimes = Dict(("ccgt", "demand") => 15))
    connection = energy_problem.db_connection
    @test isempty(
        _rows(connection, "var_flows_decommission", "from_asset = 'ccgt' AND to_asset = 'demand'"),
    )
end

@testitem "Decommission variable tables keep the documented associated input parameters" setup =
    [CommonSetup, LimitDecommissionSetup] tags = [:integration, :variable, :fast] begin
    # The associated input parameters of each table are listed in docs/src/20-user-guide/55-outputs.md
    energy_problem = _create_multi_year_problem()
    connection = energy_problem.db_connection
    _columns(table_name) =
        [row.column_name for row in DuckDB.query(connection, "DESCRIBE $table_name")]
    @test _columns("var_assets_decommission") == [
        "id",
        "asset",
        "milestone_year",
        "commission_year",
        "decommissionable",
        "investment_integer",
        "capacity",
        "solution",
    ]
    @test _columns("var_flows_decommission") == [
        "id",
        "from_asset",
        "to_asset",
        "milestone_year",
        "commission_year",
        "decommissionable",
        "investment_integer",
        "capacity",
        "solution",
    ]
    @test _columns("var_assets_decommission_energy") == [
        "id",
        "asset",
        "milestone_year",
        "commission_year",
        "decommissionable",
        "investment_integer_storage_energy",
        "capacity_storage_energy",
        "solution",
    ]
    # The parameters take the values of the input tables of the decommissioned units
    battery = only(
        DuckDB.query(
            connection,
            "SELECT decommissionable, investment_integer, capacity FROM var_assets_decommission
            WHERE asset = 'battery'",
        ),
    )
    @test (battery.decommissionable, battery.investment_integer, battery.capacity) ==
          (true, true, 50.0)
    flow = only(
        DuckDB.query(
            connection,
            "SELECT decommissionable, investment_integer, capacity FROM var_flows_decommission
            WHERE from_asset = 'ccgt' AND to_asset = 'demand'",
        ),
    )
    @test (flow.decommissionable, flow.investment_integer, flow.capacity) == (true, false, 100.0)
end

@testitem "Available units expressions keep the initial units and subtract vintage decommissions" setup =
    [CommonSetup, LimitDecommissionSetup] tags = [:integration, :constraint, :fast] begin
    energy_problem = _create_multi_year_problem()
    model = energy_problem.model
    inv(year) = _variable(
        energy_problem,
        "var_assets_investment",
        :assets_investment;
        asset = "battery",
        milestone_year = year,
    )
    dec_2050_2030 = _variable(
        energy_problem,
        "var_assets_decommission",
        :assets_decommission;
        asset = "battery",
        milestone_year = 2050,
        commission_year = 2030,
    )
    avail(year) = _expression(
        energy_problem,
        :available_asset_units_aggregated_vintage_method,
        :assets;
        asset = "battery",
        milestone_year = year,
    )
    @test JuMP.isequal_canonical(avail(2030), JuMP.@expression(model, 1.09 + inv(2030)))
    @test JuMP.isequal_canonical(
        avail(2050),
        JuMP.@expression(model, 2.02 + inv(2030) + inv(2050) - dec_2050_2030),
    )

    # Compact profiles: the 2030 vintage of wind in 2050 has existing units, the investment, and
    # the decommission of the investment
    inv_wind_2030 = _variable(
        energy_problem,
        "var_assets_investment",
        :assets_investment;
        asset = "wind",
        milestone_year = 2030,
    )
    dec_wind = _variable(
        energy_problem,
        "var_assets_decommission",
        :assets_decommission;
        asset = "wind",
        milestone_year = 2050,
        commission_year = 2030,
    )
    avail_wind(year, vintage) = _expression(
        energy_problem,
        :available_asset_units_compact_vintage_method,
        :assets;
        asset = "wind",
        milestone_year = year,
        commission_year = vintage,
    )
    @test JuMP.isequal_canonical(avail_wind(2030, 2020), JuMP.AffExpr(0.07))
    @test JuMP.isequal_canonical(
        avail_wind(2030, 2030),
        JuMP.@expression(model, 0.02 + inv_wind_2030),
    )
    @test JuMP.isequal_canonical(
        avail_wind(2050, 2030),
        JuMP.@expression(model, 0.02 + inv_wind_2030 - dec_wind),
    )

    # Technical lifetime of 15 years: the 2030 investment is gone by 2050, for both vintage methods
    energy_problem =
        _create_multi_year_problem(; technical_lifetimes = Dict("battery" => 15, "wind" => 15))
    model = energy_problem.model
    inv(year) = _variable(
        energy_problem,
        "var_assets_investment",
        :assets_investment;
        asset = "battery",
        milestone_year = year,
    )
    avail(year) = _expression(
        energy_problem,
        :available_asset_units_aggregated_vintage_method,
        :assets;
        asset = "battery",
        milestone_year = year,
    )
    @test JuMP.isequal_canonical(avail(2030), JuMP.@expression(model, 1.09 + inv(2030)))
    @test JuMP.isequal_canonical(avail(2050), JuMP.@expression(model, 2.02 + inv(2050)))
    avail_wind(year, vintage) = _expression(
        energy_problem,
        :available_asset_units_compact_vintage_method,
        :assets;
        asset = "wind",
        milestone_year = year,
        commission_year = vintage,
    )
    @test JuMP.isequal_canonical(avail_wind(2050, 2030), JuMP.AffExpr(0.02))
end

@testitem "Decommission limits bound each vintage by its investment" setup =
    [CommonSetup, LimitDecommissionSetup] tags = [:integration, :constraint, :fast] begin
    energy_problem = _create_multi_year_problem()
    model = energy_problem.model

    # Assets: one constraint per (asset, vintage) for both vintage methods
    inv_battery = _variable(
        energy_problem,
        "var_assets_investment",
        :assets_investment;
        asset = "battery",
        milestone_year = 2030,
    )
    dec_battery = _variable(
        energy_problem,
        "var_assets_decommission",
        :assets_decommission;
        asset = "battery",
        milestone_year = 2050,
        commission_year = 2030,
    )
    inv_wind = _variable(
        energy_problem,
        "var_assets_investment",
        :assets_investment;
        asset = "wind",
        milestone_year = 2030,
    )
    dec_wind = _variable(
        energy_problem,
        "var_assets_decommission",
        :assets_decommission;
        asset = "wind",
        milestone_year = 2050,
        commission_year = 2030,
    )
    @test _is_constraint_equal(
        [
            JuMP.@build_constraint(inv_battery - dec_battery ≥ 0),
            JuMP.@build_constraint(inv_wind - dec_wind ≥ 0),
        ],
        _get_cons_object(model, :limit_decommission_assets),
    )

    # Storage energy
    inv_energy = _variable(
        energy_problem,
        "var_assets_investment_energy",
        :assets_investment_energy;
        asset = "battery",
        milestone_year = 2030,
    )
    dec_energy = _variable(
        energy_problem,
        "var_assets_decommission_energy",
        :assets_decommission_energy;
        asset = "battery",
        milestone_year = 2050,
        commission_year = 2030,
    )
    @test _is_constraint_equal(
        [JuMP.@build_constraint(inv_energy - dec_energy ≥ 0)],
        _get_cons_object(model, :limit_decommission_storage_energy),
    )
    inv_energy_2050 = _variable(
        energy_problem,
        "var_assets_investment_energy",
        :assets_investment_energy;
        asset = "battery",
        milestone_year = 2050,
    )
    @test JuMP.isequal_canonical(
        _expression(
            energy_problem,
            :available_energy_units_aggregated_vintage_method,
            :energy;
            asset = "battery",
            milestone_year = 2050,
        ),
        JuMP.@expression(model, 0.0 + inv_energy + inv_energy_2050 - dec_energy),
    )

    # Transport flows (investable in 2030 and 2050)
    inv_flow = _variable(
        energy_problem,
        "var_flows_investment",
        :flows_investment;
        from_asset = "ccgt",
        to_asset = "demand",
        milestone_year = 2030,
    )
    inv_flow_2050 = _variable(
        energy_problem,
        "var_flows_investment",
        :flows_investment;
        from_asset = "ccgt",
        to_asset = "demand",
        milestone_year = 2050,
    )
    dec_flow = _variable(
        energy_problem,
        "var_flows_decommission",
        :flows_decommission;
        from_asset = "ccgt",
        to_asset = "demand",
        milestone_year = 2050,
        commission_year = 2030,
    )
    @test _is_constraint_equal(
        [JuMP.@build_constraint(inv_flow - dec_flow ≥ 0)],
        _get_cons_object(model, :limit_decommission_flows),
    )
    for direction in (:export, :import)
        @test JuMP.isequal_canonical(
            _expression(
                energy_problem,
                :available_flow_units_aggregated_vintage_method,
                direction;
                from_asset = "ccgt",
                to_asset = "demand",
                milestone_year = 2050,
            ),
            JuMP.@expression(model, 0.0 + inv_flow + inv_flow_2050 - dec_flow),
        )
    end

    # Technical lifetime of 15 years: the 2030 flow investment is gone by 2050, so there is no
    # decommission limit and only the 2050 investment is available
    energy_problem =
        _create_multi_year_problem(; flow_technical_lifetimes = Dict(("ccgt", "demand") => 15))
    model = energy_problem.model
    @test isempty(_get_cons_object(model, :limit_decommission_flows))
    inv_flow_2050 = _variable(
        energy_problem,
        "var_flows_investment",
        :flows_investment;
        from_asset = "ccgt",
        to_asset = "demand",
        milestone_year = 2050,
    )
    for direction in (:export, :import)
        @test JuMP.isequal_canonical(
            _expression(
                energy_problem,
                :available_flow_units_aggregated_vintage_method,
                direction;
                from_asset = "ccgt",
                to_asset = "demand",
                milestone_year = 2050,
            ),
            JuMP.@expression(model, 0.0 + inv_flow_2050),
        )
    end
end

@testitem "Compact efficiencies decommissions follow the same vintage rules as compact profiles" setup =
    [CommonSetup, LimitDecommissionSetup] tags = [:integration, :constraint, :fast] begin
    energy_problem = _create_multi_year_problem(; decommissionable_ccgt = true)
    connection = energy_problem.db_connection
    model = energy_problem.model

    # Ccgt (compact efficiencies, technical lifetime 25): the 2025 vintage is not investable, so
    # only the 2030 investment can be decommissioned, and only in 2050
    @test _rows(connection, "var_assets_decommission", "asset = 'ccgt'") == [(2050, 2030)]

    inv_ccgt = _variable(
        energy_problem,
        "var_assets_investment",
        :assets_investment;
        asset = "ccgt",
        milestone_year = 2030,
    )
    dec_ccgt = _variable(
        energy_problem,
        "var_assets_decommission",
        :assets_decommission;
        asset = "ccgt",
        milestone_year = 2050,
        commission_year = 2030,
    )
    avail_ccgt(year, vintage) = _expression(
        energy_problem,
        :available_asset_units_compact_vintage_method,
        :assets;
        asset = "ccgt",
        milestone_year = year,
        commission_year = vintage,
    )
    @test JuMP.isequal_canonical(avail_ccgt(2030, 2025), JuMP.AffExpr(1.0))
    @test JuMP.isequal_canonical(avail_ccgt(2030, 2030), JuMP.@expression(model, 1.0 + inv_ccgt))
    @test JuMP.isequal_canonical(
        avail_ccgt(2050, 2030),
        JuMP.@expression(model, 1.0 + inv_ccgt - dec_ccgt),
    )
    @test JuMP.isequal_canonical(avail_ccgt(2050, 2050), JuMP.AffExpr(1.0))

    # The decommission limit of the ccgt vintage sits between the battery and the wind ones
    inv_battery = _variable(
        energy_problem,
        "var_assets_investment",
        :assets_investment;
        asset = "battery",
        milestone_year = 2030,
    )
    dec_battery = _variable(
        energy_problem,
        "var_assets_decommission",
        :assets_decommission;
        asset = "battery",
        milestone_year = 2050,
        commission_year = 2030,
    )
    inv_wind = _variable(
        energy_problem,
        "var_assets_investment",
        :assets_investment;
        asset = "wind",
        milestone_year = 2030,
    )
    dec_wind = _variable(
        energy_problem,
        "var_assets_decommission",
        :assets_decommission;
        asset = "wind",
        milestone_year = 2050,
        commission_year = 2030,
    )
    @test _is_constraint_equal(
        [
            JuMP.@build_constraint(inv_battery - dec_battery ≥ 0),
            JuMP.@build_constraint(inv_ccgt - dec_ccgt ≥ 0),
            JuMP.@build_constraint(inv_wind - dec_wind ≥ 0),
        ],
        _get_cons_object(model, :limit_decommission_assets),
    )

    # Technical lifetime of 15 years: the 2030 investment is gone by 2050, so there is nothing to
    # decommission and only the existing units of the vintage remain
    energy_problem = _create_multi_year_problem(;
        technical_lifetimes = Dict("ccgt" => 15),
        decommissionable_ccgt = true,
    )
    connection = energy_problem.db_connection
    @test isempty(_rows(connection, "var_assets_decommission", "asset = 'ccgt'"))
    avail_ccgt(year, vintage) = _expression(
        energy_problem,
        :available_asset_units_compact_vintage_method,
        :assets;
        asset = "ccgt",
        milestone_year = year,
        commission_year = vintage,
    )
    @test JuMP.isequal_canonical(avail_ccgt(2050, 2030), JuMP.AffExpr(1.0))
    @test [
        row.asset for row in
        DuckDB.query(connection, "SELECT asset FROM cons_limit_decommission_assets ORDER BY asset")
    ] == ["battery", "wind"]
end
