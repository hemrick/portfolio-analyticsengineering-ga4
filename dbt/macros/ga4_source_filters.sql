{% macro ga4_start_suffix() %}
  {{ return(var('ga4_start_date', '2020-11-01') | replace('-', '')) }}
{% endmacro %}

{% macro ga4_end_suffix() %}
  {{ return(var('ga4_end_date', '2021-01-31') | replace('-', '')) }}
{% endmacro %}

{% macro ga4_source_table_suffix_filter() %}
  {{ return("_table_suffix between '" ~ ga4_start_suffix() ~ "' and '" ~ ga4_end_suffix() ~ "'") }}
{% endmacro %}

