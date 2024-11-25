export add_flow_variables!

"""
    add_flow_variables!(model, variables)

Adds flow variables to the optimization `model` based on data from the `variables`.
The flow variables are created using the `@variable` macro for each row in the `:flows` dataframe.

"""
function add_flow_variables!(model, variables)
    # Unpacking the variable indices
    flows_indices = variables[:flow].indices

    variables[:flow].container = [
        @variable(
            model,
            base_name = "flow[($(row.from), $(row.to)), $(row.year), $(row.rep_period), $(row.time_block_start):$(row.time_block_end)]"
        ) for row in eachrow(flows_indices)
    ]

    return
end
