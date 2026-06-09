{{ config(materialized='table') }}

with cust as (
    select * from {{ ref('stg_customers') }}
),
loans as (
    select
        customer_id,
        count(*)                 as n_loans,
        sum(plafond)             as total_plafond,
        sum(outstanding)         as total_outstanding,
        max(is_default)          as ever_default
    from {{ ref('stg_loans') }}
    group by customer_id
),
sav as (
    select
        customer_id,
        count(*)                 as n_accounts,
        sum(balance)             as total_balance
    from {{ ref('stg_savings') }}
    group by customer_id
),
txn as (
    select
        s.customer_id,
        count(*)                 as n_txn,
        sum(t.amount)            as total_txn_amount
    from {{ ref('stg_transactions') }} t
    join {{ ref('stg_savings') }} s on t.account_id = s.account_id
    group by s.customer_id
)
select
    c.customer_id,
    c.full_name,
    c.segment,
    c.province,
    c.city,
    c.age,
    c.credit_score,
    c.monthly_income,
    coalesce(l.n_loans, 0)            as n_loans,
    coalesce(l.total_plafond, 0)      as total_plafond,
    coalesce(l.total_outstanding, 0)  as total_outstanding,
    coalesce(l.ever_default, 0)       as ever_default,
    coalesce(sv.n_accounts, 0)        as n_savings_accounts,
    coalesce(sv.total_balance, 0)     as total_savings_balance,
    coalesce(tx.n_txn, 0)             as n_transactions,
    coalesce(tx.total_txn_amount, 0)  as total_txn_amount
from cust c
left join loans l on c.customer_id = l.customer_id
left join sav   sv on c.customer_id = sv.customer_id
left join txn   tx on c.customer_id = tx.customer_id
