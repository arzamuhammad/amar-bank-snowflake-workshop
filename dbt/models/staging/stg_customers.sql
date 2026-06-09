with src as (
    select * from {{ source('bronze', 'raw_customers') }}
)
select
    customer_id,
    nik,
    nullif(npwp, '')                              as npwp,
    initcap(full_name)                            as full_name,
    upper(gender)                                 as gender,
    birth_date,
    datediff('year', birth_date, current_date())  as age,
    province,
    city,
    segment,
    credit_score,
    monthly_income,
    phone,
    lower(email)                                  as email,
    created_at,
    updated_at,
    _loaded_at
from src
where customer_id is not null
