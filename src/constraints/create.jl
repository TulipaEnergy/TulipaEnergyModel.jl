function compute_constraints_indices(connection)
    query_file = joinpath(SQL_FOLDER, "create-constraints.sql")
    DuckDB.query(connection, read(query_file, String))

    constraints = Dict{Symbol,TulipaConstraint}(
        key => TulipaConstraint(connection, "cons_$key") for key in (
            :balance_conversion,
            :balance_consumer,
            :capacity_incoming_aggregated_vintage_method,
            :capacity_incoming_aggregated_vintage_method_non_investable_storage_with_binary,
            :capacity_incoming_aggregated_vintage_method_investable_storage_with_binary,
            :capacity_outgoing_compact_profiles_vintage_method,
            :capacity_outgoing_compact_efficiencies_vintage_method,
            :capacity_outgoing_aggregated_vintage_method,
            :capacity_outgoing_aggregated_vintage_method_non_investable_storage_with_binary,
            :capacity_outgoing_aggregated_vintage_method_investable_storage_with_binary,
            :limit_units_on_compact_vintage_method,
            :limit_units_on_aggregated_vintage_method,
            :min_output_flow_with_unit_commitment,
            :min_output_flow_without_unit_commitment_aggregated_vintage_method,
            :min_output_flow_without_unit_commitment_compact_vintage_method,
            :max_output_flow_with_basic_unit_commitment,
            :max_ramp_with_unit_commitment,
            :max_ramp_without_unit_commitment,
            :balance_storage_rep_period,
            :balance_storage_inter_period,
            :accumulated_storage_intra_period,
            :min_energy_inter_period,
            :max_energy_inter_period,
            :transport_flow_limit_aggregated_vintage_method,
            :min_outgoing_flow_for_transport_flows_without_unit_commitment,
            :min_outgoing_flow_for_transport_vintage_flows,
            :min_incoming_flow_for_transport_flows,
            :group_investment,
            :flows_relationships,
            :dc_power_flow,
            :limit_decommission_compact_vintage_method,
            :vintage_flow_sum_compact_efficiencies_vintage_method,
            :start_up_upper_bound,
            :shut_down_upper_bound_aggregated_vintage_method,
            :shut_down_upper_bound_compact_vintage_method,
            :unit_commitment_logic,
            :scenario_tail_excess,
        )
    )

    return constraints
end
