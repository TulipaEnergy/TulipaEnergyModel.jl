export compute_variables_indices

# TODO: Allow changing table names to make unit tests possible
# The signature should be something like `...(connection; assets_data="t_assets_data", ...)`
function compute_variables_indices(connection)
    query_file = joinpath(SQL_FOLDER, "create-variables.sql")
    DuckDB.query(connection, read(query_file, String))

    variables = Dict{Symbol,TulipaVariable}(
        key => TulipaVariable(connection, "var_$key") for key in (
            :flow,
            :units_on,
            :is_charging,
            :storage_level_rep_period,
            :storage_level_over_clustered_year,
            :assets_investment,
            :assets_decommission,
            :assets_decommission_simple_investment,
            :flows_investment,
            :flows_decommission,
            :assets_investment_energy,
            :assets_decommission_energy,
        )
    )

    return variables
end
