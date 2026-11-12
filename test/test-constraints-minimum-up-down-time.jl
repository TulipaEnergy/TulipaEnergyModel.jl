@testsnippet ConsMinUpDownTimeSetup begin
    using DuckDB: DBInterface
    using TulipaBuilder: TulipaBuilder as TB
    using TulipaClustering: TulipaClustering as TC

    function create_minimum_up_down_time_problem(
        resolution;
        partitioned = false,
        minimum_up_time = 4,
        minimum_down_time = 4,
        maximum_up_time = nothing,
    )
        # The maximum up time is optional, so it is only added when it is given.
        optional_asset_data = isnothing(maximum_up_time) ? (;) : (; maximum_up_time)
        tulipa = TB.TulipaData()
        if partitioned
            TB.add_asset!(tulipa, "sink", :consumer)
        end

        for (name, vintage_method) in
            (("input_1", "aggregated"), ("input_2", "compact_profiles"), ("input_3", "aggregated"))
            TB.add_asset!(
                tulipa,
                name,
                :conversion;
                vintage_method = vintage_method,
                unit_commitment = "3var",
                unit_commitment_integer = true,
                minimum_up_time,
                minimum_down_time,
                initial_units = 1.0,
                optional_asset_data...,
            )
            TB.attach_profile!(tulipa, name, :availability, 2050, ones(partitioned ? 7 : 9))

            if partitioned
                TB.add_flow!(tulipa, name, "sink")
                TB.set_partition!(tulipa, name, 2050, 1, "explicit", "3;4")
                TB.set_partition!(tulipa, name, "sink", 2050, 1, "explicit", "2;1;1;3")
            end
        end

        connection = TB.create_connection(tulipa, TEM.schema)
        layout = TC.ProfilesTableLayout(; year = :milestone_year)
        TC.dummy_cluster!(connection; layout)
        DBInterface.execute(connection, "UPDATE rep_periods_data SET resolution = ?", [resolution])

        TEM.populate_with_defaults!(connection)
        energy_problem = TEM.EnergyProblem(connection)
        TEM.create_model!(energy_problem)

        return energy_problem
    end
end

