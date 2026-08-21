@testsnippet ConsMinUpDownTimeSetup begin
    using DuckDB: DBInterface
    using TulipaBuilder: TulipaBuilder as TB
    using TulipaClustering: TulipaClustering as TC

    function create_minimum_up_down_time_problem(resolution; partitioned = false)
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
                minimum_up_time = 4,
                minimum_down_time = 4,
                initial_units = 1.0,
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
        JuMP.@build_constraint(var_start_up[5] + var_start_up[6] <= var_units_on[6])
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
