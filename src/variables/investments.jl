export add_investment_variables!

function _create_investment_variable!(
    model,
    variables,
    name,
    keys_from_row;
    lower_bound_from_row = row -> -Inf,
    integer_from_row = row -> false,
)
    this_var = variables[name]
    this_var.container = [
        @variable(
            model,
            lower_bound = lower_bound_from_row(row),
            integer = integer_from_row(row),
            base_name = "$name[" * join(keys_from_row(row), ",") * "]"
        ) for row in eachrow(this_var.indices)
    ]
    this_var.lookup = OrderedDict(
        keys_from_row(row) => var for
        (var, row) in zip(this_var.container, eachrow(this_var.indices))
    )
end

"""
    add_investment_variables!(model, graph, sets)

Adds investment, decommission, and energy-related variables to the optimization `model`,
and sets integer constraints on selected variables based on the `graph` data.

"""
function add_investment_variables!(model, graph, sets, variables)
    for (name, keys_from_row, lower_bound_from_row, integer_from_row) in [
        (
            :flows_investment,
            row -> (row.milestone_year, (row.from_asset, row.to_asset)),
            _ -> 0.0,
            row -> row.investment_integer,
        ),
        (
            :assets_investment,
            row -> (row.milestone_year, row.asset),
            _ -> 0.0,
            row -> row.investment_integer,
        ),
        (
            :assets_decommission_simple_method,
            row -> (row.milestone_year, row.asset),
            _ -> 0.0,
            row -> row.investment_integer,
        ),
        (
            :flows_decommission_using_simple_method,
            row -> (row.milestone_year, (row.from_asset, row.to_asset)),
            _ -> 0.0,
            _ -> false,
        ),
        (
            :assets_decommission_compact_method,
            row -> (row.asset, row.milestone_year, row.commission_year),
            _ -> 0.0,
            row -> row.investment_integer,
        ),
        (
            :assets_investment_energy,
            row -> (row.milestone_year, row.asset),
            _ -> 0.0,
            row -> row.investment_integer_storage_energy,
        ),
        (
            :assets_decommission_energy_simple_method,
            row -> (row.milestone_year, row.asset),
            _ -> 0.0,
            row -> row.investment_integer_storage_energy,
        ),
    ]
        _create_investment_variable!(
            model,
            variables,
            name,
            keys_from_row;
            lower_bound_from_row,
            integer_from_row,
        )
    end

    return
end
