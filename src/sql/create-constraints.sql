create schema if not exists constraints
;

create sequence id start 1
;

create table constraints.balance_conversion as
select
    nextval('id') as id,
    asset.asset,
    t_low.year,
    t_low.rep_period,
    t_low.time_block_start,
    t_low.time_block_end,
from
    t_lowest_all_flows as t_low
    left join input.asset as asset on t_low.asset = asset.asset
where
    asset.type in ('conversion')
order by
    asset.asset,
    t_low.year,
    t_low.rep_period,
    t_low.time_block_start
;

drop sequence id
;

create sequence id start 1
;

create table constraints.balance_consumer as
select
    nextval('id') as id,
    t_high.*
from
    t_highest_all_flows as t_high
    left join input.asset as asset on t_high.asset = asset.asset
where
    asset.type = 'consumer'
;

drop sequence id
;

create sequence id start 1
;

create table constraints.balance_hub as
select
    nextval('id') as id,
    t_high.*
from
    t_highest_all_flows as t_high
    left join input.asset as asset on t_high.asset = asset.asset
where
    asset.type = 'hub'
;

drop sequence id
;

create sequence id start 1
;

create table constraints.capacity_incoming_simple_method as
select
    nextval('id') as id,
    t_high.*
from
    t_highest_in_flows as t_high
    left join input.asset as asset on t_high.asset = asset.asset
where
    asset.type in ('storage')
;

drop sequence id
;

create sequence id start 1
;

create table constraints.capacity_incoming_simple_method_non_investable_storage_with_binary as
select
    nextval('id') as id,
    t_high.*
from
    t_highest_in_flows as t_high
    left join input.asset as asset on t_high.asset = asset.asset
    left join input.asset_milestone as asset_milestone on t_high.asset = asset_milestone.asset
    and t_high.year = asset_milestone.milestone_year
where
    asset.type in ('storage')
    and asset.use_binary_storage_method in ('binary', 'relaxed_binary')
    and not asset_milestone.investable
;

drop sequence id
;

create sequence id start 1
;

create table constraints.capacity_incoming_simple_method_investable_storage_with_binary as
select
    nextval('id') as id,
    t_high.*
from
    t_highest_in_flows as t_high
    left join input.asset as asset on t_high.asset = asset.asset
    left join input.asset_milestone as asset_milestone on t_high.asset = asset_milestone.asset
    and t_high.year = asset_milestone.milestone_year
where
    asset.type in ('storage')
    and asset.use_binary_storage_method in ('binary', 'relaxed_binary')
    and asset_milestone.investable
;

drop sequence id
;

create sequence id start 1
;

create table constraints.capacity_outgoing_compact_method as
select
    nextval('id') as id,
    t_high.*
from
    t_highest_out_flows as t_high
    left join input.asset as asset on t_high.asset = asset.asset
where
    asset.type in ('producer', 'storage', 'conversion')
    and asset.investment_method = 'compact'
;

drop sequence id
;

create sequence id start 1
;

create table constraints.capacity_outgoing_simple_method as
select
    nextval('id') as id,
    t_high.*
from
    t_highest_out_flows as t_high
    left join input.asset as asset on t_high.asset = asset.asset
where
    asset.type in ('producer', 'storage', 'conversion')
    and asset.investment_method in ('simple', 'none')
;

drop sequence id
;

create sequence id start 1
;

create table constraints.capacity_outgoing_simple_method_non_investable_storage_with_binary as
select
    nextval('id') as id,
    t_high.*
from
    t_highest_out_flows as t_high
    left join input.asset as asset on t_high.asset = asset.asset
    left join input.asset_milestone as asset_milestone on t_high.asset = asset_milestone.asset
    and t_high.year = asset_milestone.milestone_year
where
    asset.type in ('storage')
    and asset.use_binary_storage_method in ('binary', 'relaxed_binary')
    and not asset_milestone.investable
;

drop sequence id
;

create sequence id start 1
;

create table constraints.capacity_outgoing_simple_method_investable_storage_with_binary as
select
    nextval('id') as id,
    t_high.*
from
    t_highest_out_flows as t_high
    left join input.asset as asset on t_high.asset = asset.asset
    left join input.asset_milestone as asset_milestone on t_high.asset = asset_milestone.asset
    and t_high.year = asset_milestone.milestone_year
where
    asset.type in ('storage')
    and asset.use_binary_storage_method in ('binary', 'relaxed_binary')
    and asset_milestone.investable
;

drop sequence id
;

create sequence id start 1
;

create table constraints.min_outgoing_flow_for_transport_flows_without_unit_commitment as
-- We want to check if the outgoing flows of an asset have transport flows
-- This information is gathered from the flow table
-- COALESCE is used to handle the case where there are no outgoing flows
with
    transport_flow_info as (
        select
            asset.asset,
            coalesce(
                (
                    select
                        bool_or(flow.is_transport)
                    from
                        input.flow as flow
                    where
                        flow.from_asset = asset.asset
                ),
                false
            ) as outgoing_flows_have_transport_flows,
        from
            input.asset as asset
    )
select
    nextval('id') as id,
    t_high.*
from
    t_highest_out_flows as t_high
    left join input.asset as asset on t_high.asset = asset.asset
    left join transport_flow_info on t_high.asset = transport_flow_info.asset
where
    asset.type in ('producer', 'storage', 'conversion')
    and transport_flow_info.outgoing_flows_have_transport_flows
    -- Assets with unit commitment already have a minimum outgoing flow constraints
    and not asset.unit_commitment
