@testsnippet TutorialSetup begin
    using TulipaClustering: TulipaClustering as TC

    const TUTORIAL_INPUT_FOLDER =
        joinpath(@__DIR__, "../docs/src/10-tutorials/my-awesome-energy-system")

    function _tutorial_connection(folder; preprocess! = _ -> nothing)
        connection = DBInterface.connect(DuckDB.DB)
        TulipaIO.read_csv_folder(connection, joinpath(TUTORIAL_INPUT_FOLDER, folder))
        preprocess!(connection)
        TulipaEnergyModel.populate_with_defaults!(connection)
        return connection
    end

    function _cluster_tutorial_4!(connection)
        TC.transform_wide_to_long!(
            connection,
            "profiles_wide",
            "profiles";
            exclude_columns = ["milestone_year", "timestep"],
        )
        TC.cluster!(
            connection,
            24,
            4;
            method = :convex_hull,
            distance = TC.Distances.CosineDist(),
            weight_type = :convex,
            tol = 1e-6,
            weight_fitting_kwargs = Dict(:learning_rate => 0.001, :niters => 2000),
            layout = TC.ProfilesTableLayout(; year = :milestone_year),
        )
        return nothing
    end

    function _cluster_tutorial_5!(connection)
        TC.transform_wide_to_long!(
            connection,
            "profiles_wide",
            "profiles";
            exclude_columns = ["milestone_year", "timestep"],
        )
        TC.cluster!(
            connection,
            24,
            12;
            method = :convex_hull,
            distance = TC.Distances.CosineDist(),
            weight_type = :convex,
            tol = 1e-6,
            weight_fitting_kwargs = Dict(:learning_rate => 0.001, :niters => 2000),
            layout = TC.ProfilesTableLayout(; year = :milestone_year),
        )
        return nothing
    end

    function _cluster_tutorial_9!(connection)
        TC.transform_wide_to_long!(
            connection,
            "profiles_wide",
            "profiles";
            exclude_columns = ["scenario", "milestone_year", "timestep"],
        )
        layout = TC.ProfilesTableLayout(;
            year = :milestone_year,
            cols_to_groupby = [:milestone_year],
            cols_to_crossby = [:scenario],
        )
        TC.cluster!(
            connection,
            24,
            16;
            method = :convex_hull,
            distance = TC.Distances.CosineDist(),
            weight_type = :convex,
            tol = 1e-6,
            weight_fitting_kwargs = Dict(:learning_rate => 0.001, :niters => 2000),
            layout,
        )
        return nothing
    end
end

@testitem "Tutorial 1 objective value" setup = [CommonSetup, TutorialSetup] tags =
    [:integration, :slow] begin
    connection = _tutorial_connection("tutorial-1")
    energy_problem = TulipaEnergyModel.run_scenario(connection; show_log = false)
    @test energy_problem.objective_value ≈ 2.175768638386125e8 atol = 1e-5
    # populate_with_defaults shouldn't change the solution
    TulipaEnergyModel.populate_with_defaults!(connection)
    energy_problem = TulipaEnergyModel.run_scenario(connection; show_log = false)
    @test energy_problem.objective_value ≈ 2.175768638386125e8 atol = 1e-5
end

@testitem "Tutorial 2 objective value" setup = [CommonSetup, TutorialSetup] tags =
    [:integration, :slow] begin
    connection = _tutorial_connection("tutorial-2")
    energy_problem = TulipaEnergyModel.run_scenario(connection; show_log = false)
    @test energy_problem.objective_value ≈ 1.4854146333461672e8 atol = 1e-5
    # populate_with_defaults shouldn't change the solution
    TulipaEnergyModel.populate_with_defaults!(connection)
    energy_problem = TulipaEnergyModel.run_scenario(connection; show_log = false)
    @test energy_problem.objective_value ≈ 1.4854146333461672e8 atol = 1e-5
end

@testitem "Tutorial 3 objective value" setup = [CommonSetup, TutorialSetup] tags =
    [:integration, :slow] begin
    connection = _tutorial_connection("tutorial-3")
    energy_problem = TulipaEnergyModel.run_scenario(connection; show_log = false)
    @test energy_problem.objective_value ≈ 1.4854146333461672e8 atol = 1e-5
    # populate_with_defaults shouldn't change the solution
    TulipaEnergyModel.populate_with_defaults!(connection)
    energy_problem = TulipaEnergyModel.run_scenario(connection; show_log = false)
    @test energy_problem.objective_value ≈ 1.4854146333461672e8 atol = 1e-5
