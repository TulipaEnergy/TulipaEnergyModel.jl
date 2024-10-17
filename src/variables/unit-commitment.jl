export add_unit_commitment_variables!

"""
    add_unit_commitment_variables!(model, dataframes, sets)

Adds unit commitment variables to the optimization `model` based on the `:units_on` dataframe.
Additionally, variables are constrained to be integers based on the `sets` structure.

"""
function add_unit_commitment_variables!(model, dataframes, sets)
    df_units_on = dataframes[:units_on]

    model[:units_on] =
        df_units_on.units_on = [
            @variable(
                model,
                lower_bound = 0.0,
                base_name = "units_on[$(row.asset),$(row.year),$(row.rep_period),$(row.timesteps_block)]"
            ) for row in eachrow(df_units_on)
        ]

    ### Integer Unit Commitment Variables
    for row in eachrow(df_units_on)
        if !(row.asset in sets.Auc_integer[row.year])
            continue
        end

        JuMP.set_integer(model[:units_on][row.index])
    end

    return
end
