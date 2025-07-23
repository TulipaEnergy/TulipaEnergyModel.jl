export compute_variables_indices

# TODO: Allow changing table names to make unit tests possible
# The signature should be something like `...(connection; assets_data="t_assets_data", ...)`
function compute_variables_indices(connection)
    query_file = joinpath(SQL_FOLDER, "create-variables.sql")
    DuckDB.query(connection, read(query_file, String))

    variables = Dict{Symbol,TulipaVariable}(
        key => TulipaVariable(connection, "var_$key") for key in (
            :flow,
            :vintage_flow,
            :units_on,
            :electricity_angle,
            :is_charging,
            :storage_level_rep_period,
            :storage_level_over_clustered_year,
            :assets_investment,
            :assets_decommission,
            :flows_investment,
            :flows_decommission,
            :assets_investment_energy,
            :assets_decommission_energy,
        )
    )

    return variables
end

"""
    _create_variables_from_indices!(
    model,
    variables,
    name,
    keys_from_row;
    lower_bound_from_row = row -> -Inf,
    upper_bound_from_row = row -> Inf,
    integer_from_row = row -> false,
)

This function creates variables by iterating over the variable indices,
where each variable can have different properties determined by the index/row data.
"""
function _create_variables_from_indices!(
    model,
    variables,
    name,
    keys_from_row;
    lower_bound_from_row = row -> -Inf,
    upper_bound_from_row = row -> Inf,
    integer_from_row = row -> false,
)
    this_var = variables[name]
    this_var.container = [
        @variable(
            model,
            lower_bound = lower_bound_from_row(row),
            upper_bound = upper_bound_from_row(row),
            integer = integer_from_row(row),
            base_name = "$name[" * join(keys_from_row(row), ",") * "]"
        ) for row in this_var.indices
    ]
    return
end

"""
    _create_variables_from_specifications!(model, variables, specifications)

Creates variables based on a dictionary of specifications.
Each specification should contain keys_from_row, lower_bound_from_row, upper_bound_from_row, and integer_from_row functions.
"""
function _create_variables_from_specifications!(model, variables, specifications)
    for (name, spec) in specifications
        _create_variables_from_indices!(
            model,
            variables,
            name,
            spec.keys_from_row;
            lower_bound_from_row = spec.lower_bound_from_row,
            upper_bound_from_row = spec.upper_bound_from_row,
            integer_from_row = spec.integer_from_row,
        )
    end
    return
end
