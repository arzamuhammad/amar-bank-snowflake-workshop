{{ config(materialized='table') }}

with loans as (
    select * from {{ ref('stg_loans') }}
),
repay as (
    select
        loan_id,
        count(*)                         as n_installments,
        sum(amount_due)                  as total_due,
        sum(amount_paid)                 as total_paid,
        sum(is_late)                     as n_late,
        max(days_late)                   as max_days_late
    from {{ ref('stg_repayments') }}
    group by loan_id
)
select
    l.loan_id,
    l.customer_id,
    l.product_segment,
    l.product_type,
    l.status,
    l.dpd,
    l.dpd_bucket,
    l.is_default,
    l.plafond,
    l.outstanding,
    l.interest_rate,
    l.disbursed_at,
    coalesce(r.n_installments, 0)        as n_installments,
    coalesce(r.total_due, 0)             as total_due,
    coalesce(r.total_paid, 0)            as total_paid,
    coalesce(r.n_late, 0)                as n_late,
    coalesce(r.max_days_late, 0)         as max_days_late,
    case when r.total_due > 0
         then round(r.total_paid / r.total_due, 4) else null end as collection_ratio
from loans l
left join repay r on l.loan_id = r.loan_id
