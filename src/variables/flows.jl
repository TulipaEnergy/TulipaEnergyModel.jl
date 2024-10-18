export add_flow_variables!

"""
    add_flow_variables!(model, dataframes)

Adds flow variables to the optimization `model` based on data from the `dataframes`.
The flow variables are created using the `@variable` macro for each row in the `:flows` dataframe.

"""
function add_flow_variables!(model, dataframes)
    df_flows = dataframes[:flows]

    model[:flow] =
        df_flows.flow = [
            @variable(
                model,
                base_name = "flow[($(row.from), $(row.to)), $(row.year), $(row.rep_period), $(row.timesteps_block)]"
            ) for row in eachrow(df_flows)
        ]

    return
end
