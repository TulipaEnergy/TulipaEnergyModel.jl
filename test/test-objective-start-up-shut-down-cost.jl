@testitem "Transition costs use one coefficient per commitment event" setup = [CommonSetup] tags =
    [:unit, :fast, :objective] begin
    connection = DBInterface.connect(DuckDB.DB)
    _read_csv_folder(connection, joinpath(INPUT_FOLDER, "UC-ramping"))
    TEM.populate_with_defaults!(connection)

    # values for testing
    start_up_cost = 7.0
    shut_down_cost = 11.0

    # update inputs for testing
    DuckDB.query(
        connection,
        "UPDATE asset SET unit_commitment = '3var' WHERE asset IN ('ccgt', 'smr')",
    )
    DuckDB.query(
        connection,
        "UPDATE asset_milestone SET start_up_cost = $start_up_cost, shut_down_cost = $shut_down_cost WHERE asset = 'ccgt'",
    )
    DuckDB.query(connection, "UPDATE rep_periods_data SET resolution = 2")

    energy_problem = TEM.EnergyProblem(connection)
    TEM.create_model!(energy_problem)

    for uc_transition in (:start_up, :shut_down)
        cost_value = uc_transition == :start_up ? start_up_cost : shut_down_cost
        variable_table = "var_$uc_transition"
        objective_name = Symbol("$(uc_transition)_operational_cost")
        scenario_expression =
            energy_problem.expressions[Symbol("$(uc_transition)_operational_cost_per_scenario")]

        @test haskey(energy_problem.model, objective_name)

        variables = DuckDB.query(
            connection,
            """
            SELECT id, asset, milestone_year, rep_period, time_block_start
            FROM $variable_table
            WHERE asset = 'ccgt'
            ORDER BY id
            """,
        )
        @test !isempty(variables)

        for scenario_row in scenario_expression.indices
            scenario = scenario_row.scenario
            probability = scenario_row.probability
            scenario_cost = scenario_expression.expressions[:cost][scenario_row.id]
            for variable_row in variables
                variable = energy_problem.variables[uc_transition].container[variable_row.id]
                scenario_weight = sum(
                    row.weight for row in DuckDB.query(
                        connection,
                        """
                        SELECT weight
                        FROM rep_periods_mapping
                        WHERE milestone_year = $(variable_row.milestone_year)
                            AND rep_period = $(variable_row.rep_period)
                            AND scenario = '$scenario'
                        """,
                    )
                )
                discount_factor = only(
                    DuckDB.query(
                        connection,
                        """
                        SELECT weight_for_operation_discounts
                        FROM t_objective_assets
                        WHERE asset = 'ccgt'
                            AND milestone_year = $(variable_row.milestone_year)
                        """,
                    ),
                ).weight_for_operation_discounts
                expected_cost = if variable_row.time_block_start == 1
                    0.0
                else
                    cost_value * scenario_weight * discount_factor
                end

                @test JuMP.coefficient(scenario_cost, variable) ≈ expected_cost
                @test JuMP.coefficient(energy_problem.model[objective_name], variable) ≈
                      probability * expected_cost
            end
        end
    end

    @test only(DuckDB.query(connection, "SELECT COUNT(*) AS n FROM obj_breakdown")).n == 12

    TEM.solve_model!(energy_problem)
    TEM.save_solution!(energy_problem)
    for uc_transition in (:start_up, :shut_down)
        objective_name = "$(uc_transition)_operational_cost"
        objective_value = only(
            DuckDB.query(
                connection,
                "SELECT value FROM obj_breakdown WHERE name = '$objective_name'",
            ),
        ).value
        @test objective_value ≈ JuMP.value(energy_problem.model[Symbol(objective_name)])
    end
end
