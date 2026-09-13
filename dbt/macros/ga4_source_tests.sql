{% test ga4_source_has_rows(model) %}

select
    row_count
from (
    select count(*) as row_count
    from {{ model }}
    where {{ ga4_source_table_suffix_filter() }}
)
where row_count = 0

{% endtest %}

{% test ga4_funnel_events_have_ga_session_id(model) %}

select
    event_date,
    event_timestamp,
    event_name
from {{ model }}
where {{ ga4_source_table_suffix_filter() }}
  and event_name in (
      'add_to_cart',
      'begin_checkout',
      'add_payment_info',
      'purchase'
  )
  and (select value.int_value from unnest(event_params) where key = 'ga_session_id') is null

{% endtest %}

{% test ga4_funnel_events_have_user_key(model) %}

select
    event_date,
    event_timestamp,
    event_name
from {{ model }}
where {{ ga4_source_table_suffix_filter() }}
  and event_name in (
      'add_to_cart',
      'begin_checkout',
      'add_payment_info',
      'purchase'
  )
  and coalesce(user_id, user_pseudo_id) is null

{% endtest %}
