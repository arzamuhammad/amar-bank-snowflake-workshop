{#
  SCD Type-2 dimension for customers using dbt snapshots.
  Tracks changes to address/segment/score over time.
  Materializes into AMAR_WORKSHOP.SILVER.DIM_CUSTOMERS_SCD2
  Run with: dbt snapshot
#}
{% snapshot dim_customers_scd2 %}
{{
    config(
      target_database='AMAR_WORKSHOP',
      target_schema='SILVER',
      unique_key='customer_id',
      strategy='check',
      check_cols=['province', 'city', 'segment', 'credit_score', 'monthly_income']
    )
}}
select
    customer_id,
    nik,
    full_name,
    province,
    city,
    segment,
    credit_score,
    monthly_income,
    updated_at
from {{ source('bronze', 'raw_customers') }}
where customer_id is not null
{% endsnapshot %}
