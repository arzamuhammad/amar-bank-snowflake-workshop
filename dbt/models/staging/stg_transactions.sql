with src as (
    select * from {{ source('bronze', 'raw_transactions') }}
)
select
    txn_id,
    account_id,
    txn_type,
    channel,
    amount,
    txn_ts,
    date_trunc('month', txn_ts)                   as txn_month,
    _loaded_at
from src
where txn_id is not null
