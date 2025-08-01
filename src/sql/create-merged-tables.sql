-- incoming flows
create or replace temp table merged_in_flows as
select
    distinct to_asset as asset,
    year,
    rep_period,
    time_block_start,
    time_block_end
from
    flow_time_resolution_rep_period
;

-- incoming flows for conversion balance
create or replace temp table merged_in_flows_conversion_balance as
select
    distinct ftrrp.to_asset as asset,
    ftrrp.year,
    ftrrp.rep_period,
    ftrrp.time_block_start,
    ftrrp.time_block_end
from
    flow_time_resolution_rep_period as ftrrp
left join
    flow_commission as fc on
        ftrrp.from_asset = fc.from_asset and
        ftrrp.to_asset = fc.to_asset and
        ftrrp.year = fc.commission_year
left join
    asset on ftrrp.to_asset = asset.asset
where
    fc.conversion_coefficient > 0 and
    asset.type in ('conversion')
;

-- outgoing flows
create or replace temp table merged_out_flows as
select
    distinct from_asset as asset,
    year,
    rep_period,
    time_block_start,
    time_block_end
from
    flow_time_resolution_rep_period
;

-- outgoing flows for conversion balance
create or replace temp table merged_out_flows_conversion_balance as
select
    distinct ftrrp.from_asset as asset,
    ftrrp.year,
    ftrrp.rep_period,
    ftrrp.time_block_start,
    ftrrp.time_block_end
from
    flow_time_resolution_rep_period as ftrrp
left join
    flow_commission as fc on
        ftrrp.from_asset = fc.from_asset and
        ftrrp.to_asset = fc.to_asset and
        ftrrp.year = fc.commission_year
left join
    asset on ftrrp.from_asset = asset.asset
where
    fc.conversion_coefficient > 0 and
    asset.type in ('conversion')
;

-- union of all assets and outgoing flows
create or replace temp table merged_assets_and_out_flows as
select
    distinct asset,
    year,
    rep_period,
    time_block_start,
    time_block_end
from
    asset_time_resolution_rep_period
union
from
    merged_out_flows
;

-- union of all incoming and outgoing flows
create or replace temp table merged_all_flows as
from
    merged_in_flows
union
from
    merged_out_flows
;

-- union of all incoming and outgoing flows for conversion balance
create or replace temp table merged_flows_conversion_balance as
from
    merged_in_flows_conversion_balance
union
from
    merged_out_flows_conversion_balance
;

-- union of all assets, and incoming and outgoing flows
create or replace temp table merged_all as
select
    distinct asset,
    year,
    rep_period,
    time_block_start,
    time_block_end
from
    asset_time_resolution_rep_period
union
from
    merged_all_flows
;

-- merged table for flows relationships:
-- 1. Define the asset as the combination of the two flows (i.e., CONCAT)
-- 2. Get the resolution of the flows that are in the relationship (i.e., JOIN)
create or replace temp table merged_flows_relationship as
    select distinct
        CONCAT(fr.flow_1_from_asset, '_',
               fr.flow_1_to_asset, '_',
               fr.flow_2_from_asset, '_',
               fr.flow_2_to_asset) as asset,
        ftrrp.year,
        ftrrp.rep_period,
        ftrrp.time_block_start,
        ftrrp.time_block_end,
    from
        flow_time_resolution_rep_period as ftrrp
        join flows_relationships as fr on (
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

-- merged table for flows and connecting assets:
-- 1. Define the asset as the flow
-- 2. Get the resolution of the flow and the connecting asset (i.e., UNION)

create or replace temp table merged_flows_and_connecting_assets as
select distinct
    CONCAT(ftrrp.from_asset, '_', ftrrp.to_asset) as asset,
    ftrrp.year,
    ftrrp.rep_period,
    ftrrp.time_block_start,
    ftrrp.time_block_end
from
    flow_time_resolution_rep_period as ftrrp
-- we only want the flows with dc_opf method
left join flow_milestone as fm
    on fm.from_asset = ftrrp.from_asset
     and fm.to_asset = ftrrp.to_asset
     and fm.milestone_year = ftrrp.year
where fm.dc_opf

union

select distinct
    CONCAT(fm.from_asset, '_', fm.to_asset) as asset,
    atrrp.year,
    atrrp.rep_period,
    atrrp.time_block_start,
    atrrp.time_block_end
from
    asset_time_resolution_rep_period as atrrp
join
    flow_milestone as fm
    on (
        atrrp.asset = fm.from_asset
        or atrrp.asset = fm.to_asset
    )
      and fm.milestone_year = atrrp.year
where fm.dc_opf
;
