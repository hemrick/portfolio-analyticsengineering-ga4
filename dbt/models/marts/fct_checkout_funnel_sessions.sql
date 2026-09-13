{% set ga4_start_date = var('ga4_start_date', '2020-11-01') %}
{% set ga4_end_date = var('ga4_end_date', '2021-01-31') %}
{% set ga4_start_suffix = ga4_start_date | replace('-', '') %}
{% set ga4_end_suffix = ga4_end_date | replace('-', '') %}

{{
  config(
    materialized='incremental',
    incremental_strategy='insert_overwrite',
    partition_by={
      "field": "session_date",
      "data_type": "date",
      "granularity": "day"
    },
    on_schema_change='fail'
  )
}}

with base_events as (

    select
        coalesce(user_id, user_pseudo_id) as user_key,
        (select value.int_value from unnest(event_params) where key = 'ga_session_id') as ga_session_id,
        parse_date('%Y%m%d', event_date) as event_date,
        traffic_source.source as user_acquisition_source,
        traffic_source.medium as user_acquisition_medium,
        traffic_source.name as user_acquisition_campaign,
        event_name,
        datetime(timestamp_micros(event_timestamp)) as event_datetime,
        event_timestamp
    from {{ source('ga4_obfuscated_sample_ecommerce', 'events') }}
    where _table_suffix between '{{ ga4_start_suffix }}' and '{{ ga4_end_suffix }}'
      and event_name in (
          'add_to_cart',
          'begin_checkout',
          'add_payment_info',
          'purchase'
      )

),

ranked_events as (

    select
        concat(user_key, '-', cast(ga_session_id as string)) as session_id,
        event_date,
        user_acquisition_source,
        user_acquisition_medium,
        user_acquisition_campaign,
        event_name,
        event_datetime,
        event_timestamp,
        row_number() over (
            partition by user_key, ga_session_id
            order by event_timestamp asc
        ) as event_rank
    from base_events
    where user_key is not null
      and ga_session_id is not null

)

select
    session_id,
    min(event_date) as session_date,
    array_agg(user_acquisition_source ignore nulls order by event_timestamp asc limit 1)[safe_offset(0)] as user_acquisition_source,
    array_agg(user_acquisition_medium ignore nulls order by event_timestamp asc limit 1)[safe_offset(0)] as user_acquisition_medium,
    array_agg(user_acquisition_campaign ignore nulls order by event_timestamp asc limit 1)[safe_offset(0)] as user_acquisition_campaign,
    array_agg(
        struct(event_name, event_datetime, event_rank)
        order by event_rank
    ) as funnel_events_record,
    max(if(event_name = 'add_to_cart', 1, 0)) as has_add_to_cart,
    max(if(event_name = 'begin_checkout', 1, 0)) as has_begin_checkout,
    max(if(event_name = 'add_payment_info', 1, 0)) as has_add_payment_info,
    max(if(event_name = 'purchase', 1, 0)) as has_purchase
from ranked_events
group by
    session_id
