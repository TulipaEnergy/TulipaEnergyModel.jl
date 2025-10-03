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
            :capacity_outgoing_semi_compact_method,
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
            :min_outgoing_flow_for_transport_vintage_flows,
            :min_incoming_flow_for_transport_flows,
            :group_max_investment_limit,
            :group_min_investment_limit,
            :flows_relationships,
            :dc_power_flow,
            :limit_decommission_compact_method,
            :vintage_flow_sum_semi_compact_method,
            :start_up_upper_bound,
            :shut_down_upper_bound_simple_investment,
            :shut_down_upper_bound_compact_investment,
            :unit_commitment_logic,
            :start_up_lower_bound,
            :shut_down_lower_bound,
            :minimum_up_time,
            :minimum_down_time_simple_investment,
            :minimum_down_time_compact_investment,
            :su_ramp_vars_flow_diff,
            :sd_ramp_vars_flow_diff,
            :su_ramp_vars_flow_upper_bound,
            :sd_ramp_vars_flow_upper_bound,
            :su_sd_ramp_vars_flow_with_high_uptime,
            :su_ramping_compact_1bin,
            :sd_ramping_compact_1bin,
            :su_ramping_tight_1bin,
            :sd_ramping_tight_1bin,
            :minimum_down_time_2var_simple_investment,
            :minimum_down_time_2var_compact_investment,
        )
    )

    return constraints
end
