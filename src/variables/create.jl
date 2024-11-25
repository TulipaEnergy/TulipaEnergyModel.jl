export compute_variables_indices

# TODO: Allow changing table names to make unit tests possible
# The signature should be something like `...(connection; assets_data="t_assets_data", ...)`
function compute_variables_indices(connection, dataframes)
    variables = Dict(
        :flow => TulipaVariable(dataframes[:flows]),
        :units_on => TulipaVariable(dataframes[:units_on]),
        :storage_level_intra_rp => TulipaVariable(dataframes[:storage_level_intra_rp]),
        :storage_level_inter_rp => TulipaVariable(dataframes[:storage_level_inter_rp]),
        :is_charging => TulipaVariable(dataframes[:lowest_in_out]),
    )

    variables[:flows_investment] = TulipaVariable(
        DuckDB.query(
            connection,
            "SELECT
                flow.from_asset,
                flow.to_asset,
                flow_milestone.milestone_year,
                flow.investment_integer,
            FROM flow_milestone
            LEFT JOIN flow
                ON flow.from_asset = flow_milestone.from_asset
                AND flow.to_asset = flow_milestone.to_asset
            WHERE
                flow_milestone.investable = true",
        ) |> DataFrame,
    )
    dataframes[:flows_investment] = variables[:flows_investment].indices

    variables[:assets_investment] = TulipaVariable(
        DuckDB.query(
            connection,
            "SELECT
                asset.asset,
                asset_milestone.milestone_year,
                asset.investment_integer,
            FROM asset_milestone
            LEFT JOIN asset
                ON asset.asset = asset_milestone.asset
            WHERE
                asset_milestone.investable = true",
        ) |> DataFrame,
    )
    dataframes[:assets_investment] = variables[:assets_investment].indices

    variables[:assets_decommission_simple_method] = TulipaVariable(
        DuckDB.query(
            connection,
            "SELECT
                asset.asset,
                asset_milestone.milestone_year,
                asset.investment_integer,
            FROM asset_milestone
            LEFT JOIN asset
                ON asset.asset = asset_milestone.asset
            WHERE
                asset.investment_method = 'simple'",
        ) |> DataFrame,
    )

    variables[:assets_decommission_compact_method] = TulipaVariable(
        DuckDB.query(
            connection,
            "SELECT
                asset_both.asset,
                asset_both.milestone_year,
                asset_both.commission_year,
                asset_both.decommissionable,
                asset.investment_integer
            FROM asset_both
            LEFT JOIN asset
                ON asset.asset = asset_both.asset
            WHERE
                asset_both.decommissionable = true
                AND asset.investment_method = 'compact'
            ",
        ) |> DataFrame,
    )

    variables[:flows_decommission_using_simple_method] = TulipaVariable(
        DuckDB.query(
            connection,
            "SELECT
                flow.from_asset,
                flow.to_asset,
                flow_milestone.milestone_year
            FROM flow_milestone
            LEFT JOIN flow
                ON flow.from_asset = flow_milestone.from_asset
                AND flow.to_asset = flow_milestone.to_asset
            WHERE
                flow.is_transport = true
            ",
        ) |> DataFrame,
    )

    variables[:assets_investment_energy] = TulipaVariable(
        DuckDB.query(
            connection,
            "SELECT
                asset.asset,
                asset_milestone.milestone_year,
                asset.investment_integer_storage_energy,
            FROM asset_milestone
            LEFT JOIN asset
                ON asset.asset = asset_milestone.asset
            WHERE
                asset.storage_method_energy = true
                AND asset_milestone.investable = true
                AND asset.type = 'storage'
                AND asset.investment_method = 'simple'
            ",
        ) |> DataFrame,
    )

    variables[:assets_decommission_energy_simple_method] = TulipaVariable(
        DuckDB.query(
            connection,
            "SELECT
                asset.asset,
                asset_milestone.milestone_year,
                asset.investment_integer_storage_energy,
            FROM asset_milestone
            LEFT JOIN asset
                ON asset.asset = asset_milestone.asset
            WHERE
                asset.storage_method_energy = true
                AND asset.type = 'storage'
                AND asset.investment_method = 'simple'",
        ) |> DataFrame,
    )

    return variables
end
