-- incoming flows
create
or replace temp table t_merged_in_flows as
select distinct
    to_asset as asset,
    year,
    rep_period,
    time_block_start,
    time_block_end,
from
    resolution.flow_rep_period
;

-- outgoing flows
create
or replace temp table t_merged_out_flows as
select distinct
    from_asset as asset,
    year,
    rep_period,
    time_block_start,
    time_block_end,
from
    resolution.flow_rep_period
;

-- union of all assets and outgoing flows
create
or replace temp table t_merged_assets_and_out_flows as
select distinct
    asset,
    year,
    rep_period,
    time_block_start,
    time_block_end,
from
    resolution.asset_rep_period
union
select
    asset,
    year,
    rep_period,
    time_block_start,
    time_block_end,
from
    t_merged_out_flows
;

-- union of all incoming and outgoing flows
create
or replace temp table t_merged_all_flows as
select
    asset,
    year,
    rep_period,
    time_block_start,
    time_block_end,
from
    t_merged_in_flows
union
select
    asset,
    year,
    rep_period,
    time_block_start,
    time_block_end,
from
    t_merged_out_flows
;

-- union of all assets, and incoming and outgoing flows
create
or replace temp table t_merged_all as
select distinct
    asset,
    year,
    rep_period,
    time_block_start,
    time_block_end,
from
    resolution.asset_rep_period
union
select
    asset,
    year,
    rep_period,
    time_block_start,
    time_block_end,
from
    t_merged_all_flows
;

-- merged table for flows relationships:
-- 1. Define the asset as the combination of the two flows (i.e., CONCAT)
-- 2. Get the resolution of the flows that are in the relationship (i.e., JOIN)
create
or replace temp table t_merged_flows_relationship as
select distinct
    concat(
        fr.flow_1_from_asset,
        '_',
        fr.flow_1_to_asset,
        '_',
        fr.flow_2_from_asset,
        '_',
        fr.flow_2_to_asset
    ) as asset,
    ftrrp.year,
    ftrrp.rep_period,
    ftrrp.time_block_start,
    ftrrp.time_block_end,
from
    resolution.flow_rep_period as ftrrp
    join input.flows_relationships as fr on (
        (
            ftrrp.from_asset = fr.flow_1_from_asset
            and ftrrp.to_asset = fr.flow_1_to_asset
        )
        or (
            ftrrp.from_asset = fr.flow_2_from_asset
            and ftrrp.to_asset = fr.flow_2_to_asset
        )
    )
    and ftrrp.year = fr.milestone_year
;