@testitem "Test 3var constraints with flexible resolutions" setup = [CommonSetup] tags =
    [:unit, :validation, :fast] begin
    connection = DBInterface.connect(DuckDB.DB)
    _read_csv_folder(connection, joinpath(INPUT_FOLDER, "UC-ramping"))
    DuckDB.query(
        connection,
        """
        UPDATE asset
        SET unit_commitment = '3var',
            minimum_up_time = CASE asset
                WHEN 'ccgt' THEN 5
                WHEN 'smr' THEN 12
                WHEN 'ocgt' THEN 3
                ELSE minimum_up_time
            END,
            minimum_down_time = CASE asset
                WHEN 'ccgt' THEN 1
                WHEN 'smr' THEN 6
                WHEN 'ocgt' THEN 2
                ELSE minimum_down_time
            END,
            maximum_up_time = CASE asset
                WHEN 'ccgt' THEN 6
                WHEN 'smr' THEN 12
                ELSE maximum_up_time
            END
        WHERE asset IN ('ccgt', 'smr', 'ocgt')
        """,
    )
    TEM.populate_with_defaults!(connection)
    energy_problem = TEM.EnergyProblem(connection)
    TEM.create_model!(energy_problem)

    function ids(table_name, asset)
        return [
            row.time_block_start for row in DuckDB.query(
                connection,
                "SELECT time_block_start FROM $table_name WHERE asset = '$asset' ORDER BY id",
            )
        ]
    end

    @test ids("var_units_on", "ocgt") == collect(1:24)
    @test ids("var_units_on", "smr") == [1, 7, 13, 19]
    @test ids("var_units_on", "ccgt") == [1, 4, 7, 10, 13, 16, 19, 22]
    @test [
        row.time_block_end for row in DuckDB.query(
            connection,
            "SELECT time_block_end FROM var_start_up WHERE asset = 'ccgt' ORDER BY id",
        )
    ] == [2, 4, 8, 10, 14, 16, 20, 22]

    function variable(table_name, asset, time_block_start)
        row = first(
            DuckDB.query(
                connection,
                "SELECT id FROM $table_name WHERE asset = '$asset' AND time_block_start = $time_block_start",
            ),
        )
        return energy_problem.variables[Symbol(replace(table_name, "var_"=>""))].container[row.id]
    end

    function constraint_id(table_name, asset, time_block_start)
        row = first(
            DuckDB.query(
                connection,
                "SELECT id FROM $table_name WHERE asset = '$asset' AND time_block_start = $time_block_start",
            ),
        )
        return row.id
    end

    logic_id = constraint_id("cons_unit_commitment_logic", "ccgt", 4)
    @test _is_constraint_equal(
        JuMP.@build_constraint(
            variable("var_units_on", "ccgt", 4) - variable("var_units_on", "ccgt", 1) ==
            variable("var_start_up", "ccgt", 4) - variable("var_shut_down", "ccgt", 4)
        ),
        JuMP.constraint_object(energy_problem.model[:unit_commitment_logic][logic_id]),
    )

    up_id = constraint_id("cons_minimum_up_time", "smr", 7)
    @test _is_constraint_equal(
        JuMP.@build_constraint(
            variable("var_start_up", "smr", 1) + variable("var_start_up", "smr", 7) <=
            variable("var_units_on", "smr", 7)
        ),
        JuMP.constraint_object(energy_problem.model[:minimum_up_time][up_id]),
    )

    ccgt_up_id = constraint_id("cons_minimum_up_time", "ccgt", 7)
    @test _is_constraint_equal(
        JuMP.@build_constraint(
            variable("var_start_up", "ccgt", 4) + variable("var_start_up", "ccgt", 7) <=
            variable("var_units_on", "ccgt", 7)
        ),
        JuMP.constraint_object(energy_problem.model[:minimum_up_time][ccgt_up_id]),
    )

    # Only the assets with a maximum up time get the constraint.
    @test isempty(ids("cons_maximum_up_time", "ocgt"))
    @test ids("cons_maximum_up_time", "smr") == [1, 7, 13, 19]
    @test ids("cons_maximum_up_time", "ccgt") == [1, 4, 7, 10, 13, 16, 19, 22]

    # The 6 h window of the ccgt block 7:9 starts at time step 2, so it covers the blocks 4:6 and 7:9.
    ccgt_max_up_id = constraint_id("cons_maximum_up_time", "ccgt", 7)
    @test _is_constraint_equal(
        JuMP.@build_constraint(
            variable("var_units_on", "ccgt", 7) <=
            variable("var_start_up", "ccgt", 4) + variable("var_start_up", "ccgt", 7)
        ),
        JuMP.constraint_object(energy_problem.model[:maximum_up_time][ccgt_max_up_id]),
    )

    smr_max_up_id = constraint_id("cons_maximum_up_time", "smr", 13)
    @test _is_constraint_equal(
        JuMP.@build_constraint(
            variable("var_units_on", "smr", 13) <=
            variable("var_start_up", "smr", 7) + variable("var_start_up", "smr", 13)
        ),
        JuMP.constraint_object(energy_problem.model[:maximum_up_time][smr_max_up_id]),
    )

    ocgt_down_id = constraint_id("cons_minimum_down_time_aggregated_vintage_method", "ocgt", 5)
    available_units_id = first(
        DuckDB.query(
            connection,
            "SELECT id FROM expr_available_asset_units_aggregated_vintage_method WHERE asset = 'ocgt' AND milestone_year = 2030",
        ),
    ).id
    available_units =
        energy_problem.expressions[:available_asset_units_aggregated_vintage_method].expressions[:assets][available_units_id]
    @test _is_constraint_equal(
        JuMP.@build_constraint(
            variable("var_shut_down", "ocgt", 4) + variable("var_shut_down", "ocgt", 5) <=
            available_units - variable("var_units_on", "ocgt", 5)
        ),
        JuMP.constraint_object(
            energy_problem.model[:minimum_down_time_aggregated_vintage_method][ocgt_down_id],
        ),
    )
end

@testitem "Test minimum up/down time constraints with different durations" setup =
    [CommonSetup, ConsMinUpDownTimeSetup] tags = [:unit, :validation, :fast] begin
    minimum_up_time = 2
    minimum_down_time = 4
    energy_problem = create_minimum_up_down_time_problem(1.0; minimum_up_time, minimum_down_time)
    model = energy_problem.model
    variables = energy_problem.variables

    var_units_on = variables[:units_on].container
    var_start_up = variables[:start_up].container
    var_shut_down = variables[:shut_down].container

    function window_constraints(variable, units, blocks, duration)
        return vcat(
            [
                [
                    JuMP.@build_constraint(
                        sum(variable[j] for j in max(first(block), i-duration+1):i) <= units[i]
                    ) for i in block
                ] for block in blocks
            ]...,
        )
    end

    expected_up_time =
        [window_constraints(var_start_up, var_units_on, [1:9, 10:18, 19:27], minimum_up_time)...]
    @test _is_constraint_equal(expected_up_time, _get_cons_object(model, :minimum_up_time))

    function down_time_constraints(blocks)
        return vcat(
            [
                [
                    JuMP.@build_constraint(
                        sum(var_shut_down[j] for j in max(first(block), i-minimum_down_time+1):i) <=
                        1 - var_units_on[i]
                    ) for i in block
                ] for block in blocks
            ]...,
        )
    end

    expected_aggregated_down_time = [down_time_constraints([1:9, 19:27])...]
    @test _is_constraint_equal(
        expected_aggregated_down_time,
        _get_cons_object(model, :minimum_down_time_aggregated_vintage_method),
    )

    expected_compact_down_time = [down_time_constraints([10:18])...]
    @test _is_constraint_equal(
        expected_compact_down_time,
        _get_cons_object(model, :minimum_down_time_compact_vintage_method),
    )
