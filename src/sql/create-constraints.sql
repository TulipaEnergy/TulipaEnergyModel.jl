drop sequence if exists id
;

create sequence id start 1
;

drop table if exists cons_balance_conversion
;

create table cons_balance_conversion as
select
    nextval('id') as id,
    t_low.*
from
    t_lowest_flows_conversion_balance as t_low
order by
    t_low.asset,
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

drop table if exists cons_capacity_outgoing_semi_compact_method
;

create table cons_capacity_outgoing_semi_compact_method as
with cons_data as (
    select
        t_high.asset,
        asset_both.milestone_year as milestone_year,
        asset_both.commission_year as commission_year,
        t_high.rep_period,
        t_high.time_block_start,
        t_high.time_block_end
    from
        t_highest_out_flows as t_high
        left join asset on t_high.asset = asset.asset
        left join asset_both on t_high.asset = asset_both.asset
        and t_high.year = asset_both.milestone_year
    where
        asset.type in ('producer', 'storage', 'conversion')
        and asset.investment_method = 'semi-compact'
    -- t_high is ordered by asset, milestone_year, rep_period, time_block_start
    -- since we added commission_year, we need to explictly order by commission_year
    -- note the order is only needed for the test, constraints do not require it
    order by
        t_high.asset,
        asset_both.milestone_year,
        asset_both.commission_year,
        t_high.rep_period,
        t_high.time_block_start
    )
select
   nextval('id') as id,
   *
