drop sequence if exists id
;

create sequence id start 1
;

drop table if exists var_flow
;

create table var_flow as
select
    nextval('id') as id,
    from_asset,
    to_asset,
    year,
    rep_period,
    capacity_coefficient,
    conversion_coefficient,
    time_block_start,
    time_block_end,
    cast(null as float8) as solution,
from
    flow_time_resolution_rep_period
;

drop sequence id
;

create sequence id start 1
;

drop table if exists var_vintage_flow
;

create table var_vintage_flow as
select
    nextval('id') as id,
    ft.from_asset,
    ft.to_asset,
    ab.milestone_year,
    ab.commission_year,
    ft.rep_period,
    ft.time_block_start,
    ft.time_block_end,
    fc.capacity_coefficient,
    fc.conversion_coefficient,
    cast(null as float8) as solution,
from
    flow_time_resolution_rep_period as ft
    -- We want to split the outgoing flows by the asset's vintage
    left join asset_both as ab on ab.asset = ft.from_asset
    and ab.milestone_year = ft.year
    left join asset on asset.asset = ab.asset
    left join flow_commission as fc on fc.from_asset = ft.from_asset
    and fc.to_asset = ft.to_asset
    and fc.commission_year = ab.commission_year
where
    asset.type in ('producer', 'conversion', 'storage')
    and asset.investment_method = 'semi-compact'
;

drop sequence id
;

create sequence id start 1
;

drop table if exists var_units_on
;

create table var_units_on as
select
    nextval('id') as id,
    sub.*,
    cast(null as float8) as solution,
from
    (
        select
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
        order by
            atr.asset,
            atr.year,
            atr.rep_period,
            atr.time_block_start
    ) as sub
;

drop sequence id
;

create sequence id start 1
;

drop table if exists var_start_up
;

create table var_start_up as
select
    nextval('id') as id,
    sub.*,
    cast(null as float8) as solution,
from
    (
        select
            atr.asset,
            atr.year,
            atr.rep_period,
            t_high.time_block_start,
            t_high.time_block_end,
            asset.unit_commitment_integer
        from
            t_highest_assets_and_out_flows as t_high
            inner join asset_time_resolution_rep_period as atr on t_high.asset = atr.asset
            and t_high.year = atr.year
            and t_high.rep_period = atr.rep_period
            and t_high.time_block_start = atr.time_block_start
            left join asset on asset.asset = atr.asset
        where
            asset.type in ('producer', 'conversion')
            and asset.unit_commitment = true
            and asset.unit_commitment_method like '3var%'
        order by
            atr.asset,
            atr.year,
            atr.rep_period,
            atr.time_block_start
    ) as sub
;

drop sequence id
;

create sequence id start 1
;

drop table if exists var_shut_down
;

create table var_shut_down as
select
    nextval('id') as id,
    sub.*,
    cast(null as float8) as solution,
from
    (
        select
            atr.asset,
            atr.year,
            atr.rep_period,
            t_high.time_block_start,
            t_high.time_block_end,
            asset.unit_commitment_integer,
        from
            t_highest_assets_and_out_flows as t_high
            inner join asset_time_resolution_rep_period as atr on t_high.asset = atr.asset
            and t_high.year = atr.year
            and t_high.rep_period = atr.rep_period
            and t_high.time_block_start = atr.time_block_start
            left join asset on asset.asset = atr.asset
        where
            asset.type in ('producer', 'conversion')
            and asset.unit_commitment = true
            and asset.unit_commitment_method like '3var%'
        order by
            atr.asset,
            atr.year,
            atr.rep_period,
            atr.time_block_start
    ) as sub
;

drop sequence id
;

create sequence id start 1
;

drop table if exists var_electricity_angle
;

create table var_electricity_angle as
select
    nextval('id') as id,
    atr.asset,
    atr.year,
    atr.rep_period,
    atr.time_block_start,
    any_value (atr.time_block_end) as time_block_end,
    cast(null as float8) as solution,