end

@testitem "Test minimum up/down time constraints" setup = [CommonSetup, ConsMinUpDownTimeSetup] tags =
    [:unit, :validation, :fast] begin
    energy_problem = create_minimum_up_down_time_problem(1.0; partitioned = true)
    model = energy_problem.model
    variables = energy_problem.variables

    # Test the constraints
    var_units_on = variables[:units_on].container
    var_start_up = variables[:start_up].container
    var_shut_down = variables[:shut_down].container

    expected_cons = [
        JuMP.@build_constraint(var_start_up[1] <= var_units_on[1]),
        JuMP.@build_constraint(var_start_up[1] + var_start_up[2] <= var_units_on[2]),
        JuMP.@build_constraint(var_start_up[3] <= var_units_on[3]),
        JuMP.@build_constraint(var_start_up[3] + var_start_up[4] <= var_units_on[4]),
        JuMP.@build_constraint(var_start_up[5] <= var_units_on[5]),
        JuMP.@build_constraint(var_start_up[5] + var_start_up[6] <= var_units_on[6]),
    ]
    observed_cons = _get_cons_object(model, :minimum_up_time)

    @test _is_constraint_equal(expected_cons, observed_cons)

    expected_cons = [
        JuMP.@build_constraint(var_shut_down[1] <= 1 - var_units_on[1]),
        JuMP.@build_constraint(var_shut_down[1] + var_shut_down[2] <= 1 - var_units_on[2]),
        JuMP.@build_constraint(var_shut_down[5] <= 1 - var_units_on[5]),
        JuMP.@build_constraint(var_shut_down[5] + var_shut_down[6] <= 1 - var_units_on[6]),
    ]
    observed_cons = _get_cons_object(model, :minimum_down_time_aggregated_vintage_method)
    @test _is_constraint_equal(expected_cons, observed_cons)

    expected_cons = [
        JuMP.@build_constraint(var_shut_down[3] <= 1 - var_units_on[3]),
        JuMP.@build_constraint(var_shut_down[3] + var_shut_down[4] <= 1 - var_units_on[4]),
    ]
    observed_cons = _get_cons_object(model, :minimum_down_time_compact_vintage_method)
    @test _is_constraint_equal(expected_cons, observed_cons)
end