end

@testitem "Tutorial 4 objective value" setup = [CommonSetup, TutorialSetup] tags =
    [:integration, :slow] begin
    connection = _tutorial_connection("tutorial-4"; preprocess! = _cluster_tutorial_4!)
    energy_problem = TulipaEnergyModel.run_scenario(connection; show_log = false)
    @test energy_problem.objective_value ≈ 1.6628272019781297e8 atol = 1e-5
    # populate_with_defaults shouldn't change the solution
    TulipaEnergyModel.populate_with_defaults!(connection)
    energy_problem = TulipaEnergyModel.run_scenario(connection; show_log = false)
    @test energy_problem.objective_value ≈ 1.6628272019781297e8 atol = 1e-5
end

@testitem "Tutorial 5 objective value" setup = [CommonSetup, TutorialSetup] tags =
    [:integration, :slow] begin
    connection = _tutorial_connection("tutorial-5"; preprocess! = _cluster_tutorial_5!)
    energy_problem = TulipaEnergyModel.run_scenario(connection; show_log = false)
    @test energy_problem.objective_value ≈ 3.3675960187027e8 atol = 1e-5
    # populate_with_defaults shouldn't change the solution
    TulipaEnergyModel.populate_with_defaults!(connection)
    energy_problem = TulipaEnergyModel.run_scenario(connection; show_log = false)
    @test energy_problem.objective_value ≈ 3.3675960187027e8 atol = 1e-5
end

@testitem "Tutorial 6 simple method objective value" setup = [CommonSetup, TutorialSetup] tags =
    [:integration, :slow] begin
    connection = _tutorial_connection("tutorial-6-simple-method")
    energy_problem = TulipaEnergyModel.run_scenario(connection; show_log = false)
    @test energy_problem.objective_value ≈ 8511709.40963 atol = 1e-5
    # populate_with_defaults shouldn't change the solution
    TulipaEnergyModel.populate_with_defaults!(connection)
    energy_problem = TulipaEnergyModel.run_scenario(connection; show_log = false)
    @test energy_problem.objective_value ≈ 8511709.40963 atol = 1e-5
end

@testitem "Tutorial 6 compact method objective value" setup = [CommonSetup, TutorialSetup] tags =
    [:integration, :slow] begin
    connection = _tutorial_connection("tutorial-6-compact-method")
    energy_problem = TulipaEnergyModel.run_scenario(connection; show_log = false)
    @test energy_problem.objective_value ≈ 8629317.65966 atol = 1e-5
    # populate_with_defaults shouldn't change the solution
    TulipaEnergyModel.populate_with_defaults!(connection)
    energy_problem = TulipaEnergyModel.run_scenario(connection; show_log = false)
    @test energy_problem.objective_value ≈ 8629317.65966 atol = 1e-5
end

@testitem "Tutorial 9 objective value" setup = [CommonSetup, TutorialSetup] tags =
    [:integration, :slow] begin
    connection = _tutorial_connection("tutorial-9"; preprocess! = _cluster_tutorial_9!)
    energy_problem = TulipaEnergyModel.run_scenario(connection; show_log = false)
    @test energy_problem.objective_value ≈ 531.19287 atol = 1e-5
    # populate_with_defaults shouldn't change the solution
    TulipaEnergyModel.populate_with_defaults!(connection)
    energy_problem = TulipaEnergyModel.run_scenario(connection; show_log = false)
    @test energy_problem.objective_value ≈ 531.19287 atol = 1e-5
end

@testitem "Tutorial CVaR objective value" setup = [CommonSetup, TutorialSetup] tags =
    [:integration, :slow] begin
    connection = _tutorial_connection("tutorial-cvar")
    energy_problem = TulipaEnergyModel.run_scenario(connection; show_log = false)
    @test energy_problem.objective_value ≈ 39700.0 atol = 1e-5
    # populate_with_defaults shouldn't change the solution
    TulipaEnergyModel.populate_with_defaults!(connection)
    energy_problem = TulipaEnergyModel.run_scenario(connection; show_log = false)
    @test energy_problem.objective_value ≈ 39700.0 atol = 1e-5
end
