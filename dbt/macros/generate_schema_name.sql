{#
  generate_schema_name — override default dbt behavior.

  Default dbt menggabung target.schema + custom schema (mis. SILVER_GOLD).
  Untuk arsitektur medallion (BRONZE/SILVER/GOLD) kita ingin nama schema
  dipakai APA ADANYA dari config `+schema:` di dbt_project.yml / snapshot.

  Hasil:
    staging  (+schema: SILVER) -> SILVER
    gold     (+schema: GOLD)   -> GOLD
    snapshot (target_schema: SILVER) -> SILVER
  Jika sebuah model tidak set custom schema, fallback ke target.schema.
#}
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- set default_schema = target.schema -%}
    {%- if custom_schema_name is none -%}
        {{ default_schema }}
    {%- else -%}
        {{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