@testitem "Test minimum up/down time constraints with resolution 2.0" setup =
    [CommonSetup, ConsMinUpDownTimeSetup] tags = [:unit, :validation, :fast] begin
    energy_problem = create_minimum_up_down_time_problem(2.0)
    model = energy_problem.model
    variables = energy_problem.variables

    var_units_on = variables[:units_on].container
    var_start_up = variables[:start_up].container
    var_shut_down = variables[:shut_down].container

    expected_cons = [
        JuMP.@build_constraint(var_start_up[1] <= var_units_on[1]),
        JuMP.@build_constraint(var_start_up[1] + var_start_up[2] <= var_units_on[2]),
        JuMP.@build_constraint(var_start_up[2] + var_start_up[3] <= var_units_on[3]),
        JuMP.@build_constraint(var_start_up[3] + var_start_up[4] <= var_units_on[4]),
        JuMP.@build_constraint(var_start_up[4] + var_start_up[5] <= var_units_on[5]),
        JuMP.@build_constraint(var_start_up[5] + var_start_up[6] <= var_units_on[6]),
        JuMP.@build_constraint(var_start_up[6] + var_start_up[7] <= var_units_on[7]),
        JuMP.@build_constraint(var_start_up[7] + var_start_up[8] <= var_units_on[8]),
        JuMP.@build_constraint(var_start_up[8] + var_start_up[9] <= var_units_on[9]),
        JuMP.@build_constraint(var_start_up[10] <= var_units_on[10]),
        JuMP.@build_constraint(var_start_up[10] + var_start_up[11] <= var_units_on[11]),
        JuMP.@build_constraint(var_start_up[11] + var_start_up[12] <= var_units_on[12]),
        JuMP.@build_constraint(var_start_up[12] + var_start_up[13] <= var_units_on[13]),
        JuMP.@build_constraint(var_start_up[13] + var_start_up[14] <= var_units_on[14]),
        JuMP.@build_constraint(var_start_up[14] + var_start_up[15] <= var_units_on[15]),
        JuMP.@build_constraint(var_start_up[15] + var_start_up[16] <= var_units_on[16]),
        JuMP.@build_constraint(var_start_up[16] + var_start_up[17] <= var_units_on[17]),
        JuMP.@build_constraint(var_start_up[17] + var_start_up[18] <= var_units_on[18]),
        JuMP.@build_constraint(var_start_up[19] <= var_units_on[19]),
        JuMP.@build_constraint(var_start_up[19] + var_start_up[20] <= var_units_on[20]),
        JuMP.@build_constraint(var_start_up[20] + var_start_up[21] <= var_units_on[21]),
        JuMP.@build_constraint(var_start_up[21] + var_start_up[22] <= var_units_on[22]),
        JuMP.@build_constraint(var_start_up[22] + var_start_up[23] <= var_units_on[23]),
        JuMP.@build_constraint(var_start_up[23] + var_start_up[24] <= var_units_on[24]),
        JuMP.@build_constraint(var_start_up[24] + var_start_up[25] <= var_units_on[25]),
        JuMP.@build_constraint(var_start_up[25] + var_start_up[26] <= var_units_on[26]),
        JuMP.@build_constraint(var_start_up[26] + var_start_up[27] <= var_units_on[27]),
    ]
    observed_cons = _get_cons_object(model, :minimum_up_time)

    @test _is_constraint_equal(expected_cons, observed_cons)

    expected_cons = [
        JuMP.@build_constraint(var_shut_down[1] <= 1 - var_units_on[1]),
        JuMP.@build_constraint(var_shut_down[1] + var_shut_down[2] <= 1 - var_units_on[2]),
        JuMP.@build_constraint(var_shut_down[2] + var_shut_down[3] <= 1 - var_units_on[3]),
        JuMP.@build_constraint(var_shut_down[3] + var_shut_down[4] <= 1 - var_units_on[4]),
        JuMP.@build_constraint(var_shut_down[4] + var_shut_down[5] <= 1 - var_units_on[5]),
        JuMP.@build_constraint(var_shut_down[5] + var_shut_down[6] <= 1 - var_units_on[6]),
        JuMP.@build_constraint(var_shut_down[6] + var_shut_down[7] <= 1 - var_units_on[7]),
        JuMP.@build_constraint(var_shut_down[7] + var_shut_down[8] <= 1 - var_units_on[8]),
        JuMP.@build_constraint(var_shut_down[8] + var_shut_down[9] <= 1 - var_units_on[9]),
        JuMP.@build_constraint(var_shut_down[19] <= 1 - var_units_on[19]),
        JuMP.@build_constraint(var_shut_down[19] + var_shut_down[20] <= 1 - var_units_on[20]),
        JuMP.@build_constraint(var_shut_down[20] + var_shut_down[21] <= 1 - var_units_on[21]),
        JuMP.@build_constraint(var_shut_down[21] + var_shut_down[22] <= 1 - var_units_on[22]),
        JuMP.@build_constraint(var_shut_down[22] + var_shut_down[23] <= 1 - var_units_on[23]),
        JuMP.@build_constraint(var_shut_down[23] + var_shut_down[24] <= 1 - var_units_on[24]),
        JuMP.@build_constraint(var_shut_down[24] + var_shut_down[25] <= 1 - var_units_on[25]),
        JuMP.@build_constraint(var_shut_down[25] + var_shut_down[26] <= 1 - var_units_on[26]),
        JuMP.@build_constraint(var_shut_down[26] + var_shut_down[27] <= 1 - var_units_on[27]),
    ]
    observed_cons = _get_cons_object(model, :minimum_down_time_aggregated_vintage_method)

    @test _is_constraint_equal(expected_cons, observed_cons)

    expected_cons = [
        JuMP.@build_constraint(var_shut_down[10] <= 1 - var_units_on[10]),
        JuMP.@build_constraint(var_shut_down[10] + var_shut_down[11] <= 1 - var_units_on[11]),
        JuMP.@build_constraint(var_shut_down[11] + var_shut_down[12] <= 1 - var_units_on[12]),
        JuMP.@build_constraint(var_shut_down[12] + var_shut_down[13] <= 1 - var_units_on[13]),
        JuMP.@build_constraint(var_shut_down[13] + var_shut_down[14] <= 1 - var_units_on[14]),
        JuMP.@build_constraint(var_shut_down[14] + var_shut_down[15] <= 1 - var_units_on[15]),
        JuMP.@build_constraint(var_shut_down[15] + var_shut_down[16] <= 1 - var_units_on[16]),
        JuMP.@build_constraint(var_shut_down[16] + var_shut_down[17] <= 1 - var_units_on[17]),
        JuMP.@build_constraint(var_shut_down[17] + var_shut_down[18] <= 1 - var_units_on[18]),
    ]
    observed_cons = _get_cons_object(model, :minimum_down_time_compact_vintage_method)

    @test _is_constraint_equal(expected_cons, observed_cons)
end

