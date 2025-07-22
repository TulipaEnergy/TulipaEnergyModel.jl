@testset "Test add_decommission_variables!" begin
    # Setup a temporary DuckDB connection and model
    connection = DBInterface.connect(DuckDB.DB)
    model = JuMP.Model()

    # Create test data for assets decommission variables
    asset_decommission_data = DataFrame(;
        id = [1, 2],
        asset = ["wind", "solar"],
        milestone_year = [2030, 2040],
        commission_year = [2020, 2030],
        investment_integer = [true, false],
    )
    DuckDB.register_data_frame(connection, asset_decommission_data, "var_assets_decommission")

    # Create test data for flows decommission variables
    flow_decommission_data = DataFrame(;
        id = [1],
        from_asset = ["wind"],
        to_asset = ["demand"],
        milestone_year = [2030],
        commission_year = [2020],
        investment_integer = [true],
    )
    DuckDB.register_data_frame(connection, flow_decommission_data, "var_flows_decommission")

    # Create test data for assets decommission energy variables
    asset_decommission_energy_data = DataFrame(;
        id = [1],
        asset = ["battery"],
        milestone_year = [2040],
        commission_year = [2030],
        investment_integer_storage_energy = [false],
    )
    DuckDB.register_data_frame(
        connection,
        asset_decommission_energy_data,
        "var_assets_decommission_energy",
    )

    # Create TulipaVariable objects
    variables = Dict{Symbol,TulipaEnergyModel.TulipaVariable}(
        key => TulipaEnergyModel.TulipaVariable(connection, "var_$key") for
        key in (:assets_decommission, :flows_decommission, :assets_decommission_energy)
    )

    # Call the function under test
    TulipaEnergyModel.add_decommission_variables!(model, variables)

    # Test that variables were created correctly
    @test length(variables[:assets_decommission].container) ==
          asset_decommission_data |> DataFrames.nrow
    @test length(variables[:flows_decommission].container) ==
          flow_decommission_data |> DataFrames.nrow
    @test length(variables[:assets_decommission_energy].container) ==
          asset_decommission_energy_data |> DataFrames.nrow

    # Test bounds and integer constraints for assets decommission
    # Note: Decommission variables don't have upper bounds
    asset_vars = variables[:assets_decommission].container
    for row in eachrow(asset_decommission_data)
        var = asset_vars[row.id]
        @test JuMP.lower_bound(var) == 0.0
        @test !JuMP.has_upper_bound(var)
        @test JuMP.is_integer(var) == row.investment_integer
    end

    # Test bounds and integer constraints for flows decommission
    flow_vars = variables[:flows_decommission].container
    for row in eachrow(flow_decommission_data)
        var = flow_vars[row.id]
        @test JuMP.lower_bound(var) == 0.0
        @test !JuMP.has_upper_bound(var)
        @test JuMP.is_integer(var) == row.investment_integer
    end

    # Test bounds and integer constraints for assets decommission energy
    energy_vars = variables[:assets_decommission_energy].container
    for row in eachrow(asset_decommission_energy_data)
        var = energy_vars[row.id]
        @test JuMP.lower_bound(var) == 0.0
        @test !JuMP.has_upper_bound(var)
        @test JuMP.is_integer(var) == row.investment_integer_storage_energy
    end
end
