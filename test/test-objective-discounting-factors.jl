@testsnippet InvestmentDiscountingSetup begin
    function annualized_investment_cost(
        investment_cost,
        technology_discount_rate,
        economic_lifetime,
    )
        technology_discount_rate == 0 && return investment_cost / economic_lifetime
        return technology_discount_rate /
               (1 - 1 / (1 + technology_discount_rate)^economic_lifetime) * investment_cost
    end

    function salvage_value(
        investment_cost,
        technology_discount_rate,
        economic_lifetime,
        milestone_year,
        last_year,
    )
        milestone_year + economic_lifetime <= last_year + 1 && return 0.0
        return annualized_investment_cost(
            investment_cost,
            technology_discount_rate,
            economic_lifetime,
        ) * sum(
            1 / (1 + technology_discount_rate)^(year - milestone_year) for
            year in (last_year+1):(milestone_year+economic_lifetime-1)
        )
    end

    function investment_discounting_factor(
        investment_cost,
        technology_discount_rate,
        economic_lifetime,
        milestone_year,
        last_year,
        social_discount_rate,
        discount_year,
    )
        investment_cost == 0 && return 0.0
        salvage = salvage_value(
            investment_cost,
            technology_discount_rate,
            economic_lifetime,
            milestone_year,
            last_year,
        )
        return 1 / (1 + social_discount_rate)^(milestone_year - discount_year) *
               (1 + technology_discount_rate - salvage / investment_cost)
    end
end

@testitem "Test investment discounting" setup = [CommonSetup, InvestmentDiscountingSetup] tags =
    [:integration, :validation, :fast] begin
    function _investment_factors(case)
        connection = DBInterface.connect(DuckDB.DB)
        _read_csv_folder(connection, joinpath(INPUT_FOLDER, case))
        energy_problem = TulipaEnergyModel.EnergyProblem(connection)
        TulipaEnergyModel.create_model!(energy_problem)
        parameters = only(
            DuckDB.query(
                connection,
                "SELECT discount_rate AS social_discount_rate, discount_year FROM model_parameters",
            ),
        )
        last_year =
            only(
                DuckDB.query(
                    connection,
                    "SELECT MAX(milestone_year) AS last_year FROM rep_periods_data",
                ),
            ).last_year
        rows = collect(
            DuckDB.query(
                connection,
                "SELECT
                    o.milestone_year,
                    o.investment_cost,
                    o.annualized_cost,
                    o.salvage_value,
                    o.weight_for_asset_investment_discount AS discounting_factor,
                    a.discount_rate AS technology_discount_rate,
                    a.economic_lifetime
                FROM t_objective_assets AS o
                JOIN asset AS a ON a.asset = o.asset
                WHERE o.investment_cost > 0",
            ),
        )
        return (;
            social_discount_rate = parameters.social_discount_rate,
            discount_year = parameters.discount_year,
            last_year,
            rows,
        )
    end

    single = _investment_factors("Tiny")
    @test !isempty(single.rows)
    for row in single.rows
        @test row.annualized_cost ≈ annualized_investment_cost(
            row.investment_cost,
            row.technology_discount_rate,
            row.economic_lifetime,
        )
        @test row.salvage_value == 0.0
        @test row.discounting_factor ≈ investment_discounting_factor(
            row.investment_cost,
            row.technology_discount_rate,
            row.economic_lifetime,
            row.milestone_year,
            single.last_year,
            single.social_discount_rate,
            single.discount_year,
        )
        @test row.discounting_factor ≈
              1 / (1 + single.social_discount_rate)^(row.milestone_year - single.discount_year) *
              (1 + row.technology_discount_rate)
    end

    multi = _investment_factors("Multi-year Investments")
    @test !isempty(multi.rows)
    for row in multi.rows
        @test row.annualized_cost ≈ annualized_investment_cost(
            row.investment_cost,
            row.technology_discount_rate,
            row.economic_lifetime,
        )
        @test row.salvage_value ≈ salvage_value(
            row.investment_cost,
            row.technology_discount_rate,
            row.economic_lifetime,
            row.milestone_year,
            multi.last_year,
        )
        @test row.discounting_factor ≈ investment_discounting_factor(
            row.investment_cost,
            row.technology_discount_rate,
            row.economic_lifetime,
            row.milestone_year,
            multi.last_year,
            multi.social_discount_rate,
            multi.discount_year,
        )
    end
end

@testitem "Zero-discount annualized cost is investment cost over lifetime" setup = [CommonSetup] tags =
    [:integration, :validation, :fast] begin
    connection = DBInterface.connect(DuckDB.DB)
    _read_csv_folder(connection, joinpath(INPUT_FOLDER, "Tiny"))
    energy_problem = TulipaEnergyModel.EnergyProblem(connection)

    # With a zero technology-specific discount rate, the CRF annualized cost reduces
    # to a straight-line split of the investment cost over the economic lifetime.
    DuckDB.query(connection, "UPDATE asset SET discount_rate = 0, economic_lifetime = 5")
    TulipaEnergyModel.create_model!(energy_problem)

    rows = collect(
        DuckDB.query(
            connection,
            "SELECT o.annualized_cost, o.investment_cost, a.economic_lifetime
            FROM t_objective_assets AS o
            JOIN asset AS a ON a.asset = o.asset
            WHERE o.investment_cost > 0",
        ),
    )
    @test !isempty(rows)
    for row in rows
        @test row.annualized_cost == row.investment_cost / row.economic_lifetime
    end
end

@testitem "Single-year investment uses the same formula as multi-year" setup =
    [CommonSetup, InvestmentDiscountingSetup] tags = [:integration, :validation, :fast] begin
    connection = DBInterface.connect(DuckDB.DB)
    _read_csv_folder(connection, joinpath(INPUT_FOLDER, "Tiny"))
    energy_problem = TulipaEnergyModel.EnergyProblem(connection)

    # Tiny is a single-year horizon
    DuckDB.query(connection, "UPDATE asset SET economic_lifetime = 10")
    TulipaEnergyModel.create_model!(energy_problem)

    last_year =
        only(
            DuckDB.query(
                connection,
                "SELECT MAX(milestone_year) AS last_year FROM rep_periods_data",
            ),
        ).last_year
    rows = collect(
        DuckDB.query(
            connection,
            "SELECT
                o.milestone_year,
                o.investment_cost,
                o.annualized_cost,
                o.salvage_value,
                o.investment_year_discount,
                o.weight_for_asset_investment_discount AS discounting_factor,
                a.discount_rate AS technology_discount_rate,
                a.economic_lifetime
            FROM t_objective_assets AS o
            JOIN asset AS a ON a.asset = o.asset
            WHERE o.investment_cost > 0",
        ),
    )
    @test !isempty(rows)
    for row in rows
        # The lifetime extends beyond the single-year horizon, so salvage is active,
        # yet the discounting factor still reduces to a single annualized payment
        @test row.salvage_value ≈ salvage_value(
            row.investment_cost,
            row.technology_discount_rate,
            row.economic_lifetime,
            row.milestone_year,
            last_year,
        )
        @test row.discounting_factor ≈
              row.investment_year_discount * row.annualized_cost / row.investment_cost
    end
end
