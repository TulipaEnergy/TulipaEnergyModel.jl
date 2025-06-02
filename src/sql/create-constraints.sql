drop sequence if exists id
;

create sequence id start 1
;

drop table if exists cons_balance_conversion
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

drop table if exists cons_balance_consumer
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

drop table if exists cons_balance_hub
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

drop table if exists cons_capacity_incoming_simple_method
;

create table cons_capacity_incoming_simple_method as
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

drop table if exists cons_capacity_incoming_simple_method_non_investable_storage_with_binary
;

create table cons_capacity_incoming_simple_method_non_investable_storage_with_binary as
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

drop table if exists cons_capacity_incoming_simple_method_investable_storage_with_binary
;

create table cons_capacity_incoming_simple_method_investable_storage_with_binary as
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

drop table if exists cons_capacity_outgoing_compact_method
;

create table cons_capacity_outgoing_compact_method as
select
    nextval('id') as id,
    t_high.*
from
    t_highest_out_flows as t_high
    left join asset on t_high.asset = asset.asset
where
    asset.type in ('producer', 'storage', 'conversion')
    and asset.investment_method = 'compact'
;

drop sequence id
;

create sequence id start 1
;

drop table if exists cons_capacity_outgoing_simple_method
;

create table cons_capacity_outgoing_simple_method as
select
    nextval('id') as id,
    t_high.*
from
    t_highest_out_flows as t_high
    left join asset on t_high.asset = asset.asset
where
    asset.type in ('producer', 'storage', 'conversion')
    and asset.investment_method in ('simple', 'none')
;

drop sequence id
;

create sequence id start 1
;

drop table if exists cons_capacity_outgoing_simple_method_non_investable_storage_with_binary
;

create table cons_capacity_outgoing_simple_method_non_investable_storage_with_binary as
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

drop table if exists cons_capacity_outgoing_simple_method_investable_storage_with_binary
;

create table cons_capacity_outgoing_simple_method_investable_storage_with_binary as
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

drop sequence id
;

create sequence id start 1
;

drop table if exists cons_min_outgoing_flow_for_transport_flows_without_unit_commitment
;

create table cons_min_outgoing_flow_for_transport_flows_without_unit_commitment as
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
                        flow
                    where
                        flow.from_asset = asset.asset
                ),
                false
            ) as outgoing_flows_have_transport_flows,
        from
            asset
    )
select
    nextval('id') as id,
    t_high.*
from
    t_highest_out_flows as t_high
    left join asset on t_high.asset = asset.asset
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

drop table if exists cons_min_incoming_flow_for_transport_flows
;

create table cons_min_incoming_flow_for_transport_flows as
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
                        flow
                    where
                        flow.to_asset = asset.asset
                ),
                false
            ) as incoming_flows_have_transport_flows,
        from
            asset
    )
select
    nextval('id') as id,
    t_high.*
from
    t_highest_out_flows as t_high
    left join asset on t_high.asset = asset.asset
    left join transport_flow_info on t_high.asset = transport_flow_info.asset
where
    asset.type in ('storage', 'conversion')
    and transport_flow_info.incoming_flows_have_transport_flows
;

drop sequence id
;

drop table if exists cons_limit_units_on_compact_method
;

create table cons_limit_units_on_compact_method as
select
    *
from
    var_units_on
    left join asset on var_units_on.asset = asset.asset
where
    asset.investment_method = 'compact'
;

drop table if exists cons_limit_units_on_simple_method
;

create table cons_limit_units_on_simple_method as
select
    *
from
    var_units_on
    left join asset on var_units_on.asset = asset.asset
where
    asset.investment_method in ('simple', 'none')
;

create sequence id start 1
;

drop table if exists cons_min_output_flow_with_unit_commitment
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

drop table if exists cons_max_output_flow_with_basic_unit_commitment
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

drop table if exists cons_max_ramp_with_unit_commitment
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

drop table if exists cons_max_ramp_without_unit_commitment
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

drop table if exists cons_balance_storage_rep_period
;

create table cons_balance_storage_rep_period as
select
    *
from
    var_storage_level_rep_period
;

drop table if exists cons_balance_storage_over_clustered_year
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

drop table if exists cons_min_energy_over_clustered_year
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

drop table if exists cons_max_energy_over_clustered_year
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

drop table if exists cons_transport_flow_limit_simple_method
;

create table cons_transport_flow_limit_simple_method as
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

drop table if exists cons_group_max_investment_limit
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

drop table if exists cons_group_min_investment_limit
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

create sequence id start 1
;

-- This query fetches and appends flows relationships data to constraint table
-- It joins the `cons_flows_relationships` table with the `flows_relationships` table
-- using a composite key created by concatenating the flows from/to columns in the `flows_relationships` table.
-- since the asset created in the `t_lowest_flows_relationship` table is a composite key.
--
drop table if exists cons_flows_relationships
;

create table cons_flows_relationships as
select
    nextval('id') as id,
    t_low.*,
    fr.flow_1_from_asset,
    fr.flow_1_to_asset,
    fr.flow_2_from_asset,
    fr.flow_2_to_asset,
    fr.sense,
    fr.constant,
    fr.ratio,
from
    t_lowest_flows_relationship as t_low
    left join flows_relationships as fr on t_low.asset = concat(
        fr.flow_1_from_asset,
        '_',
        fr.flow_1_to_asset,
        '_',
        fr.flow_2_from_asset,
        '_',
        fr.flow_2_to_asset
    )
    and t_low.year = fr.milestone_year
;

drop sequence id
;

create sequence id start 1
;

drop table if exists cons_dc_power_flow
;

create table cons_dc_power_flow as
select
    nextval('id') as id,
    flow.from_asset,
    flow.to_asset,
    t_high.year,
    t_high.rep_period,
    t_high.time_block_start,
    t_high.time_block_end
from
    t_highest_flows_and_connecting_assets as t_high
left join flow on t_high.asset = CONCAT(flow.from_asset, '_', flow.to_asset)
left join flow_milestone on flow_milestone.from_asset = flow.from_asset
    and flow_milestone.to_asset = flow.to_asset
    and flow_milestone.milestone_year = t_high.year
where
    flow.is_transport
    and flow_milestone.dc_opf
;

drop sequence id
;

create sequence id start 1
;

drop table if exists cons_limit_decommission_compact_method
;

create table cons_limit_decommission_compact_method as
select
    nextval('id') as id,
    var_assets_decommission.asset,
    var_assets_decommission.milestone_year,
    var_assets_decommission.commission_year,
from
    var_assets_decommission
left join asset on asset.asset = var_assets_decommission.asset
where
    asset.investment_method = 'compact'
;

drop sequence id
;
