export add_trajectory_constraints!

"""
    add_trajectory_constraints!(model, constraints)
Adds the start up trajectory constraints to the model.
Assets using this constraint should have a minimum down time >= length of start up trajectory + length of shut down trajectory
"""
function add_trajectory_constraints!(
    connection,
    model,
    variables,
    expressions,
    constraints,
    profiles,
)
    let table_name = :susd_trajectory, cons = constraints[table_name]
        # Prevent error if column doesnt exist
        if length(collect(cons.indices)) == 0
            return
        end

        indices = _append_data_to_trajectory(connection)

        # Expression for pmax = capacity * profile * units_on
        attach_expression!(
            cons,
            :max_production,
            [
                @expression(
                    model,
                    row.capacity *
                    _profile_aggregate(
                        profiles.rep_period,
                        (row.profile_name, row.year, row.rep_period),
                        row.time_block_start:row.time_block_end,
                        Statistics.mean,
                        1.0,
                    ) *
                    cons.expressions[:units_on][row.id]
                ) for row in indices
            ],
        )

        # Expression for pmin = min_op_point * pmax
        attach_expression!(
            cons,
            :min_production,
            [
                @expression(
                    model,
                    row.min_operating_point * cons.expressions[:max_production][row.id]
                ) for row in indices
            ],
        )

        # Label expressions
        flow_total = cons.expressions[:outgoing]
        pmin = cons.expressions[:min_production]
        pmax = cons.expressions[:max_production]

        """
        The idea here is to read and process every trajectory just once and store the results.
        This prevents it from having to be computed for every individual constraint.
        """
        # Read trajectory data
        asset_trajectory_info = _get_trajectory_info(connection)

        # Holds assetname -> ((su_trajectory, su_length), (sd_trajectory, sd_length))
        trajectories_info = Dict{String,Dict{String,Union{Vector{Int64},Int64}}}()

        for asset_row in asset_trajectory_info
            trajectories_info[asset_row.asset] = Dict{String,Union{String,Int64}}()

            trajectories_info[asset_row.asset]["su_trajectory"] =
            # read_trajectory(asset_row.start_trajectory)
                [1, 2, 3]
            trajectories_info[asset_row.asset]["sd_trajectory"] =
            # read_trajectory(asset_row.shut_trajectory)
                [6, 5, 4]

            trajectories_info[asset_row.asset]["su_length"] =
                length(trajectories_info[asset_row.asset]["su_trajectory"])
            trajectories_info[asset_row.asset]["sd_length"] =
                length(trajectories_info[asset_row.asset]["sd_trajectory"])
        end

        """
        The idea here is to precompute the term representing the trajectories' contributions in the constraints for each timeblock.
        Since it will be the exact same in both constraints, we can compute it just once, and use it for both.
        """
        trajectories_term = [
            let t_start = row.time_block_start, t_end = row.time_block_end
                p_su_trajectory = trajectories_info[row.asset]["su_trajectory"]
                p_sd_trajectory = trajectories_info[row.asset]["sd_trajectory"]
                su_length = trajectories_info[row.asset]["su_length"]
                sd_length = trajectories_info[row.asset]["sd_length"]

                su_var_ids =
                    _find_relevant_su_var_ids(connection, row.asset, row.year, row.rep_period)
                sd_var_ids =
                    _find_relevant_sd_var_ids(connection, row.asset, row.year, row.rep_period)

                # For every start_up and every shut_down variable, check their contributions and add them to the term
                term = JuMP.AffExpr(0.0)
                for (su_row, sd_row) in zip(su_var_ids, sd_var_ids)
                    su_id    = su_row.start_up_id
                    su_start = su_row.start_up_start
                    sd_id    = sd_row.shut_down_id
                    sd_start = sd_row.shut_down_start

                    # Include contribution for every timestep within a trajectory length from the start of the start_up variable
                    p_up_traj = [
                        if t_start + i <= su_start && su_start <= t_end + i
                            (p_su_trajectory[su_length-i+1]) / (t_end - t_start + 1)
                        else
                            0
                        end for i in 1:su_length
                    ]
                    # Include contribution for every timestep within a trajectory length from the start of the shut_down variable
                    p_down_traj = [
                        if t_start - i <= sd_start && sd_start <= t_end - i
                            (p_sd_trajectory[i+1]) / (t_end - t_start + 1)
                        else
                            0
                        end for i in 0:(sd_length-1)
                    ]

                    JuMP.add_to_expression!(
                        term,
                        1,
                        variables[:start_up].container[su_id] * sum(p_up_traj) +
                        variables[:shut_down].container[sd_id] * sum(p_down_traj),
                    )
                end

                term
            end for row in indices
        ]

        # Attach lower bound constraint
        attach_constraint!(
            model,
            cons,
            :susd_trajectory_lower_bound,
            [
                @constraint(
                    model,
                    flow_total[row.id] >= pmin[row.id] + trajectories_term[row.id],
                    base_name = "susd_trajectory_lower_bound[$(row.asset),$(row.year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]"
                ) for row in indices
            ],
        )

        # Attach upper bound constraint
        attach_constraint!(
            model,
            cons,
            :susd_trajectory_upper_bound,
            [
                @constraint(
                    model,
                    flow_total[row.id] <= pmax[row.id] + trajectories_term[row.id],
                    base_name = "susd_trajectory_upper_bound[$(row.asset),$(row.year),$(row.rep_period),$(row.time_block_start):$(row.time_block_end)]"
                ) for row in indices
            ],
        )
    end
    return nothing
