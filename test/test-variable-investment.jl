@testset "Test add_investment_variables!" begin
    # Setup a temporary DuckDB connection and model
    connection = DBInterface.connect(DuckDB.DB)
    model = JuMP.Model()

    # Create test data for assets investment variables
    asset_investment_data = DataFrame(;
        id = [1, 2, 3, 4],
        asset = ["wind", "solar", "battery", "ccgt"],
        milestone_year = [2030, 2030, 2040, 2040],
        investment_integer = [true, false, true, true],
        capacity = [100.0, 50.0, 25.0, 125.0],
        investment_limit = [1000.0, missing, 500.0, 650.0],
    )
    DuckDB.register_data_frame(connection, asset_investment_data, "var_assets_investment")

    # Create test data for flows investment variables
    flow_investment_data = DataFrame(;
        id = [1, 2],
        from_asset = ["wind", "solar"],
        to_asset = ["demand", "demand"],
        milestone_year = [2030, 2030],
        investment_integer = [false, true],
        capacity = [80.0, 60.0],
        investment_limit = [800.0, missing],
    )
    DuckDB.register_data_frame(connection, flow_investment_data, "var_flows_investment")

    # Create test data for assets investment energy variables
    asset_investment_energy_data = DataFrame(;
        id = [1],
        asset = ["battery"],
        milestone_year = [2040],
        investment_integer_storage_energy = [true],
        capacity_storage_energy = [100.0],
        investment_limit_storage_energy = [1200.0],
    )
    DuckDB.register_data_frame(
        connection,
        asset_investment_energy_data,
        "var_assets_investment_energy",
    )

    # Create TulipaVariable objects
    variables = Dict{Symbol,TulipaEnergyModel.TulipaVariable}(
        key => TulipaEnergyModel.TulipaVariable(connection, "var_$key") for
        key in (:flows_investment, :assets_investment, :assets_investment_energy)
    )

    # Call the function under test
    TulipaEnergyModel.add_investment_variables!(model, variables)

    # Test that variables were created correctly
    @test length(variables[:assets_investment].container) ==
          asset_investment_data |> DataFrames.nrow
    @test length(variables[:flows_investment].container) == flow_investment_data |> DataFrames.nrow
    @test length(variables[:assets_investment_energy].container) ==
          asset_investment_energy_data |> DataFrames.nrow

    # Test bounds and integer constraints for assets investment
    asset_vars = variables[:assets_investment].container
    for row in eachrow(asset_investment_data)
        _test_variable_properties(
            asset_vars[row.id],
            0.0,
            ismissing(row.investment_limit) ? nothing : floor(row.investment_limit / row.capacity);
            is_integer = row.investment_integer,
        )
    end

    # Test bounds and integer constraints for flows investment
    flow_vars = variables[:flows_investment].container
    for row in eachrow(flow_investment_data)
        _test_variable_properties(
            flow_vars[row.id],
            0.0,
            ismissing(row.investment_limit) ? nothing : floor(row.investment_limit / row.capacity);
            is_integer = row.investment_integer,
        )
    end

    # Test bounds and integer constraints for assets investment energy
    energy_vars = variables[:assets_investment_energy].container
    for row in eachrow(asset_investment_energy_data)
        _test_variable_properties(
            energy_vars[row.id],
            0.0,
            if ismissing(row.investment_limit_storage_energy)
                nothing
            else
                floor(row.investment_limit_storage_energy / row.capacity_storage_energy)
            end;
            is_integer = row.investment_integer_storage_energy,
        )
    end
end
