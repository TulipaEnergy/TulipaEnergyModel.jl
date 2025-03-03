create sequence id start 1
;

create table var_flow as
select
    nextval('id') as id,
    from_asset,
    to_asset,
    year,
    rep_period,
    efficiency,
    time_block_start,
    time_block_end,
from
    flow_time_resolution_rep_period
;

drop sequence id
;

create sequence id start 1
;

create table var_units_on as
select
    nextval('id') as id,
    atr.asset,
    atr.year,
    atr.rep_period,
    atr.time_block_start,
    atr.time_block_end,
    asset.unit_commitment_integer,
from
    asset_time_resolution_rep_period as atr
    left join asset on asset.asset = atr.asset
where
    asset.type in ('producer', 'conversion')
    and asset.unit_commitment = true
;

drop sequence id
;

create sequence id start 1
;

create table var_is_charging as
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
    left join asset on t_low.asset = asset.asset
where
    asset.type = 'storage'
    and asset.use_binary_storage_method in ('binary', 'relaxed_binary')
;

drop sequence id
;

create sequence id start 1
;

create table var_storage_level_rep_period as
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
            left join asset on t_low.asset = asset.asset
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

create table var_storage_level_over_clustered_year as
with
    filtered_assets as (
        select
            attr.asset,
            attr.year,
            attr.period_block_start,
            attr.period_block_end,
        from
            asset_time_resolution_over_clustered_year as attr
            left join asset on attr.asset = asset.asset
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

create table var_flows_investment as
select
    nextval('id') as id,
    flow.from_asset,
    flow.to_asset,
    flow_milestone.milestone_year,
    flow.investment_integer,
    flow.capacity,
    flow_commission.investment_limit,
from
    flow_milestone
    left join flow on flow.from_asset = flow_milestone.from_asset
    and flow.to_asset = flow_milestone.to_asset
    left join flow_commission on flow_commission.from_asset = flow_milestone.from_asset
    and flow_commission.to_asset = flow_milestone.to_asset
    and flow_commission.commission_year = flow_milestone.milestone_year
where
    flow_milestone.investable = true
;

drop sequence id
;

create sequence id start 1
;

create table var_assets_investment as
select
    nextval('id') as id,
    asset.asset,
    asset_milestone.milestone_year,
    asset.investment_integer,
    asset.capacity,
    asset_commission.investment_limit,
from
    asset_milestone
    left join asset on asset.asset = asset_milestone.asset
    left join asset_commission on asset_commission.asset = asset_milestone.asset
    and asset_commission.commission_year = asset_milestone.milestone_year
where
    asset_milestone.investable = true
;

drop sequence id
;

create sequence id start 1
;

create table var_assets_decommission as
select
    nextval('id') as id,
    asset_both.asset,
    asset_both.milestone_year,
    asset_both.commission_year,
    asset_both.decommissionable,
    asset_both.initial_units,
    asset.investment_integer,
from
    asset_both
    left join asset on asset.asset = asset_both.asset
where
    asset_both.decommissionable
    and asset_both.milestone_year != asset_both.commission_year
;

drop sequence id
;

create sequence id start 1
;

create table var_flows_decommission as
select
    nextval('id') as id,
    flow.from_asset,
    flow.to_asset,
    flow_both.milestone_year,
    flow_both.commission_year,
    flow.investment_integer,
from
    flow_both
    left join flow on flow.from_asset = flow_both.from_asset
    and flow.to_asset = flow_both.to_asset
where
    flow.is_transport = true
    and flow_both.decommissionable
    and flow_both.commission_year != flow_both.milestone_year
;

drop sequence id
;

create sequence id start 1
;

create table var_assets_investment_energy as
select
    nextval('id') as id,
    asset.asset,
    asset_milestone.milestone_year,
    asset.investment_integer_storage_energy,
    asset.capacity_storage_energy,
    asset_commission.investment_limit_storage_energy,
from
    asset_milestone
    left join asset on asset.asset = asset_milestone.asset
    left join asset_commission on asset_commission.asset = asset_milestone.asset
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

create table var_assets_decommission_energy as
select
    nextval('id') as id,
    asset.asset,
    asset_both.milestone_year,
    asset_both.commission_year,
    asset.investment_integer_storage_energy,
from
    asset_both
    left join asset on asset.asset = asset_both.asset
where
    asset.storage_method_energy = true
    and asset.type = 'storage'
    and asset_both.decommissionable
    and asset_both.commission_year != asset_both.milestone_year
;

drop sequence id
;
