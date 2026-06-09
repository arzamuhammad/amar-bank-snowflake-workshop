with src as (
    select * from {{ source('bronze', 'raw_savings') }}
)
select
    account_id,
    customer_id,
    account_type,
    balance,
    interest_rate,
    opened_at,
    status,
    _loaded_at
from src
where account_id is not null
