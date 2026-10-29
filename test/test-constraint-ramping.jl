@testsnippet ConsRampingSetup begin
    using TulipaBuilder: TulipaBuilder as TB
    using TulipaClustering: TulipaClustering as TC

    function create_ramping_problem(; unit_commitment = "none", initial_units = 10.0)
        tulipa = TB.TulipaData()
        TB.add_asset!(tulipa, "demand", :consumer; peak_demand = 1000.0)
        TB.add_asset!(
            tulipa,
            "plant",
            :producer;
            capacity = 100.0,
            initial_units,
            ramping = true,
            max_ramp_up = 0.5,
            max_ramp_down = 0.5,
            unit_commitment,
            unit_commitment_integer = true,
        )
        TB.add_flow!(tulipa, "plant", "demand")
        TB.attach_profile!(tulipa, "plant", :availability, 2030, ones(3); scenario = 1)

        connection = TB.create_connection(tulipa, TEM.schema)
        layout = TC.ProfilesTableLayout(; year = :milestone_year, cols_to_crossby = [:scenario])
        TC.cluster!(connection, 3, 1; layout)
        TEM.populate_with_defaults!(connection)
        energy_problem = TEM.EnergyProblem(connection)
        TEM.create_model!(energy_problem)
        return connection, energy_problem
    end
end

@testitem "Non-UC ramping scales with available units" setup = [CommonSetup, ConsRampingSetup] tags =
    [:unit, :constraint, :fast] begin
    connection, energy_problem = create_ramping_problem()
    model = energy_problem.model

    rows =
        energy_problem.constraints[:max_ramp_without_unit_commitment_aggregated_vintage_method].indices
    @test length(collect(rows)) == 3
    @test isempty(
        collect(
            DuckDB.query(
                connection,
                """SELECT id FROM cons_max_ramp_without_unit_commitment_compact_vintage_method""",
            ),
        ),
    )

    up_constraints = model[:max_ramp_up_without_unit_commitment_aggregated_vintage_method]
    down_constraints = model[:max_ramp_down_without_unit_commitment_aggregated_vintage_method]
    @test JuMP.constraint_object(up_constraints[2]).set.upper ≈ 500.0
    @test JuMP.constraint_object(down_constraints[2]).set.lower ≈ -500.0
end

@testitem "UC assets are excluded from non-UC ramping" setup = [CommonSetup, ConsRampingSetup] tags =
    [:unit, :constraint, :fast] begin
    connection, energy_problem =
        create_ramping_problem(; unit_commitment = "basic", initial_units = 1.0)
    @test isempty(
        collect(
            DuckDB.query(
                connection,
                """SELECT id FROM cons_max_ramp_without_unit_commitment_aggregated_vintage_method""",
            ),
        ),
    )
    @test length(collect(energy_problem.constraints[:max_ramp_with_unit_commitment].indices)) == 3
end

@testitem "Compact-vintage ramping uses available vintages" setup = [CommonSetup] tags =
    [:unit, :constraint, :fast] begin
    connection = _multi_year_fixture()
    DuckDB.query(
        connection,
        """UPDATE asset
           SET ramping = true, max_ramp_up = 0.5, max_ramp_down = 0.5
           WHERE asset IN ('wind', 'ccgt')""",
    )
    TEM.populate_with_defaults!(connection)
    energy_problem = TEM.EnergyProblem(connection)
    TEM.create_model!(energy_problem)

    compact_rows = collect(
        DuckDB.query(
            connection,
            """SELECT asset FROM cons_max_ramp_without_unit_commitment_compact_vintage_method
               ORDER BY asset""",
        ),
    )
    @test !isempty(compact_rows)
    @test haskey(energy_problem.model, :max_ramp_up_without_unit_commitment_compact_vintage_method)
    @test haskey(
        energy_problem.model,
        :max_ramp_down_without_unit_commitment_compact_vintage_method,
    )
end
