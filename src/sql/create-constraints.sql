create sequence id start 1
;

create table cons_balance_conversion as
select
    nextval('id') as id,
    asset.asset,
    t_low.year,
    t_low.rep_period,
    t_low.time_block_start,
    t_low.time_block_end,
from
    t_lowest_all_flows as t_low
    left join asset on t_low.asset = asset.asset
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

create table cons_balance_consumer as
select
    nextval('id') as id,
    t_high.*
from
    t_highest_all_flows as t_high
    left join asset on t_high.asset = asset.asset
where
    asset.type = 'consumer'
;

drop sequence id
;

create sequence id start 1
;

create table cons_balance_hub as
select
    nextval('id') as id,
    t_high.*
from
    t_highest_all_flows as t_high
    left join asset on t_high.asset = asset.asset
where
    asset.type = 'hub'
;

drop sequence id
;

create sequence id start 1
;

create table cons_capacity_incoming as
select
    nextval('id') as id,
    t_high.*
from
    t_highest_in_flows as t_high
    left join asset on t_high.asset = asset.asset
where
    asset.type in ('storage')
;

drop sequence id
;

create sequence id start 1
;

create table cons_capacity_incoming_non_investable_storage_with_binary as
select
    nextval('id') as id,
    t_high.*
from
    t_highest_in_flows as t_high
    left join asset on t_high.asset = asset.asset
    left join asset_milestone on t_high.asset = asset_milestone.asset
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

create table cons_capacity_incoming_investable_storage_with_binary as
select
    nextval('id') as id,
    t_high.*
from
    t_highest_in_flows as t_high
    left join asset on t_high.asset = asset.asset
    left join asset_milestone on t_high.asset = asset_milestone.asset
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

create table cons_capacity_outgoing as
select
    nextval('id') as id,
    t_high.*
from
    t_highest_out_flows as t_high
    left join asset on t_high.asset = asset.asset
where
    asset.type in ('producer', 'storage', 'conversion')
;

drop sequence id
;

create sequence id start 1
;

create table cons_capacity_outgoing_non_investable_storage_with_binary as
select
    nextval('id') as id,
    t_high.*
from
    t_highest_out_flows as t_high
    left join asset on t_high.asset = asset.asset
    left join asset_milestone on t_high.asset = asset_milestone.asset
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

create table cons_capacity_outgoing_investable_storage_with_binary as
select
    nextval('id') as id,
    t_high.*
from
    t_highest_out_flows as t_high
    left join asset on t_high.asset = asset.asset
    left join asset_milestone on t_high.asset = asset_milestone.asset
    and t_high.year = asset_milestone.milestone_year
where
    asset.type in ('storage')
    and asset.use_binary_storage_method in ('binary', 'relaxed_binary')
    and asset_milestone.investable
;

create table cons_limit_units_on as
select
    *
from
    var_units_on
;

drop sequence id
;

create sequence id start 1
;

create table cons_min_output_flow_with_unit_commitment as
select
    nextval('id') as id,
    t_high.*
from
    t_highest_assets_and_out_flows as t_high
    left join asset on t_high.asset = asset.asset
where
    asset.type in ('producer', 'conversion')
    and asset.unit_commitment
;

drop sequence id
;

create sequence id start 1
;

create table cons_max_output_flow_with_basic_unit_commitment as
select
    nextval('id') as id,
    t_high.*
from
    t_highest_assets_and_out_flows as t_high
    left join asset on t_high.asset = asset.asset
where
    asset.type in ('producer', 'conversion')
    and asset.unit_commitment
    and asset.unit_commitment_method = 'basic'
;

drop sequence id
;

create sequence id start 1
;

create table cons_max_ramp_with_unit_commitment as
select
    nextval('id') as id,
    t_high.*
from
    t_highest_assets_and_out_flows as t_high
    left join asset on t_high.asset = asset.asset
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

create table cons_max_ramp_without_unit_commitment as
select
    nextval('id') as id,
    t_high.*
from
    t_highest_out_flows as t_high
    left join asset on t_high.asset = asset.asset
where
    asset.type in ('producer', 'storage', 'conversion')
    and asset.ramping
    and not asset.unit_commitment
    and asset.unit_commitment_method != 'basic'
;

create table cons_balance_storage_rep_period as
select
    *
from
    var_storage_level_rep_period
;

create table cons_balance_storage_over_clustered_year as
select
    *
from
    var_storage_level_over_clustered_year
;

drop sequence id
;

create sequence id start 1
;

create table cons_min_energy_over_clustered_year as
select
    nextval('id') as id,
    attr.asset,
    attr.year,
    attr.period_block_start,
    attr.period_block_end,
from
    asset_time_resolution_over_clustered_year as attr
    left join asset_milestone on attr.asset = asset_milestone.asset
    and attr.year = asset_milestone.milestone_year
where
    asset_milestone.min_energy_timeframe_partition is not null
;

drop sequence id
;

create sequence id start 1
;

create table cons_max_energy_over_clustered_year as
select
    nextval('id') as id,
    attr.asset,
    attr.year,
    attr.period_block_start,
    attr.period_block_end,
from
    asset_time_resolution_over_clustered_year as attr
    left join asset_milestone on attr.asset = asset_milestone.asset
    and attr.year = asset_milestone.milestone_year
where
    asset_milestone.max_energy_timeframe_partition is not null
;

drop sequence id
;

create sequence id start 1
;

create table cons_transport_flow_limit as
select
    nextval('id') as id,
    var_flow.from_asset,
    var_flow.to_asset,
    var_flow.year,
    var_flow.rep_period,
    var_flow.time_block_start,
    var_flow.time_block_end,
    var_flow.id as var_flow_id
from
    var_flow
    left join flow on flow.from_asset = var_flow.from_asset
    and flow.to_asset = var_flow.to_asset
where
    flow.is_transport
;

drop sequence id
;

create sequence id start 1
;

create table cons_group_max_investment_limit as
select
    nextval('id') as id,
    ga.name,
    ga.milestone_year,
    ga.max_investment_limit,
from
    group_asset as ga
where
    ga.invest_method
    and ga.max_investment_limit is not null
;

drop sequence id
;

create sequence id start 1
;

create table cons_group_min_investment_limit as
select
    nextval('id') as id,
    ga.name,
    ga.milestone_year,
    ga.min_investment_limit,
from
    group_asset as ga
where
    ga.invest_method
    and ga.min_investment_limit is not null
;

drop sequence id
;
