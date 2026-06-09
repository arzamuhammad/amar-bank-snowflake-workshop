with src as (
    select * from {{ source('bronze', 'raw_repayments') }}
)
select
    repayment_id,
    loan_id,
    due_date,
    paid_date,
    amount_due,
    amount_paid,
    amount_due - amount_paid                      as shortfall,
    datediff('day', due_date, paid_date)          as days_late,
    is_late,
    _loaded_at
from src
where repayment_id is not null