@testitem "Test minimum up/down time constraints with resolution 0.5" setup =
    [CommonSetup, ConsMinUpDownTimeSetup] tags = [:unit, :validation, :fast] begin
    energy_problem = create_minimum_up_down_time_problem(0.5)
    model = energy_problem.model
    variables = energy_problem.variables

    var_units_on = variables[:units_on].container
    var_start_up = variables[:start_up].container
    var_shut_down = variables[:shut_down].container

    expected_cons = [
        JuMP.@build_constraint(var_start_up[1] <= var_units_on[1]),
        JuMP.@build_constraint(var_start_up[1] + var_start_up[2] <= var_units_on[2]),
        JuMP.@build_constraint(
            var_start_up[1] + var_start_up[2] + var_start_up[3] <= var_units_on[3]
        ),
        JuMP.@build_constraint(
            var_start_up[1] + var_start_up[2] + var_start_up[3] + var_start_up[4] <=
            var_units_on[4]
        ),
        JuMP.@build_constraint(
            var_start_up[1] +
            var_start_up[2] +
            var_start_up[3] +
            var_start_up[4] +
            var_start_up[5] <= var_units_on[5]
        ),
        JuMP.@build_constraint(
            var_start_up[1] +
            var_start_up[2] +
            var_start_up[3] +
            var_start_up[4] +
            var_start_up[5] +
            var_start_up[6] <= var_units_on[6]
        ),
        JuMP.@build_constraint(
            var_start_up[1] +
            var_start_up[2] +
            var_start_up[3] +
            var_start_up[4] +
            var_start_up[5] +
            var_start_up[6] +
            var_start_up[7] <= var_units_on[7]
        ),
        JuMP.@build_constraint(
            var_start_up[1] +
            var_start_up[2] +
            var_start_up[3] +
            var_start_up[4] +
            var_start_up[5] +
            var_start_up[6] +
            var_start_up[7] +
            var_start_up[8] <= var_units_on[8]
        ),
        JuMP.@build_constraint(
            var_start_up[2] +
            var_start_up[3] +
            var_start_up[4] +
            var_start_up[5] +
            var_start_up[6] +
            var_start_up[7] +
            var_start_up[8] +
            var_start_up[9] <= var_units_on[9]
        ),
        JuMP.@build_constraint(var_start_up[10] <= var_units_on[10]),
        JuMP.@build_constraint(var_start_up[10] + var_start_up[11] <= var_units_on[11]),
        JuMP.@build_constraint(
            var_start_up[10] + var_start_up[11] + var_start_up[12] <= var_units_on[12]
        ),
        JuMP.@build_constraint(
            var_start_up[10] + var_start_up[11] + var_start_up[12] + var_start_up[13] <=
            var_units_on[13]
        ),
        JuMP.@build_constraint(
            var_start_up[10] +
            var_start_up[11] +
            var_start_up[12] +
            var_start_up[13] +
            var_start_up[14] <= var_units_on[14]
        ),
        JuMP.@build_constraint(
            var_start_up[10] +
            var_start_up[11] +
            var_start_up[12] +
            var_start_up[13] +
            var_start_up[14] +
            var_start_up[15] <= var_units_on[15]
        ),
        JuMP.@build_constraint(
            var_start_up[10] +
            var_start_up[11] +
            var_start_up[12] +
            var_start_up[13] +
            var_start_up[14] +
            var_start_up[15] +
            var_start_up[16] <= var_units_on[16]
        ),
        JuMP.@build_constraint(
            var_start_up[10] +
            var_start_up[11] +
            var_start_up[12] +
            var_start_up[13] +
            var_start_up[14] +
            var_start_up[15] +
            var_start_up[16] +
            var_start_up[17] <= var_units_on[17]
        ),
        JuMP.@build_constraint(
            var_start_up[11] +
            var_start_up[12] +
            var_start_up[13] +
            var_start_up[14] +
            var_start_up[15] +
            var_start_up[16] +
            var_start_up[17] +
            var_start_up[18] <= var_units_on[18]
        ),
        JuMP.@build_constraint(var_start_up[19] <= var_units_on[19]),
        JuMP.@build_constraint(var_start_up[19] + var_start_up[20] <= var_units_on[20]),
        JuMP.@build_constraint(
            var_start_up[19] + var_start_up[20] + var_start_up[21] <= var_units_on[21]
        ),
        JuMP.@build_constraint(
            var_start_up[19] + var_start_up[20] + var_start_up[21] + var_start_up[22] <=
            var_units_on[22]
        ),
        JuMP.@build_constraint(
            var_start_up[19] +
            var_start_up[20] +
            var_start_up[21] +
            var_start_up[22] +
            var_start_up[23] <= var_units_on[23]
        ),
        JuMP.@build_constraint(
            var_start_up[19] +
            var_start_up[20] +
            var_start_up[21] +
            var_start_up[22] +
            var_start_up[23] +
            var_start_up[24] <= var_units_on[24]
        ),
        JuMP.@build_constraint(
            var_start_up[19] +
            var_start_up[20] +
            var_start_up[21] +
            var_start_up[22] +
            var_start_up[23] +
            var_start_up[24] +
            var_start_up[25] <= var_units_on[25]
        ),
        JuMP.@build_constraint(
            var_start_up[19] +
            var_start_up[20] +
            var_start_up[21] +
            var_start_up[22] +
            var_start_up[23] +
            var_start_up[24] +
            var_start_up[25] +
            var_start_up[26] <= var_units_on[26]
        ),
        JuMP.@build_constraint(
            var_start_up[20] +
            var_start_up[21] +
            var_start_up[22] +
            var_start_up[23] +
            var_start_up[24] +
            var_start_up[25] +
            var_start_up[26] +
            var_start_up[27] <= var_units_on[27]
        ),
    ]
    observed_cons = _get_cons_object(model, :minimum_up_time)

    @test _is_constraint_equal(expected_cons, observed_cons)

    expected_cons = [
        JuMP.@build_constraint(var_shut_down[1] <= 1 - var_units_on[1]),
        JuMP.@build_constraint(var_shut_down[1] + var_shut_down[2] <= 1 - var_units_on[2]),
        JuMP.@build_constraint(
            var_shut_down[1] + var_shut_down[2] + var_shut_down[3] <= 1 - var_units_on[3]
        ),
        JuMP.@build_constraint(
            var_shut_down[1] + var_shut_down[2] + var_shut_down[3] + var_shut_down[4] <=
            1 - var_units_on[4]
        ),
        JuMP.@build_constraint(
            var_shut_down[1] +
            var_shut_down[2] +
            var_shut_down[3] +
            var_shut_down[4] +
            var_shut_down[5] <= 1 - var_units_on[5]
        ),
        JuMP.@build_constraint(
            var_shut_down[1] +
            var_shut_down[2] +
            var_shut_down[3] +
            var_shut_down[4] +
            var_shut_down[5] +
            var_shut_down[6] <= 1 - var_units_on[6]
        ),
        JuMP.@build_constraint(
            var_shut_down[1] +
            var_shut_down[2] +
            var_shut_down[3] +
            var_shut_down[4] +
            var_shut_down[5] +
            var_shut_down[6] +
            var_shut_down[7] <= 1 - var_units_on[7]
        ),
        JuMP.@build_constraint(
            var_shut_down[1] +
            var_shut_down[2] +
            var_shut_down[3] +
            var_shut_down[4] +
            var_shut_down[5] +
            var_shut_down[6] +
            var_shut_down[7] +
            var_shut_down[8] <= 1 - var_units_on[8]
        ),
        JuMP.@build_constraint(
            var_shut_down[2] +
            var_shut_down[3] +
            var_shut_down[4] +
            var_shut_down[5] +
            var_shut_down[6] +
            var_shut_down[7] +
            var_shut_down[8] +
            var_shut_down[9] <= 1 - var_units_on[9]
        ),
        JuMP.@build_constraint(var_shut_down[19] <= 1 - var_units_on[19]),
        JuMP.@build_constraint(var_shut_down[19] + var_shut_down[20] <= 1 - var_units_on[20]),
        JuMP.@build_constraint(
            var_shut_down[19] + var_shut_down[20] + var_shut_down[21] <= 1 - var_units_on[21]
        ),
        JuMP.@build_constraint(
            var_shut_down[19] + var_shut_down[20] + var_shut_down[21] + var_shut_down[22] <=
            1 - var_units_on[22]
        ),
        JuMP.@build_constraint(
            var_shut_down[19] +
            var_shut_down[20] +
            var_shut_down[21] +
            var_shut_down[22] +
            var_shut_down[23] <= 1 - var_units_on[23]
        ),
        JuMP.@build_constraint(
            var_shut_down[19] +
            var_shut_down[20] +
            var_shut_down[21] +
            var_shut_down[22] +
            var_shut_down[23] +
            var_shut_down[24] <= 1 - var_units_on[24]
        ),
        JuMP.@build_constraint(
            var_shut_down[19] +
            var_shut_down[20] +
            var_shut_down[21] +
            var_shut_down[22] +
            var_shut_down[23] +
            var_shut_down[24] +
            var_shut_down[25] <= 1 - var_units_on[25]
        ),
        JuMP.@build_constraint(
            var_shut_down[19] +
            var_shut_down[20] +
            var_shut_down[21] +
            var_shut_down[22] +
            var_shut_down[23] +
            var_shut_down[24] +
            var_shut_down[25] +
            var_shut_down[26] <= 1 - var_units_on[26]
        ),
        JuMP.@build_constraint(
            var_shut_down[20] +
            var_shut_down[21] +
            var_shut_down[22] +
            var_shut_down[23] +
            var_shut_down[24] +
            var_shut_down[25] +
            var_shut_down[26] +
            var_shut_down[27] <= 1 - var_units_on[27]
        ),
    ]
    observed_cons = _get_cons_object(model, :minimum_down_time_aggregated_vintage_method)

    @test _is_constraint_equal(expected_cons, observed_cons)

    expected_cons = [
        JuMP.@build_constraint(var_shut_down[10] <= 1 - var_units_on[10]),
        JuMP.@build_constraint(var_shut_down[10] + var_shut_down[11] <= 1 - var_units_on[11]),
        JuMP.@build_constraint(
            var_shut_down[10] + var_shut_down[11] + var_shut_down[12] <= 1 - var_units_on[12]
        ),
        JuMP.@build_constraint(
            var_shut_down[10] + var_shut_down[11] + var_shut_down[12] + var_shut_down[13] <=
            1 - var_units_on[13]
        ),
        JuMP.@build_constraint(
            var_shut_down[10] +
            var_shut_down[11] +
            var_shut_down[12] +
            var_shut_down[13] +
            var_shut_down[14] <= 1 - var_units_on[14]
        ),
        JuMP.@build_constraint(
            var_shut_down[10] +
            var_shut_down[11] +
            var_shut_down[12] +
            var_shut_down[13] +
            var_shut_down[14] +
            var_shut_down[15] <= 1 - var_units_on[15]
        ),
        JuMP.@build_constraint(
            var_shut_down[10] +
            var_shut_down[11] +
            var_shut_down[12] +
            var_shut_down[13] +
            var_shut_down[14] +
            var_shut_down[15] +
            var_shut_down[16] <= 1 - var_units_on[16]
        ),
        JuMP.@build_constraint(
            var_shut_down[10] +
            var_shut_down[11] +
            var_shut_down[12] +
            var_shut_down[13] +
            var_shut_down[14] +
            var_shut_down[15] +
            var_shut_down[16] +
            var_shut_down[17] <= 1 - var_units_on[17]
        ),
        JuMP.@build_constraint(
            var_shut_down[11] +
            var_shut_down[12] +
            var_shut_down[13] +
            var_shut_down[14] +
            var_shut_down[15] +
            var_shut_down[16] +
            var_shut_down[17] +
            var_shut_down[18] <= 1 - var_units_on[18]
        ),
    ]
    observed_cons = _get_cons_object(model, :minimum_down_time_compact_vintage_method)

    @test _is_constraint_equal(expected_cons, observed_cons)
