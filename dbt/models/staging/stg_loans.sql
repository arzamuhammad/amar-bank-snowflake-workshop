with src as (
    select * from {{ source('bronze', 'raw_loans') }}
)
select
    loan_id,
    customer_id,
    product_type,
    case
        when product_type ilike 'Tunaiku%' then 'Tunaiku'
        when product_type ilike 'SMB%'     then 'SMB'
        else 'Other'
    end                                           as product_segment,
    plafond,
    tenor_months,
    interest_rate,
    disbursed_at,
    status,
    dpd,
    is_default,
    case
        when dpd = 0   then 'CURRENT'
        when dpd <= 30 then 'DPD_1_30'
        when dpd <= 60 then 'DPD_31_60'
        when dpd <= 90 then 'DPD_61_90'
        else 'DPD_90_PLUS'
    end                                           as dpd_bucket,
    outstanding,
    updated_at,
    _loaded_at
from src
where loan_id is not null
