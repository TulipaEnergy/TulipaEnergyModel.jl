export add_investment_constraints!

"""
    add_investment_constraints!(connection, variables)

Adds the investment constraints bounds for all asset types and flows
"""
function add_investment_constraints!(connection, variables)
    # TODO: When we refactor the signatures to look the same, we should consider naming it differently
    # TODO: Verify if it's possible and reasonable to move the bound definition to when the

    # - Maximum (i.e., potential) investment limit for assets
    constraint_indices = _create_asset_investment_indices(connection)
    filtered_indices =
        filter(row -> row.capacity > 0 && !ismissing(row.investment_limit), constraint_indices)
    if !isempty(filtered_indices)
        filtered_indices.bound_value .= _find_upper_bound(
            filtered_indices.investment_limit,
            filtered_indices.capacity,
            filtered_indices.investment_integer,
        )
        for (assets_investment, row) in
            zip(variables[:assets_investment].container, eachrow(filtered_indices))
            JuMP.set_upper_bound(assets_investment, row.bound_value)
        end
    end

    # - Maximum (i.e., potential) investment limit for storage assets with energy method
    constraint_indices = _create_asset_investment_energy_indices(connection)
    filtered_indices = filter(
        row ->
            row.capacity_storage_energy > 0 && !ismissing(row.investment_limit_storage_energy),
        constraint_indices,
    )
    if !isempty(filtered_indices)
        filtered_indices.bound_value .= _find_upper_bound(
            filtered_indices.investment_limit_storage_energy,
            filtered_indices.capacity_storage_energy,
            filtered_indices.investment_integer_storage_energy,
        )
        for (assets_investment_energy, row) in
            zip(variables[:assets_investment_energy].container, eachrow(filtered_indices))
            JuMP.set_upper_bound(assets_investment_energy, row.bound_value)
        end
    end

    # - Maximum (i.e., potential) investment limit for flows
    constraint_indices = _create_flow_investment_indices(connection)
    filtered_indices =
        filter(row -> row.capacity > 0 && !ismissing(row.investment_limit), constraint_indices)
    if !isempty(filtered_indices)
        filtered_indices.bound_value .= _find_upper_bound(
            filtered_indices.investment_limit,
            filtered_indices.capacity,
            filtered_indices.investment_integer,
        )
        for (flows_investment, row) in
            zip(variables[:flows_investment].container, eachrow(filtered_indices))
            JuMP.set_upper_bound(flows_investment, row.bound_value)
        end
    end
end

function _create_asset_investment_indices(connection)
    return DuckDB.query(
        connection,
        "SELECT
            indices.asset,
            indices.milestone_year,
            indices.investment_integer,
            asset.capacity,
            asset_commission.investment_limit,
        FROM indices_for_assets_investment AS indices
        LEFT JOIN asset
            ON asset.asset = indices.asset
        LEFT JOIN asset_commission
            ON asset_commission.asset = indices.asset
                AND asset_commission.commission_year = indices.milestone_year
        ",
    ) |> DataFrame
end

function _create_asset_investment_energy_indices(connection)
    return DuckDB.query(
        connection,
        "SELECT
            indices.asset,
            indices.milestone_year,
            indices.investment_integer_storage_energy,
            asset.capacity_storage_energy,
            asset_commission.investment_limit_storage_energy,
        FROM indices_for_assets_investment_energy AS indices
        LEFT JOIN asset
            ON asset.asset = indices.asset
        LEFT JOIN asset_commission
            ON asset_commission.asset = indices.asset
                AND asset_commission.commission_year = indices.milestone_year
        ",
    ) |> DataFrame
end

function _create_flow_investment_indices(connection)
    return DuckDB.query(
        connection,
        "SELECT
            indices.from_asset,
            indices.to_asset,
            indices.milestone_year,
            indices.investment_integer,
            flow.capacity,
            flow_commission.investment_limit,
        FROM indices_for_flows_investment AS indices
        LEFT JOIN flow
            ON flow.from_asset = indices.from_asset
                AND flow.to_asset = indices.to_asset
        LEFT JOIN flow_commission
            ON flow_commission.from_asset = indices.from_asset
                AND flow_commission.to_asset = indices.to_asset
                AND flow_commission.commission_year = indices.milestone_year
        ",
    ) |> DataFrame
end

function _find_upper_bound(investment_limit, capacity, investment_integer)
    bound_value = investment_limit ./ capacity
    bound_value = [
        integer == true ? floor(value) : value for
        (integer, value) in zip(investment_integer, bound_value)
    ]
    return bound_value
end
