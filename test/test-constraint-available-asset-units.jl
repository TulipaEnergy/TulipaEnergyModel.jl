@testsnippet ConsAvailableAssetUnitsSetup begin
    using DuckDB: DuckDB
    using TulipaBuilder: TulipaBuilder as TB
    using TulipaClustering: TulipaClustering as TC

    function create_available_asset_units_problem(; assets = Tuple[])
        tulipa = TB.TulipaData()
        for asset in assets
            TB.add_asset!(
                tulipa,
                asset.name,
                asset.type;
                investable = asset.investable,
                vintage_method = asset.vintage_method,
                max_available_units = asset.max_available_units,
                min_available_units = asset.min_available_units,
            )
            for (milestone_year, profile) in asset.profiles
                TB.attach_profile!(tulipa, asset.name, :availability, milestone_year, profile)
            end
        end

        connection = TB.create_connection(tulipa, TEM.schema)
        layout = TC.ProfilesTableLayout(; year = :milestone_year)
        TC.dummy_cluster!(connection; layout)

        TEM.populate_with_defaults!(connection)
        energy_problem = TEM.EnergyProblem(connection)
        TEM.create_model!(energy_problem)

        return energy_problem
    end
end

@testitem "Available asset units constraints use aggregated expressions" setup =
    [CommonSetup, ConsAvailableAssetUnitsSetup] tags = [:unit, :constraint, :fast] begin
    energy_problem = create_available_asset_units_problem(;
        assets = [
            (;
                name = "aggregated_asset",
                type = :producer,
                investable = true,
                vintage_method = "aggregated",
                profiles = [(2050, ones(6))],
                max_available_units = 5.0,
                min_available_units = 2.0,
            ),
        ],
    )

    expr_aggregated = energy_problem.expressions[:available_asset_units_aggregated_vintage_method]
    expected_min_cons =
        [JuMP.@build_constraint(expr >= 2) for expr in expr_aggregated.expressions[:assets]]
    expected_max_cons =
        [JuMP.@build_constraint(expr <= 5) for expr in expr_aggregated.expressions[:assets]]

    @test _is_constraint_equal(
        expected_min_cons,
        _get_cons_object(energy_problem.model, :min_available_asset_units),
    )
    @test _is_constraint_equal(
        expected_max_cons,
        _get_cons_object(energy_problem.model, :max_available_asset_units),
    )
end

@testitem "Available asset units constraints use compact expressions" setup =
    [CommonSetup, ConsAvailableAssetUnitsSetup] tags = [:unit, :constraint, :fast] begin
    energy_problem = create_available_asset_units_problem(;
        assets = [
            (;
                name = "compact_asset",
                type = :producer,
                investable = true,
                vintage_method = "compact_profiles",
                profiles = [(2030, ones(6)), (2050, ones(6))],
                max_available_units = 7.0,
                min_available_units = 3.0,
            ),
        ],
    )

    expr_compact = energy_problem.expressions[:available_asset_units_compact_vintage_method]
    expected_min_cons =
        [JuMP.@build_constraint(expr >= 3) for expr in expr_compact.expressions[:assets]]
    expected_max_cons =
        [JuMP.@build_constraint(expr <= 7) for expr in expr_compact.expressions[:assets]]

    @test _is_constraint_equal(
        expected_min_cons,
        _get_cons_object(energy_problem.model, :min_available_asset_units),
    )
    @test _is_constraint_equal(
        expected_max_cons,
        _get_cons_object(energy_problem.model, :max_available_asset_units),
    )
end

@testitem "Available asset units constraints are optional when there are no limits" setup =
    [CommonSetup, ConsAvailableAssetUnitsSetup] tags = [:unit, :constraint, :fast] begin
    energy_problem = create_available_asset_units_problem(;
        assets = [
            (;
                name = "aggregated_asset",
                type = :producer,
                investable = true,
                vintage_method = "aggregated",
                profiles = [(2050, ones(6))],
                max_available_units = nothing,
                min_available_units = nothing,
            ),
            (;
                name = "compact_asset",
                type = :producer,
                investable = true,
                vintage_method = "compact_profiles",
                profiles = [(2050, ones(6))],
                max_available_units = nothing,
                min_available_units = nothing,
            ),
        ],
    )

    @test isempty(energy_problem.model[:min_available_asset_units])
    @test isempty(energy_problem.model[:max_available_asset_units])
end