from
    -- The angle resolution is the same as the time resolution of the asset
    asset_time_resolution_rep_period as atr
    -- We need to check if the asset has any connecting flows that are transport
    -- We only get the assets that have outgoing flows OR incoming flows
    -- With the condition that the flows are transport
    left join flow on flow.from_asset = atr.asset
    or flow.to_asset = atr.asset
    -- After that we need to also check if the flows have dc_opf method
    -- This is by joining the flow_milestone table
    -- Here we use AND because we need to match flow_milestone with flow
    left join flow_milestone on flow_milestone.from_asset = flow.from_asset
    and flow_milestone.to_asset = flow.to_asset
    and flow_milestone.milestone_year = atr.year
where
    flow.is_transport
    and flow_milestone.dc_opf
    -- We may end up with duplicates because an asset can have both incoming and outgoing flows
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

drop table if exists var_is_charging
;

create table var_is_charging as
select
    nextval('id') as id,
    t_low.asset,
    t_low.year,
    t_low.rep_period,
    t_low.time_block_start,
    t_low.time_block_end,
    asset.use_binary_storage_method,
    cast(null as float8) as solution,
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

drop table if exists var_storage_level_rep_period
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
    filtered_assets.*,
    cast(null as float8) as solution,
from
    filtered_assets
;

drop sequence id
;

create sequence id start 1
;

drop table if exists var_storage_level_over_clustered_year
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
    filtered_assets.*,
    cast(null as float8) as solution,
from
    filtered_assets
;

drop sequence id
;

create sequence id start 1
;

drop table if exists var_flows_investment
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
    cast(null as float8) as solution,
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

drop table if exists var_assets_investment
;

create table var_assets_investment as
select
    nextval('id') as id,
    asset.asset,
    asset_milestone.milestone_year,
    asset.investment_integer,
    asset.capacity,
    asset_commission.investment_limit,
    cast(null as float8) as solution,
from
    asset_milestone
    left join asset on asset.asset = asset_milestone.asset
    left join asset_commission on asset_commission.asset = asset_milestone.asset
    and asset_commission.commission_year = asset_milestone.milestone_year
where
    asset_milestone.investable = true
    and asset.investment_method in ('simple', 'semi-compact', 'compact')
;

drop sequence id
;

create sequence id start 1
;

drop table if exists var_assets_decommission
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
    cast(null as float8) as solution,
from
    asset_both
    left join asset on asset.asset = asset_both.asset
where
    asset_both.decommissionable
    and asset.investment_method in ('simple', 'semi-compact', 'compact')
;

drop sequence id
;

create sequence id start 1
;

drop table if exists var_flows_decommission
;

create table var_flows_decommission as
select
    nextval('id') as id,
    flow.from_asset,
    flow.to_asset,
    flow_both.milestone_year,
    flow_both.commission_year,
    flow.investment_integer,
    cast(null as float8) as solution,
from
    flow_both
    left join flow on flow.from_asset = flow_both.from_asset
    and flow.to_asset = flow_both.to_asset
where
    flow.is_transport = true
    and flow_both.decommissionable
;

drop sequence id
;

create sequence id start 1
;

drop table if exists var_assets_investment_energy
;

create table var_assets_investment_energy as
select
    nextval('id') as id,
    asset.asset,
    asset_milestone.milestone_year,
    asset.investment_integer_storage_energy,
    asset.capacity_storage_energy,
    asset_commission.investment_limit_storage_energy,
    cast(null as float8) as solution,
from
    asset_milestone
    left join asset on asset.asset = asset_milestone.asset
    left join asset_commission on asset_commission.asset = asset_milestone.asset
    and asset_commission.commission_year = asset_milestone.milestone_year
where
    asset.storage_method_energy = true
    and asset_milestone.investable = true
    and asset.type = 'storage'
    and asset.investment_method = 'simple'
;

drop sequence id
;

create sequence id start 1
;

drop table if exists var_assets_decommission_energy
;

create table var_assets_decommission_energy as
select
    nextval('id') as id,
    asset.asset,
    asset_both.milestone_year,
    asset_both.commission_year,
    asset.investment_integer_storage_energy,
    cast(null as float8) as solution,
from
    asset_both
    left join asset on asset.asset = asset_both.asset
where
    asset.storage_method_energy = true
    and asset.type = 'storage'
    and asset_both.decommissionable
    and asset.investment_method = 'simple'
;

drop sequence id
;