end

@testitem "Test maximum up time constraints are not created without maximum_up_time" setup =
    [CommonSetup, ConsMinUpDownTimeSetup] tags = [:unit, :validation, :fast] begin
    energy_problem = create_minimum_up_down_time_problem(1.0)

    @test energy_problem.constraints[:maximum_up_time].num_rows == 0
    @test isempty(energy_problem.model[:maximum_up_time])

    num_constraints =
        JuMP.num_constraints(energy_problem.model; count_variable_in_set_constraints = false)
    connection = energy_problem.db_connection
    DuckDB.query(connection, "ALTER TABLE asset DROP COLUMN maximum_up_time")
    TEM.populate_with_defaults!(connection)
    energy_problem = TEM.EnergyProblem(connection)
    TEM.create_model!(energy_problem)

    @test energy_problem.constraints[:maximum_up_time].num_rows == 0
    @test isempty(energy_problem.model[:maximum_up_time])
    @test JuMP.num_constraints(energy_problem.model; count_variable_in_set_constraints = false) ==
          num_constraints
end

@testitem "Test maximum up time is ignored without 3var unit commitment" setup = [CommonSetup] tags =
    [:unit, :validation, :fast] begin
    connection = DBInterface.connect(DuckDB.DB)
    _read_csv_folder(connection, joinpath(INPUT_FOLDER, "UC-ramping"))
    DuckDB.query(connection, "UPDATE asset SET maximum_up_time = 4")
    TEM.populate_with_defaults!(connection)
    energy_problem = TEM.EnergyProblem(connection)
    TEM.create_model!(energy_problem)

    @test energy_problem.constraints[:maximum_up_time].num_rows == 0
    @test isempty(energy_problem.model[:maximum_up_time])
