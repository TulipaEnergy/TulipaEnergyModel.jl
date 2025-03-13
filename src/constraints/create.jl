export compute_constraints_indices

function compute_constraints_indices(connection)
    query_file = joinpath(SQL_FOLDER, "create-constraints.sql")
    DuckDB.query(connection, read(query_file, String))

    constraints = Dict{Symbol,TulipaConstraint}(
        key => TulipaConstraint(connection, "cons_$key") for key in (
            :balance_conversion,
            :balance_consumer,
            :balance_hub,
            :capacity_incoming,
            :capacity_incoming_non_investable_storage_with_binary,
            :capacity_incoming_investable_storage_with_binary,
            :capacity_outgoing,
            :capacity_outgoing_simple_investment,
            :capacity_outgoing_non_investable_storage_with_binary,
            :capacity_outgoing_investable_storage_with_binary,
            :limit_units_on,
            :min_output_flow_with_unit_commitment,
            :max_output_flow_with_basic_unit_commitment,
            :max_ramp_with_unit_commitment,
            :max_ramp_without_unit_commitment,
            :balance_storage_rep_period,
            :balance_storage_over_clustered_year,
            :min_energy_over_clustered_year,
            :max_energy_over_clustered_year,
            :transport_flow_limit,
            :group_max_investment_limit,
            :group_min_investment_limit,
        )
    )

    return constraints
end