from
    cons_data
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
-- Note we assume that the this property does not change across the years
-- In other words, we assume the underlying graph does not change
-- This information is gathered from the flow table
-- COALESCE is used to handle the case where there are no outgoing flows
with
    cte_transport_flow_info as (
        select
            asset.asset,
            coalesce(
                (
                    select
                        bool_or(flow.is_transport) -- true if any outgoing flow is transport
                    from
                        flow
                    where
                        flow.from_asset = asset.asset
                ),
                false -- coalescing to false in case there are no outgoing flows
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
    left join cte_transport_flow_info on t_high.asset = cte_transport_flow_info.asset
where
    asset.type in ('producer', 'storage', 'conversion')
    and cte_transport_flow_info.outgoing_flows_have_transport_flows
    -- Assets with unit commitment already have a minimum outgoing flow constraints
    and not asset.unit_commitment
    and asset.investment_method in ('compact', 'simple', 'none')
;

drop sequence id
;

create sequence id start 1
;

drop table if exists cons_min_outgoing_flow_for_transport_vintage_flows
;

-- This constraint is very similar to cons_min_outgoing_flow_for_transport_flows_without_unit_commitment
-- but it applies to vintage flows instead of regular flows
create table cons_min_outgoing_flow_for_transport_vintage_flows as
with
    cte_transport_flow_info as (
        select
            asset.asset,
            coalesce(
                (
                    select
                        bool_or(flow.is_transport) -- true if any outgoing flow is transport
                    from
                        flow
                    where
                        flow.from_asset = asset.asset
                ),
                false -- coalescing to false in case there are no outgoing flows
            ) as outgoing_flows_have_transport_flows,
        from
            asset
    )
select
    nextval('id') as id,
    t_high.asset as asset,
    t_high.year as milestone_year,
    asset_both.commission_year as commission_year,
    t_high.rep_period,
    t_high.time_block_start,
    t_high.time_block_end
from
    t_highest_out_flows as t_high
    left join asset on t_high.asset = asset.asset
    left join cte_transport_flow_info on t_high.asset = cte_transport_flow_info.asset
    left join asset_both on t_high.asset = asset_both.asset
        and t_high.year = asset_both.milestone_year
where
    asset.type in ('producer', 'storage', 'conversion')
    and asset.investment_method = 'semi-compact'
    and cte_transport_flow_info.outgoing_flows_have_transport_flows
    -- Note we do not exclude UC here, because UC only guarantees
    -- the minimum point of flow, instead of vintage flow
    -- For the same reason, we cannot reuse cons_min_outgoing_flow_for_transport_flows_without_unit_commitment
    -- directly
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
    cte_transport_flow_info as (
        select
            asset.asset,
            coalesce(
                (
                    select
                        bool_or(flow.is_transport) -- true if any incoming flow is transport
                    from
                        flow
                    where
                        flow.to_asset = asset.asset
                ),
                false -- coalescing to false in case there are no incoming flows
            ) as incoming_flows_have_transport_flows
        from
            asset
    )
select
    nextval('id') as id,
    t_high.*
from
    t_highest_out_flows as t_high
    left join asset on t_high.asset = asset.asset
    left join cte_transport_flow_info on t_high.asset = cte_transport_flow_info.asset
where
    asset.type in ('storage', 'conversion')
    and cte_transport_flow_info.incoming_flows_have_transport_flows
    and asset.investment_method in ('compact', 'simple', 'none')
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

drop sequence id
;

create sequence id start 1
;

drop table if exists cons_su_ramping_compact_1bin
;

create table cons_su_ramping_compact_1bin as
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
    and asset.unit_commitment_method like '1bin-1%'
;

drop sequence id
;

create sequence id start 1
;

drop table if exists cons_sd_ramping_compact_1bin
;

create table cons_sd_ramping_compact_1bin as
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
    and asset.unit_commitment_method like '1bin-1%'
;

drop sequence id
;

create sequence id start 1
;

drop table if exists cons_su_ramping_tight_1bin
;

create table cons_su_ramping_tight_1bin as
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
    and asset.unit_commitment_method = '1bin-1T'
;

drop sequence id
;

create sequence id start 1
;

drop table if exists cons_sd_ramping_tight_1bin
;

create table cons_sd_ramping_tight_1bin as
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
    and asset.unit_commitment_method = '1bin-1T'
;

drop sequence id
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

drop sequence if exists id
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

create sequence id start 1
;

drop table if exists cons_vintage_flow_sum_semi_compact_method
;

create table cons_vintage_flow_sum_semi_compact_method as
select
    nextval('id') as id,
    from_asset,
    to_asset,
    year,
    rep_period,
    time_block_start,
    time_block_end,
from
    var_flow
left join asset on asset.asset = var_flow.from_asset
where
    asset.investment_method = 'semi-compact'
;

drop sequence id
;

create sequence id start 1
;

drop table if exists cons_start_up_upper_bound
;

create table cons_start_up_upper_bound as
select
    nextval('id') as id,
    sub.*
from (
    select
        t_high.asset,
        t_high.year,
        t_high.rep_period,
        t_high.time_block_start,
        t_high.time_block_end
    from
        t_highest_assets_and_out_flows as t_high
        inner join asset_time_resolution_rep_period as atr
            on
                t_high.asset = atr.asset
                and t_high.year = atr.year
                and t_high.rep_period = atr.rep_period
                and t_high.time_block_start = atr.time_block_start
        left join asset on asset.asset = atr.asset
    where
        asset.type in ('producer', 'conversion')
        and asset.unit_commitment = true
        and asset.unit_commitment_method LIKE '3var%'
    order by
        t_high.asset,
        t_high.year,
        t_high.rep_period,
        t_high.time_block_start
) as sub
;

drop sequence id
;

create sequence id start 1
;

drop table if exists cons_shut_down_upper_bound_simple_investment
;

create table cons_shut_down_upper_bound_simple_investment as
select
    nextval('id') as id,
    sub.*
from (
    select
        t_high.asset,
        t_high.year,
        t_high.rep_period,
        t_high.time_block_start,
        t_high.time_block_end
    from
        t_highest_assets_and_out_flows as t_high
        inner join asset_time_resolution_rep_period as atr
            on
                t_high.asset = atr.asset
                and t_high.year = atr.year
                and t_high.rep_period = atr.rep_period
                and t_high.time_block_start = atr.time_block_start
        left join asset on asset.asset = atr.asset
    where
        asset.type in ('producer', 'conversion')
        and asset.unit_commitment = true
        and asset.unit_commitment_method LIKE '3var%'
        and asset.investment_method in ('simple', 'none')

    order by
        t_high.asset,
        t_high.year,
        t_high.rep_period,
        t_high.time_block_start
) as sub
;

drop sequence id
;

create sequence id start 1
;

drop table if exists cons_shut_down_upper_bound_compact_investment
;

create table cons_shut_down_upper_bound_compact_investment as
with sub as
(select distinct
    t_high.asset,
    t_high.year,
    t_high.rep_period,
    t_high.time_block_start,
    t_high.time_block_end,
from
    asset_time_resolution_rep_period as atr
    join
    t_highest_assets_and_out_flows as t_high
        on
            atr.asset = t_high.asset and
            atr.time_block_start = t_high.time_block_start and
            atr.rep_period = t_high.rep_period and
            atr.year = t_high.year
    join asset
        on
            asset.asset = t_high.asset
where
    asset.type in ('producer', 'conversion')
    and asset.unit_commitment = true
    and asset.unit_commitment_method LIKE '3var%'
    and asset.investment_method = 'compact'
order by
    t_high.asset,
    t_high.year,
    t_high.rep_period,
    t_high.time_block_start)
select
    nextval('id') as id,
    sub.*
from sub
;

drop sequence id
;

create sequence id start 1
;

drop table if exists cons_unit_commitment_logic
;

create table cons_unit_commitment_logic as
select distinct
    nextval('id') as id,
    sub.*
from (
    select distinct
        t_high.asset,
        t_high.year,
        t_high.rep_period,
        t_high.time_block_start,
        t_high.time_block_end,
    from
        t_highest_assets_and_out_flows as t_high
        inner join asset_time_resolution_rep_period as atr
            on
                t_high.asset = atr.asset
                and t_high.year = atr.year
                and t_high.rep_period = atr.rep_period
                and t_high.time_block_start = atr.time_block_start
        left join asset on asset.asset = atr.asset
    where
        asset.type in ('producer', 'conversion')
        and asset.unit_commitment = true
        and asset.unit_commitment_method LIKE '3var%'
    order by
        t_high.asset,
        t_high.year,
        t_high.rep_period,
        t_high.time_block_start
) as sub
;

drop sequence id
;

create sequence id start 1
;

drop table if exists cons_start_up_lower_bound
;

create table cons_start_up_lower_bound as
with sorted as (
    select distinct
        t_high.asset,
        t_high.year,
        t_high.rep_period,
        t_high.time_block_start,
        t_high.time_block_end,
    from
        asset_time_resolution_rep_period as atr
        join t_highest_assets_and_out_flows as t_high
            on atr.asset = t_high.asset
            and atr.time_block_start = t_high.time_block_start and
            atr.rep_period = t_high.rep_period and
            atr.year = t_high.year
        join asset
            on asset.asset = t_high.asset
    where
        asset.type in ('producer', 'conversion')
        and asset.unit_commitment = true
        and asset.unit_commitment_method = 'SU-SD-compact'
    order by
        t_high.asset,
        t_high.year,
        t_high.rep_period,
        t_high.time_block_start
)
select
    nextval('id') as id,
    sorted.*
from
    sorted
order by
    sorted.asset,
    sorted.year,
    sorted.rep_period,
    sorted.time_block_start
;

drop sequence id
;

create sequence id start 1
;

drop table if exists cons_shut_down_lower_bound
;

create table cons_shut_down_lower_bound as
with sorted as (
    select distinct
        t_high.asset,
        t_high.year,
        t_high.rep_period,
        t_high.time_block_start,
        t_high.time_block_end,
    from
        asset_time_resolution_rep_period as atr
        join t_highest_assets_and_out_flows as t_high
            on atr.asset = t_high.asset
            and atr.time_block_start = t_high.time_block_start and
            atr.rep_period = t_high.rep_period and
            atr.year = t_high.year
        join asset
            on asset.asset = t_high.asset
    where
        asset.type in ('producer', 'conversion')
        and asset.unit_commitment = true
        and asset.unit_commitment_method = 'SU-SD-compact'
    order by
        t_high.asset,
        t_high.year,
        t_high.rep_period,
        t_high.time_block_start
)
select
    nextval('id') as id,
    sorted.*
from
    sorted
order by
    sorted.asset,
    sorted.year,
    sorted.rep_period,
    sorted.time_block_start
;

drop sequence id
;

create sequence id start 1
;

create table cons_minimum_up_time as
with sorted as
(select distinct
    t_high.asset,
    t_high.year,
    t_high.rep_period,
    t_high.time_block_start,
    t_high.time_block_end,
from
    asset_time_resolution_rep_period as atr
    join
    t_highest_assets_and_out_flows as t_high
        on
            atr.asset = t_high.asset and
            atr.time_block_start = t_high.time_block_start
    join asset
        on
            asset.asset = t_high.asset
where
    asset.type in ('producer', 'conversion')
    and asset.unit_commitment = true
    and asset.unit_commitment_method in ('min_up_down')
order by
    t_high.asset,
    t_high.year,
    t_high.rep_period,
    t_high.time_block_start)
select
    nextval('id') as id,
    sorted.*
from sorted
;

drop sequence id
;

create sequence id start 1
;

create table cons_minimum_down_time_simple_investment as
with sorted as
(select distinct
    t_high.asset,
    t_high.year,
    t_high.rep_period,
    t_high.time_block_start,
    t_high.time_block_end
from
    asset_time_resolution_rep_period as atr
    join
    t_highest_assets_and_out_flows as t_high
        on
            atr.asset = t_high.asset and
            atr.time_block_start = t_high.time_block_start
    join asset
        on
            asset.asset = t_high.asset
where
    asset.type in ('producer', 'conversion')
    and asset.unit_commitment = true
    and asset.unit_commitment_method in ('min_up_down')
    and asset.investment_method in ('simple', 'none')
order by
    t_high.asset,
    t_high.year,
    t_high.rep_period,
    t_high.time_block_start)
select
    nextval('id') as id,
    sorted.*
from sorted
;

drop sequence id
;

create sequence id start 1
;

create table cons_minimum_down_time_compact_investment as
with sorted as
(select distinct
    t_high.asset,
    t_high.year,
    t_high.rep_period,
    t_high.time_block_start,
    t_high.time_block_end
from
    asset_time_resolution_rep_period as atr
    join
    t_highest_assets_and_out_flows as t_high
        on
            atr.asset = t_high.asset and
            atr.time_block_start = t_high.time_block_start
    join asset
        on
            asset.asset = t_high.asset
where
    asset.type in ('producer', 'conversion')
    and asset.unit_commitment = true
    and asset.unit_commitment_method in ('min_up_down')
    and asset.investment_method = 'compact'
order by
    t_high.asset,
    t_high.year,
    t_high.rep_period,
    t_high.time_block_start)
select
    nextval('id') as id,
    sorted.*
from sorted
;

drop sequence id
;

create sequence id start 1
;

create table cons_su_ramp_vars_flow_diff as
with sub as
(select distinct
    t_high.asset,
    t_high.year,
    t_high.rep_period,
    t_high.time_block_start,
    t_high.time_block_end,
from
    asset_time_resolution_rep_period as atr
    join t_highest_assets_and_out_flows as t_high
        on atr.asset = t_high.asset
        and atr.rep_period = t_high.rep_period
        and atr.year = t_high.year
    join asset
        on asset.asset = t_high.asset
where
    asset.type in ('producer', 'conversion')
    and asset.ramping
    and asset.unit_commitment
    and asset.unit_commitment_method in ('3var-su-sd-ramp')
order by
    t_high.asset,
    t_high.year,
    t_high.rep_period,
    t_high.time_block_start)
select
    nextval('id') as id,
    sub.*
from sub
;

drop sequence id
;

create sequence id start 1
;

create table cons_sd_ramp_vars_flow_diff as
select
    nextval('id') as id,
    cons_su_ramp_vars_flow_diff.*
from cons_su_ramp_vars_flow_diff
;

drop sequence id
;

create sequence id start 1
;

create table cons_su_ramp_vars_flow_upper_bound as
with sub as
(select distinct
    t_high.*,
    var_units_on.time_block_start as units_on_start,
    var_units_on.time_block_end as units_on_end
from
    asset_time_resolution_rep_period as atr
    join t_highest_assets_and_out_flows as t_high
        on atr.asset = t_high.asset
        and atr.rep_period = t_high.rep_period
        and atr.year = t_high.year
    join asset
        on asset.asset = t_high.asset
    left join var_units_on on t_high.asset = var_units_on.asset
        and t_high.year = var_units_on.year
        and t_high.rep_period = var_units_on.rep_period
        and t_high.time_block_start >= var_units_on.time_block_start
        and t_high.time_block_end <= var_units_on.time_block_end
where
    asset.type in ('producer', 'conversion')
    and asset.ramping
    and asset.unit_commitment
    and asset.unit_commitment_method in ('3var-su-sd-ramp')
order by
    t_high.asset,
    t_high.year,
    t_high.rep_period,
    t_high.time_block_start)
select
    nextval('id') as id,
    sub.*
from sub
;

drop sequence id
;

create sequence id start 1
;

create table cons_sd_ramp_vars_flow_upper_bound as
select
    nextval('id') as id,
    cons_su_ramp_vars_flow_upper_bound.*
from cons_su_ramp_vars_flow_upper_bound
;

drop sequence id
;

create sequence id start 1
;

create table cons_su_sd_ramp_vars_flow_with_high_uptime as
select
    nextval('id') as id,
    cons_su_ramp_vars_flow_upper_bound.*
from cons_su_ramp_vars_flow_upper_bound
;

drop sequence id
;

create sequence id start 1
;

drop table if exists cons_su_ramping_compact_1bin
;

create table cons_su_ramping_compact_1bin as
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
    and asset.unit_commitment_method like '1var-1%'
;

drop sequence id
;

create sequence id start 1
;

drop table if exists cons_sd_ramping_compact_1bin
;

create table cons_sd_ramping_compact_1bin as
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
    and asset.unit_commitment_method like '1var-1%'
;

drop sequence id
;

create sequence id start 1
;

drop table if exists cons_su_ramping_tight_1bin
;

create table cons_su_ramping_tight_1bin as
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
    and asset.unit_commitment_method = '1var-1T'
;

drop sequence id
;

create sequence id start 1
;

drop table if exists cons_sd_ramping_tight_1bin
;

create table cons_sd_ramping_tight_1bin as
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
    and asset.unit_commitment_method = '1var-1T'
;

drop sequence id
;

create sequence id start 1
;

create table cons_susd_trajectory as
with sorted as (
    select
        t_high.asset,
        t_high.year,
        t_high.rep_period,
        t_high.time_block_start,
        t_high.time_block_end,
        asset.min_operating_point,
    from
        t_highest_assets_and_out_flows as t_high
        join asset
            on
                t_high.asset = asset.asset
    where
        asset.type in ('producer', 'conversion')
        and asset.unit_commitment
        and asset.unit_commitment_method = '3bin-3'
    order by
        t_high.asset,
        t_high.year,
        t_high.rep_period,
        t_high.time_block_start,
        t_high.time_block_end
)
select
    nextval('id') as id,
    sorted.*
from
    sorted
;