end

@testitem "Test maximum up time constraints with different resolutions" setup =
    [CommonSetup, ConsMinUpDownTimeSetup] tags = [:unit, :validation, :fast] begin
    maximum_up_time = 3
    # The window is rounded up to whole blocks: ceil(3 / resolution).
    for (resolution, window_blocks) in ((1.0, 3), (2.0, 2), (0.5, 6))
        energy_problem =
            create_minimum_up_down_time_problem(resolution; minimum_up_time = 2, maximum_up_time)
        var_units_on = energy_problem.variables[:units_on].container
        var_start_up = energy_problem.variables[:start_up].container

        expected_cons = [
            JuMP.@build_constraint(
                var_units_on[i] <=
                sum(var_start_up[j] for j in max(first(block), i-window_blocks+1):i)
            ) for block in (1:9, 10:18, 19:27) for i in block
        ]
        @test _is_constraint_equal(
            expected_cons,
            _get_cons_object(energy_problem.model, :maximum_up_time),
        )
    end
end

@testitem "Test maximum up time constraints with partitioned blocks" setup =
    [CommonSetup, ConsMinUpDownTimeSetup] tags = [:unit, :validation, :fast] begin
    # Each asset has the blocks 1:3 and 4:7, so the window of the second block
    # only reaches the first block when the maximum up time is at least 4.
    energy_problem = create_minimum_up_down_time_problem(
        1.0;
        partitioned = true,
        minimum_up_time = 2,
        maximum_up_time = 3,
    )
    var_units_on = energy_problem.variables[:units_on].container
    var_start_up = energy_problem.variables[:start_up].container

    expected_cons = [JuMP.@build_constraint(var_units_on[i] <= var_start_up[i]) for i in 1:6]
    @test _is_constraint_equal(
        expected_cons,
        _get_cons_object(energy_problem.model, :maximum_up_time),
    )

    energy_problem = create_minimum_up_down_time_problem(
        1.0;
        partitioned = true,
        minimum_up_time = 2,
        maximum_up_time = 4,
    )
    var_units_on = energy_problem.variables[:units_on].container
    var_start_up = energy_problem.variables[:start_up].container

    expected_cons = [
        JuMP.@build_constraint(var_units_on[1] <= var_start_up[1]),
        JuMP.@build_constraint(var_units_on[2] <= var_start_up[1] + var_start_up[2]),
        JuMP.@build_constraint(var_units_on[3] <= var_start_up[3]),
        JuMP.@build_constraint(var_units_on[4] <= var_start_up[3] + var_start_up[4]),
        JuMP.@build_constraint(var_units_on[5] <= var_start_up[5]),
        JuMP.@build_constraint(var_units_on[6] <= var_start_up[5] + var_start_up[6]),
    ]
    @test _is_constraint_equal(
        expected_cons,
        _get_cons_object(energy_problem.model, :maximum_up_time),
    )
