@testitem "Test add_limit_decommission_aggregated_method_constraints!" setup = [CommonSetup] tags =
    [:unit, :constraint, :fast] begin
    # The battery in the multi-year fixture uses the aggregated vintage method with a technical
    # lifetime of 30 years, so a decision taken in 2030 is still within the lifetime window in 2050
    connection = _multi_year_fixture()
    model = JuMP.Model()

    table_name = "var_assets_investment"
    table_rows = [(1, "battery", 2030, true, 50, 0, Inf), (2, "battery", 2050, true, 50, 0, Inf)]
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

    # Rows 1 and 3 decommission existing units, row 2 decommissions the units invested in 2030
    table_name = "var_assets_decommission"
    table_rows = [
        (1, "battery", 2030, 2030, true),
        (2, "battery", 2050, 2030, true),
        (3, "battery", 2050, 2050, true),
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

    table_name = "cons_limit_decommission_initial_units_aggregated_vintage_method"
    table_rows = [(1, "battery", 2030, 1.09), (2, "battery", 2050, 2.02)]
    columns = [:id, :asset, :milestone_year, :initial_units]
    _create_table_for_tests(connection, table_name, table_rows, columns)

    table_name = "cons_limit_decommission_invested_units_aggregated_vintage_method"
    table_rows = [(1, "battery", 2030)]
    columns = [:id, :asset, :commission_year]
    _create_table_for_tests(connection, table_name, table_rows, columns)

    constraints = Dict{Symbol,TulipaEnergyModel.TulipaConstraint}(
        key => TulipaEnergyModel.TulipaConstraint(connection, "cons_$key") for key in (
            :limit_decommission_initial_units_aggregated_vintage_method,
            :limit_decommission_invested_units_aggregated_vintage_method,
        )
    )

    TulipaEnergyModel.add_limit_decommission_aggregated_method_constraints!(
        connection,
        model,
        variables,
        constraints,
    )

    var_inv = variables[:assets_investment].container
    var_dec = variables[:assets_decommission].container

    expected_cons = [
        JuMP.@build_constraint(1.09 - var_dec[1] ≥ 0),
        JuMP.@build_constraint(2.02 - var_dec[1] - var_dec[3] ≥ 0),
    ]
    observed_cons =
        _get_cons_object(model, :limit_decommission_initial_units_aggregated_vintage_method)
    @test _is_constraint_equal(expected_cons, observed_cons)

    expected_cons = [JuMP.@build_constraint(var_inv[1] - var_dec[2] ≥ 0)]
    observed_cons =
        _get_cons_object(model, :limit_decommission_invested_units_aggregated_vintage_method)
    @test _is_constraint_equal(expected_cons, observed_cons)
end

@testsnippet DecommissionAggregatedSetup begin
    # Build the full model for the multi-year fixture, optionally overriding the technical lifetime
    # of the battery (aggregated vintage method, investable and decommissionable in 2030 and 2050)
    function _create_multi_year_problem(; battery_technical_lifetime = nothing)
        connection = _multi_year_fixture()
        if battery_technical_lifetime !== nothing
            DuckDB.query(
                connection,
                "UPDATE asset SET technical_lifetime = $battery_technical_lifetime WHERE asset = 'battery'",
            )
        end
        TulipaEnergyModel.populate_with_defaults!(connection)
        energy_problem = TulipaEnergyModel.EnergyProblem(connection)
        TulipaEnergyModel.create_model!(energy_problem)
        return energy_problem
    end

    function _decommission_rows(connection, asset)
        return [
            (row.milestone_year, row.commission_year) for row in DuckDB.query(
                connection,
                "SELECT milestone_year, commission_year
                FROM var_assets_decommission
                WHERE asset = '$asset'
                ORDER BY milestone_year, commission_year",
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

    function _available_units_aggregated(energy_problem, asset, milestone_year)
        expr = energy_problem.expressions[:available_asset_units_aggregated_vintage_method]
        id = only([
            row.id for row in DuckDB.query(
                energy_problem.db_connection,
                "FROM expr_available_asset_units_aggregated_vintage_method
                WHERE asset = '$asset' AND milestone_year = $milestone_year",
            )
        ])
        return expr.expressions[:assets][id]
    end
end

@testitem "Aggregated decommission variables track the vintage of the decommissioned units" setup =
    [CommonSetup, DecommissionAggregatedSetup] tags = [:integration, :variable, :fast] begin
    # Battery: technical lifetime 30 years, so the 2030 investment is alive in 2050 and can be
    # decommissioned in 2050 through its own row; existing units get one row per milestone year
    energy_problem = _create_multi_year_problem()
    connection = energy_problem.db_connection
    @test _decommission_rows(connection, "battery") == [(2030, 2030), (2050, 2030), (2050, 2050)]
    # Compact assets keep the rows given in asset_both
    @test _decommission_rows(connection, "wind") == [(2030, 2020), (2050, 2030)]
    # Non-decommissionable assets have no rows
    @test isempty(_decommission_rows(connection, "ocgt"))

    # With a technical lifetime shorter than the gap between milestone years, the 2030 investment
    # is not alive in 2050, so there is no row to decommission it
    energy_problem = _create_multi_year_problem(; battery_technical_lifetime = 15)
    connection = energy_problem.db_connection
    @test _decommission_rows(connection, "battery") == [(2030, 2030), (2050, 2050)]
end

@testitem "Aggregated available units stop subtracting decommissions after the technical lifetime" setup =
    [CommonSetup, DecommissionAggregatedSetup] tags = [:integration, :constraint, :fast] begin
    # Technical lifetime of 30 years: every investment and decommission of 2030 is still alive in 2050
    energy_problem = _create_multi_year_problem()
    inv = (
        year -> _variable(
            energy_problem,
            "var_assets_investment",
            :assets_investment;
            asset = "battery",
            milestone_year = year,
        )
    )
    dec = (
        (year, vintage) -> _variable(
            energy_problem,
            "var_assets_decommission",
            :assets_decommission;
            asset = "battery",
            milestone_year = year,
            commission_year = vintage,
        )
    )

    expected_2030 = JuMP.@expression(energy_problem.model, 1.09 + inv(2030) - dec(2030, 2030))
    expected_2050 = JuMP.@expression(
        energy_problem.model,
        2.02 + inv(2030) + inv(2050) - dec(2030, 2030) - dec(2050, 2030) - dec(2050, 2050)
    )
    @test JuMP.isequal_canonical(
        _available_units_aggregated(energy_problem, "battery", 2030),
        expected_2030,
    )
    @test JuMP.isequal_canonical(
        _available_units_aggregated(energy_problem, "battery", 2050),
        expected_2050,
    )

    # Technical lifetime of 15 years: the 2030 investment and the 2030 decommission of existing
    # units are gone by 2050, so neither of them appears in the 2050 expression
    energy_problem = _create_multi_year_problem(; battery_technical_lifetime = 15)
    inv = (
        year -> _variable(
            energy_problem,
            "var_assets_investment",
            :assets_investment;
            asset = "battery",
            milestone_year = year,
        )
    )
    dec = (
        (year, vintage) -> _variable(
            energy_problem,
            "var_assets_decommission",
            :assets_decommission;
            asset = "battery",
            milestone_year = year,
            commission_year = vintage,
        )
    )
    expected_2030 = JuMP.@expression(energy_problem.model, 1.09 + inv(2030) - dec(2030, 2030))
    expected_2050 = JuMP.@expression(energy_problem.model, 2.02 + inv(2050) - dec(2050, 2050))
    @test JuMP.isequal_canonical(
        _available_units_aggregated(energy_problem, "battery", 2030),
        expected_2030,
    )
    @test JuMP.isequal_canonical(
        _available_units_aggregated(energy_problem, "battery", 2050),
        expected_2050,
    )
end

@testitem "Aggregated decommission limits exist only where there is something to decommission" setup =
    [CommonSetup, DecommissionAggregatedSetup] tags = [:integration, :constraint, :fast] begin
    energy_problem = _create_multi_year_problem()
    model = energy_problem.model

    # Existing units: one constraint per decommissionable aggregated asset and milestone year
    cons_initial =
        _get_cons_object(model, :limit_decommission_initial_units_aggregated_vintage_method)
    @test length(cons_initial) == 2

    # Invested units: one constraint for the 2030 vintage of the battery
    cons_invested =
        _get_cons_object(model, :limit_decommission_invested_units_aggregated_vintage_method)
    @test length(cons_invested) == 1
    inv_2030 = _variable(
        energy_problem,
        "var_assets_investment",
        :assets_investment;
        asset = "battery",
        milestone_year = 2030,
    )
    dec_2050_2030 = _variable(
        energy_problem,
        "var_assets_decommission",
        :assets_decommission;
        asset = "battery",
        milestone_year = 2050,
        commission_year = 2030,
    )
    @test _is_constraint_equal(
        JuMP.@build_constraint(inv_2030 - dec_2050_2030 ≥ 0),
        only(cons_invested),
    )
end
