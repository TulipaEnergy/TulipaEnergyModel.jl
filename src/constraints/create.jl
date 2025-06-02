export compute_constraints_indices

function compute_constraints_indices(connection)
    query_file = joinpath(SQL_FOLDER, "create-constraints.sql")
    DuckDB.query(connection, read(query_file, String))

    constraints = Dict{Symbol,TulipaConstraint}(
        key => TulipaConstraint(connection, "cons_$key") for key in (
            :balance_conversion,
            :balance_consumer,
            :balance_hub,
            :capacity_incoming_simple_method,
            :capacity_incoming_simple_method_non_investable_storage_with_binary,
            :capacity_incoming_simple_method_investable_storage_with_binary,
            :capacity_outgoing_compact_method,
            :capacity_outgoing_simple_method,
            :capacity_outgoing_simple_method_non_investable_storage_with_binary,
            :capacity_outgoing_simple_method_investable_storage_with_binary,
            :limit_units_on_compact_method,
            :limit_units_on_simple_method,
            :min_output_flow_with_unit_commitment,
            :max_output_flow_with_basic_unit_commitment,
            :max_ramp_with_unit_commitment,
            :max_ramp_without_unit_commitment,
            :balance_storage_rep_period,
            :balance_storage_over_clustered_year,
            :min_energy_over_clustered_year,
            :max_energy_over_clustered_year,
            :transport_flow_limit_simple_method,
            :min_outgoing_flow_for_transport_flows_without_unit_commitment,
            :min_incoming_flow_for_transport_flows,
            :group_max_investment_limit,
            :group_min_investment_limit,
            :flows_relationships,
            :dc_power_flow,
            :limit_decommission_compact_method,
        )
    )

    return constraints
end