end

@testitem "Test maximum up time limits the consecutive on time" setup = [CommonSetup] tags =
    [:integration, :validation, :slow] begin
    function solve_uc_ramping(ocgt_maximum_up_time)
        connection = DBInterface.connect(DuckDB.DB)
        _read_csv_folder(connection, joinpath(INPUT_FOLDER, "UC-ramping"))
        DuckDB.query(
            connection,
            "UPDATE asset SET unit_commitment = '3var' WHERE asset IN ('ccgt', 'smr', 'ocgt')",
        )
        if !isnothing(ocgt_maximum_up_time)
            DBInterface.execute(
                connection,
                "UPDATE asset SET maximum_up_time = ? WHERE asset = 'ocgt'",
                [ocgt_maximum_up_time],
            )
        end
        energy_problem = TEM.run_scenario(
            connection;
            optimizer = HiGHS.Optimizer,
            optimizer_parameters = Dict(
                "output_flag" => false,
                "mip_rel_gap" => 0.0,
                "mip_feasibility_tolerance" => 1e-5,
            ),
            show_log = false,
        )
        JuMP.assert_is_solved_and_feasible(energy_problem.model)
        ocgt_units_on = [
            row.solution for row in DuckDB.query(
                connection,
                "SELECT solution FROM var_units_on WHERE asset = 'ocgt' ORDER BY time_block_start",
            )
        ]
        return energy_problem, ocgt_units_on
    end

    # The ocgt has hourly blocks and at most one unit on, so the longest run of
    # consecutive hours on is bounded by the maximum up time.
    function longest_on_run(units_on)
        longest = 0
        current = 0
        for value in units_on
            current = value > 0.5 ? current + 1 : 0
            longest = max(longest, current)
        end
        return longest
    end

    baseline_objective = 302419.52581

    energy_problem, ocgt_units_on = solve_uc_ramping(nothing)
    @test energy_problem.termination_status == JuMP.OPTIMAL
    @test energy_problem.objective_value ≈ baseline_objective atol = 1e-5
    @test longest_on_run(ocgt_units_on) == 3

    energy_problem, ocgt_units_on = solve_uc_ramping(2)
    @test energy_problem.termination_status == JuMP.OPTIMAL
    @test energy_problem.objective_value ≈ 302847.52306 atol = 1e-5
    @test longest_on_run(ocgt_units_on) == 2

    # A maximum up time longer than the horizon does not change the optimal cost.
    energy_problem, _ = solve_uc_ramping(1000)
    @test energy_problem.termination_status == JuMP.OPTIMAL
    @test energy_problem.objective_value ≈ baseline_objective atol = 1e-5
end