end

function _append_data_to_trajectory(connection)
    return DuckDB.query(
        connection,
        "
        SELECT
            cons.*,
            asset.min_operating_point     AS min_op_point,
            asset.capacity          AS capacity,
            profiles.profile_name   AS profile_name,
        FROM cons_susd_trajectory AS cons
        LEFT JOIN asset AS asset
            ON cons.asset = asset.asset
        LEFT JOIN assets_profiles as profiles
            ON cons.asset = profiles.asset
            AND cons.year = profiles.commission_year
            AND profiles.profile_type = 'availability'
        LEFT JOIN asset_time_resolution_rep_period AS atr
            ON  cons.asset = atr.asset
            AND cons.year = atr.year
            AND cons.rep_period = atr.rep_period
            AND cons.time_block_start >= atr.time_block_start
            AND cons.time_block_end <= atr.time_block_end
        ORDER BY cons.id
        ",
    )
end

function _get_trajectory_info(connection)
    return DuckDB.query(
        connection,
        "
        SELECT
            asset.asset,
            asset.start_trajectory,
            asset.shut_trajectory
        FROM asset AS asset
        WHERE
            asset.type in ('producer', 'conversion')
            AND asset.unit_commitment
            AND asset.unit_commitment_method = '3var-3'
        ",
    )
end

# The reason for the WHERE clause in this function is to prevent creating an extremely large table, which would take up a lot of memory
function _find_relevant_su_var_ids(connection, asset, year, rep_period)
    return DuckDB.query(
        connection,
        "
        SELECT
            cons.id,
            cons.asset,
            cons.year,
            cons.rep_period,
            start_up.id AS start_up_id,
            start_up.time_block_start AS start_up_start,
        FROM cons_susd_trajectory AS cons
        JOIN var_start_up AS start_up
            ON cons.asset = start_up.asset
            AND cons.year = start_up.year
            AND cons.rep_period = start_up.rep_period
            AND cons.time_block_start = start_up.time_block_start
        WHERE
            cons.asset = '$asset'
            AND cons.year = '$year'
            AND cons.rep_period = '$rep_period'
        ORDER BY cons.id
        ",
    )
end
# The reason for the WHERE clause in this function is to prevent creating an extremely large table, which would take up a lot of memory
function _find_relevant_sd_var_ids(connection, asset, year, rep_period)
    return DuckDB.query(
        connection,
        "
        SELECT
            cons.id,
            cons.asset,
            cons.year,
            cons.rep_period,
            shut_down.id AS shut_down_id,
            shut_down.time_block_start AS shut_down_start,
        FROM cons_susd_trajectory AS cons
        JOIN var_shut_down AS shut_down
            ON cons.asset = shut_down.asset
            AND cons.year = shut_down.year
            AND cons.rep_period = shut_down.rep_period
            AND cons.time_block_start = shut_down.time_block_start
        WHERE
            cons.asset = '$asset'
            AND cons.year = '$year'
            AND cons.rep_period = '$rep_period'
        ORDER BY cons.id
        ",
    )
end

function read_trajectory(trajectory::String)#, target::Float64 = 0.0)
    s = split(trajectory, ",")
    # if s[1] == "linear"
    #     len = parse(Int, s[3])
    #     step = target / len
    #     traj = [(i * step + (step / 2)) for i in 0:len][1:len]
    #     if s[2] == "up"
    #         return traj
    #     elseif s[2] == "down"
    #         return reverse!(traj)
    #     end
    # else
    return parse.(Int, split(trajectory, ","))
    # end
end