;

drop sequence id
;

create sequence id start 1
;

create table constraints.min_incoming_flow_for_transport_flows as
-- Similar to the previous query, but for incoming flows
-- Also for assets with unit commitment
with
    transport_flow_info as (
        select
            asset.asset,
            coalesce(
                (
                    select
                        bool_or(flow.is_transport)
                    from
                        input.flow as flow
                    where
                        flow.to_asset = asset.asset
                ),
                false
            ) as incoming_flows_have_transport_flows,
        from
            input.asset as asset
    )
select
    nextval('id') as id,
    t_high.*
from
    t_highest_out_flows as t_high
    left join input.asset as asset on t_high.asset = asset.asset
    left join transport_flow_info on t_high.asset = transport_flow_info.asset
where
    asset.type in ('storage', 'conversion')
    and transport_flow_info.incoming_flows_have_transport_flows
;

drop sequence id
;

create table constraints.limit_units_on_compact_method as
select
    *
from
    variables.units_on
    left join input.asset as asset on variables.units_on.asset = asset.asset
where
    asset.investment_method = 'compact'
;

create table constraints.limit_units_on_simple_method as
select
    *
from
    variables.units_on
    left join input.asset as asset on variables.units_on.asset = asset.asset
where
    asset.investment_method in ('simple', 'none')
;

create sequence id start 1
;

create table constraints.min_output_flow_with_unit_commitment as
select
    nextval('id') as id,
    t_high.*
from
    t_highest_assets_and_out_flows as t_high
    left join input.asset as asset on t_high.asset = asset.asset
where
    asset.type in ('producer', 'conversion')
    and asset.unit_commitment
;

drop sequence id
;

create sequence id start 1
;

create table constraints.max_output_flow_with_basic_unit_commitment as
select
    nextval('id') as id,
    t_high.*
from
    t_highest_assets_and_out_flows as t_high
    left join input.asset as asset on t_high.asset = asset.asset
where
    asset.type in ('producer', 'conversion')
    and asset.unit_commitment
    and asset.unit_commitment_method = 'basic'
;

drop sequence id
;

create sequence id start 1
;

create table constraints.max_ramp_with_unit_commitment as
select
    nextval('id') as id,
    t_high.*
from
    t_highest_assets_and_out_flows as t_high
    left join input.asset as asset on t_high.asset = asset.asset
where
    asset.type in ('producer', 'conversion')
    and asset.ramping
    and asset.unit_commitment
    and asset.unit_commitment_method = 'basic'
;

drop sequence id
;

create sequence id start 1
;

create table constraints.max_ramp_without_unit_commitment as
select
    nextval('id') as id,
    t_high.*
from
    t_highest_out_flows as t_high
    left join input.asset as asset on t_high.asset = asset.asset
where
    asset.type in ('producer', 'storage', 'conversion')
    and asset.ramping
    and not asset.unit_commitment
    and asset.unit_commitment_method != 'basic'
;

create table constraints.balance_storage_rep_period as
select
    *
from
    variables.storage_level_rep_period
;

create table constraints.balance_storage_over_clustered_year as
select
    *
from
    variables.storage_level_over_clustered_year
;

drop sequence id
;

create sequence id start 1
;

create table constraints.min_energy_over_clustered_year as
select
    nextval('id') as id,
    attr.asset,
    attr.year,
    attr.period_block_start,
    attr.period_block_end,
from
    resolution.asset_over_clustered_year as attr
    left join input.asset_milestone as asset_milestone on attr.asset = asset_milestone.asset
    and attr.year = asset_milestone.milestone_year
where
    asset_milestone.min_energy_timeframe_partition is not null
;

drop sequence id
;

create sequence id start 1
;

create table constraints.max_energy_over_clustered_year as
select
    nextval('id') as id,
    attr.asset,
    attr.year,
    attr.period_block_start,
    attr.period_block_end,
from
    resolution.asset_over_clustered_year as attr
    left join input.asset_milestone as asset_milestone on attr.asset = asset_milestone.asset
    and attr.year = asset_milestone.milestone_year
where
    asset_milestone.max_energy_timeframe_partition is not null
;

drop sequence id
;

create sequence id start 1
;

create table constraints.transport_flow_limit_simple_method as
select
    nextval('id') as id,
    variables.flow.from_asset,
    variables.flow.to_asset,
    variables.flow.year,
    variables.flow.rep_period,
    variables.flow.time_block_start,
    variables.flow.time_block_end,
    variables.flow.id as var_flow_id
from
    variables.flow
    left join input.flow on input.flow.from_asset = variables.flow.from_asset
    and input.flow.to_asset = variables.flow.to_asset
where
    flow.is_transport
;

drop sequence id
;

create sequence id start 1
;

create table constraints.group_max_investment_limit as
select
    nextval('id') as id,
    ga.name,
    ga.milestone_year,
    ga.max_investment_limit,
from
    input.group_asset as ga
where
    ga.invest_method
    and ga.max_investment_limit is not null
;

drop sequence id
;

create sequence id start 1
;

create table constraints.group_min_investment_limit as
select
    nextval('id') as id,
    ga.name,
    ga.milestone_year,
    ga.min_investment_limit,
from
    input.group_asset as ga
where
    ga.invest_method
    and ga.min_investment_limit is not null
;

drop sequence id
;
