create schema if not exists variables
;

create sequence id start 1
;

create table variables.flow as
select
    nextval('id') as id,
    from_asset,
    to_asset,
    year,
    rep_period,
    efficiency,
    flow_coefficient_in_capacity_constraint,
    time_block_start,
    time_block_end,
from
    resolution.flow_rep_period
;

drop sequence id
;

create sequence id start 1
;

create table variables.units_on as
select
    nextval('id') as id,
    atr.asset,
    atr.year,
    atr.rep_period,
    atr.time_block_start,
    atr.time_block_end,
    asset.unit_commitment_integer,
from
    resolution.asset_rep_period as atr
    left join input.asset as asset on asset.asset = atr.asset
where
    asset.type in ('producer', 'conversion')
    and asset.unit_commitment = true
;

drop sequence id
;

create sequence id start 1
;

create table variables.electricity_angle as
select
    nextval('id') as id,
    atr.asset,
    atr.year,
    atr.rep_period,
    atr.time_block_start,
    any_value (atr.time_block_end) as time_block_end,
    -- The angle resolution is the same as the time resolution of the asset
from
    resolution.asset_rep_period as atr
    -- We need to check if the asset has any connecting flows that are transport
    -- We only get the assets that have outgoing flows OR incoming flows
    -- With the condition that the flows are transport
    left join input.flow as flow on flow.from_asset = atr.asset
    or flow.to_asset = atr.asset
    -- After that we need to also check if the flows have dc_opf method
    -- This is by joining the flow_milestone table
    -- Here we use AND because we need to match flow_milestone with flow
    left join input.flow_milestone as flow_milestone on flow_milestone.from_asset = flow.from_asset
    and flow_milestone.to_asset = flow.to_asset
    and flow_milestone.milestone_year = atr.year
where
    flow.is_transport
    and flow_milestone.dc_opf
    -- We may end up with duplicates because an asset can have both incoming and outgoing
    -- flows
    -- Or it can have multiple flows
    -- GROUP BY is used to remove duplicates
    -- Note SELECT only happens after the GROUP BY, so id is unique for each row.
group by
    atr.asset,
    atr.year,
    atr.rep_period,
    atr.time_block_start
;

drop sequence id
;

create sequence id start 1
;

create table variables.is_charging as
select
    nextval('id') as id,
    t_low.asset,
    t_low.year,
    t_low.rep_period,
    t_low.time_block_start,
    t_low.time_block_end,
    asset.use_binary_storage_method
from
    t_lowest_all_flows as t_low
    left join input.asset as asset on t_low.asset = asset.asset
where
    asset.type = 'storage'
    and asset.use_binary_storage_method in ('binary', 'relaxed_binary')
;

drop sequence id
;

create sequence id start 1
;

create table variables.storage_level_rep_period as
with
    filtered_assets as (
        select
            t_low.asset,
            t_low.year,
            t_low.rep_period,
            t_low.time_block_start,
            t_low.time_block_end,
        from
            t_lowest_all as t_low
            left join input.asset as asset on t_low.asset = asset.asset
        where
            asset.type = 'storage'
            and asset.is_seasonal = false
        order by
            t_low.asset,
            t_low.year,
            t_low.rep_period,
            t_low.time_block_start
    )
select
    nextval('id') as id,
    filtered_assets.*
from
    filtered_assets
;

drop sequence id
;

create sequence id start 1
;

create table variables.storage_level_over_clustered_year as
with
    filtered_assets as (
        select
            attr.asset,
            attr.year,
            attr.period_block_start,
            attr.period_block_end,
        from
            resolution.asset_over_clustered_year as attr
            left join input.asset as asset on attr.asset = asset.asset
        where
            asset.type = 'storage'
            and asset.is_seasonal = true
        order by
            attr.asset,
            attr.year,
            attr.period_block_start
    )
select
    nextval('id') as id,
    filtered_assets.*
from
    filtered_assets
;

drop sequence id
;

create sequence id start 1
;

create table variables.flows_investment as
select
    nextval('id') as id,
    flow.from_asset,
    flow.to_asset,
    flow_milestone.milestone_year,
    flow.investment_integer,
    flow.capacity,
    flow_commission.investment_limit,
from
    input.flow_milestone as flow_milestone
    left join input.flow as flow on flow.from_asset = flow_milestone.from_asset
    and flow.to_asset = flow_milestone.to_asset
    left join input.flow_commission as flow_commission on flow_commission.from_asset = flow_milestone.from_asset
    and flow_commission.to_asset = flow_milestone.to_asset
    and flow_commission.commission_year = flow_milestone.milestone_year
where
    flow_milestone.investable = true
;

drop sequence id
;

create sequence id start 1
;

create table variables.assets_investment as
select
    nextval('id') as id,
    asset.asset,
    asset_milestone.milestone_year,
    asset.investment_integer,
    asset.capacity,
    asset_commission.investment_limit,
from
    input.asset_milestone as asset_milestone
    left join input.asset as asset on asset.asset = asset_milestone.asset
    left join input.asset_commission as asset_commission on asset_commission.asset = asset_milestone.asset
    and asset_commission.commission_year = asset_milestone.milestone_year
where
    asset_milestone.investable = true
;

drop sequence id
;

create sequence id start 1
;

create table variables.assets_decommission as
select
    nextval('id') as id,
    asset_both.asset,
    asset_both.milestone_year,
    asset_both.commission_year,
    asset_both.decommissionable,
    asset_both.initial_units,
    asset.investment_integer,
from
    input.asset_both as asset_both
    left join input.asset as asset on asset.asset = asset_both.asset
where
    asset_both.decommissionable
;

drop sequence id
;

create sequence id start 1
;

create table variables.flows_decommission as
select
    nextval('id') as id,
    flow.from_asset,
    flow.to_asset,
    flow_both.milestone_year,
    flow_both.commission_year,
    flow.investment_integer,
from
    input.flow_both as flow_both
    left join input.flow as flow on flow.from_asset = flow_both.from_asset
    and flow.to_asset = flow_both.to_asset
where
    flow.is_transport = true
    and flow_both.decommissionable
;

drop sequence id
;

create sequence id start 1
;

create table variables.assets_investment_energy as
select
    nextval('id') as id,
    asset.asset,
    asset_milestone.milestone_year,
    asset.investment_integer_storage_energy,
    asset.capacity_storage_energy,
    asset_commission.investment_limit_storage_energy,
from
    input.asset_milestone as asset_milestone
    left join input.asset as asset on asset.asset = asset_milestone.asset
    left join input.asset_commission as asset_commission on asset_commission.asset = asset_milestone.asset
    and asset_commission.commission_year = asset_milestone.milestone_year
where
    asset.storage_method_energy = true
    and asset_milestone.investable = true
    and asset.type = 'storage'
;

drop sequence id
;

create sequence id start 1
;

create table variables.assets_decommission_energy as
select
    nextval('id') as id,
    asset.asset,
    asset_both.milestone_year,
    asset_both.commission_year,
    asset.investment_integer_storage_energy,
from
    input.asset_both as asset_both
    left join input.asset as asset on asset.asset = asset_both.asset
where
    asset.storage_method_energy = true
    and asset.type = 'storage'
    and asset_both.decommissionable
;

drop sequence id
;
