export compute_variables_indices

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
            "SELECT from_asset, to_asset, year, FROM flows_data WHERE investable=true",
        ) |> DataFrame,
    )

    variables[:assets_investment] = TulipaVariable(
        DuckDB.query(connection, "SELECT name, year FROM assets_data WHERE investable=true") |>
        DataFrame,
    )

    variables[:assets_decommission_simple_method] = TulipaVariable(
        DuckDB.query(
            connection,
            "SELECT DISTINCT assets_data.name, assets_data.year FROM assets_data
            LEFT JOIN graph_assets_data
                ON assets_data.name=graph_assets_data.name
            WHERE investment_method='simple'",
        ) |> DataFrame,
    )

    # TODO: Translate compact decommission into SQL
    # variables[:assets_decommission_compact_method] = TulipaVariable(
    #     DuckDB.query(
    #         connection,
    #         "SELECT DISTINCT assets_data.name, assets_data.year, assets_data.commission_year FROM assets_data
    #         LEFT JOIN graph_assets_data
    #             ON assets_data.name=graph_assets_data.name
    #         LEFT JOIN year_data
    #             ON assets_data.year=year_data.year
    #             AND assets_data.commission_year=commission_year_data.commission_year
    #         WHERE
    #             investment_method='compact'
    #             AND assets_data.year - graph_assets_data.technical-lifetime + 1 <= assets_data.commission_year < assets_data.year
    #             AND ass
    #             ",
    #     ) |> DataFrame,
    # )

    variables[:flows_decommission_using_simple_method] = TulipaVariable(
        DuckDB.query(
            connection,
            "SELECT flows_data.from_asset, flows_data.to_asset, flows_data.year FROM flows_data
            LEFT JOIN graph_flows_data
                ON flows_data.from_asset=graph_flows_data.from_asset
                AND flows_data.to_asset=graph_flows_data.to_asset
            WHERE graph_flows_data.is_transport=true
            ",
        ) |> DataFrame,
    )

    variables[:assets_investment_energy] = TulipaVariable(DuckDB.query(
        connection,
        "SELECT name, year FROM assets_data
        WHERE storage_method_energy=true
            AND investable=true
        ",
    ) |> DataFrame)

    return variables
end
