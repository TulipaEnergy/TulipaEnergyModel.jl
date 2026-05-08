@testitem "Test two assets can share inflows profile with different storage_inflows value" setup =
    [CommonSetup] tags = [:unit, :validation, :fast] begin
    using DuckDB
    using JuMP
    using TulipaEnergyModel: TulipaEnergyModel as TEM
    using TulipaClustering: TulipaClustering as TC
    using TulipaBuilder: TulipaBuilder as TB

    #= The issue happens if the inflows profile is saved in the profiles
    # structure using specific asset value (in this case, storage_inflows)
    =#

    # We create a simple tulipa problem with two storage assets
    tulipa = TB.TulipaData()

    storage_inflows = Dict("storageA" => 2.5, "storageB" => 5.5)
    TB.add_asset!(tulipa, "generator", :producer)
    TB.add_asset!(tulipa, "consumer", :consumer)
    TB.add_flow!(tulipa, "generator", "consumer")
    TB.add_flow!(tulipa, "consumer", "storageB")
    TB.add_flow!(tulipa, "storageB", "consumer")

    for storage_asset in ("storageA", "storageB")
        TB.add_asset!(
            tulipa,
            storage_asset,
            :storage;
            storage_inflows = storage_inflows[storage_asset],
            is_seasonal = true,
        )
        TB.add_flow!(tulipa, "consumer", storage_asset)
        TB.add_flow!(tulipa, storage_asset, "consumer")
    end

    # Attach profile only to storageA
    inflows_profile = [0.5; 0.25; 0.125]
    TB.attach_profile!(tulipa, "storageA", :inflows, 2030, inflows_profile)
    num_time_blocks = length(inflows_profile)

    connection = create_connection(tulipa)

    # Use same profile for storageB
    DuckDB.query(
        connection,
        """
        INSERT INTO assets_profiles BY NAME
        SELECT
            'storageB' AS asset,
            * EXCLUDE (asset),
        FROM assets_profiles WHERE asset = 'storageA'
        """,
    )

    # Cluster, populate_with_defaults, and create model
    TC.dummy_cluster!(connection; layout = TC.ProfilesTableLayout(; year = :milestone_year))
    TEM.populate_with_defaults!(connection)
    energy_problem = TEM.EnergyProblem(connection)
    TEM.create_model!(energy_problem)

    # Actual test, create expected constraint
    storage_level_intra =
        energy_problem.variables[:accumulated_storage_level_intra_period].container
    flow = energy_problem.variables[:flow].container
    cons_name = :accumulated_storage_intra_period

    for storage_asset in ("storageA", "storageB")
        storage_level_ids = [
            row.id for row in DuckDB.query(
                connection,
                """
                SELECT id
                FROM var_accumulated_storage_level_intra_period
                WHERE asset = '$storage_asset'
                """,
            )
        ]
        for tb in 1:num_time_blocks
            incoming_flow_ids = [row.id for row in DuckDB.query(
                connection,
                """
                SELECT id
                 FROM var_flow
                 WHERE to_asset = '$storage_asset'
                    AND time_block_start = $tb
                """,
            )]
            outgoing_flow_ids = [row.id for row in DuckDB.query(
                connection,
                """
                SELECT id
                 FROM var_flow
                 WHERE from_asset = '$storage_asset'
                    AND time_block_start = $tb
                """,
            )]

            incoming = sum(flow[id] for id in incoming_flow_ids)
            outgoing = sum(flow[id] for id in outgoing_flow_ids)
            rhs = inflows_profile[tb] * storage_inflows[storage_asset]

            if tb == 1
                expected_cons = JuMP.@build_constraint(
                    storage_level_intra[storage_level_ids[1]] - incoming + outgoing == rhs
                )
            else
                expected_cons = JuMP.@build_constraint(
                    storage_level_intra[storage_level_ids[tb]] -
                    storage_level_intra[storage_level_ids[tb-1]] - incoming + outgoing == rhs
                )
            end

            cons_id = only([row.id for row in DuckDB.query(
                connection,
                """
                SELECT id
                FROM cons_$cons_name
                WHERE asset = '$storage_asset'
                    AND time_block_start = $tb
                """,
            )])

            observed_cons = _get_cons_object(energy_problem.model, cons_name)[cons_id]

            @test _is_constraint_equal(expected_cons, observed_cons)
        end
    end
end
