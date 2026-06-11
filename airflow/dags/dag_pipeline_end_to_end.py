"""
DAG: amar_pipeline_end_to_end
Orchestration lives ENTIRELY in Airflow (no Snowflake Tasks/Streams).

Flow:  ingest (COPY INTO Bronze)  ->  dbt build (EXECUTE DBT PROJECT)
       ->  dbt snapshot (SCD-2)   ->  DQ gate  ->  notify

Requires:
  - Airflow connection id "snowflake_default" (key-pair auth recommended)
  - provider: apache-airflow-providers-snowflake
  - dbt project deployed to Snowflake as AMAR_WORKSHOP.SILVER.AMAR_WORKSHOP
    (snow dbt deploy) so EXECUTE DBT PROJECT works.
"""
from datetime import datetime, timedelta

from airflow import DAG
from airflow.providers.common.sql.operators.sql import SQLExecuteQueryOperator
from airflow.utils.task_group import TaskGroup

SNOWFLAKE_CONN_ID = "snowflake_default"
WAREHOUSE = "AMAR_WORKSHOP_WH"
DATABASE = "AMAR_WORKSHOP"

default_args = {
    "owner": "data_engineering",
    "retries": 2,
    "retry_delay": timedelta(minutes=2),
}

# COPY INTO statements (one per Bronze table)
COPY_CUSTOMERS = """
COPY INTO AMAR_WORKSHOP.BRONZE.RAW_CUSTOMERS
    (customer_id, nik, npwp, full_name, gender, birth_date, province, city,
     segment, credit_score, monthly_income, phone, email, created_at, updated_at, _source_file)
FROM (
  SELECT $1:customer_id,$1:nik,$1:npwp,$1:full_name,$1:gender,$1:birth_date,$1:province,
         $1:city,$1:segment,$1:credit_score,$1:monthly_income,$1:phone,$1:email,
         $1:created_at,$1:updated_at, METADATA$FILENAME
  FROM @AMAR_WORKSHOP.BRONZE.STG_S3_AMAR/customers.csv
)
FILE_FORMAT=(FORMAT_NAME=AMAR_WORKSHOP.BRONZE.FF_CSV)
MATCH_BY_COLUMN_NAME=CASE_INSENSITIVE ON_ERROR=CONTINUE;
"""

COPY_LOANS = """
COPY INTO AMAR_WORKSHOP.BRONZE.RAW_LOANS
    (loan_id, customer_id, product_type, plafond, tenor_months, interest_rate,
     disbursed_at, status, dpd, is_default, outstanding, updated_at, _source_file)
FROM (
  SELECT $1:loan_id,$1:customer_id,$1:product_type,$1:plafond,$1:tenor_months,
         $1:interest_rate,$1:disbursed_at,$1:status,$1:dpd,$1:is_default,
         $1:outstanding,$1:updated_at, METADATA$FILENAME
  FROM @AMAR_WORKSHOP.BRONZE.STG_S3_AMAR/loans.csv
)
FILE_FORMAT=(FORMAT_NAME=AMAR_WORKSHOP.BRONZE.FF_CSV)
MATCH_BY_COLUMN_NAME=CASE_INSENSITIVE ON_ERROR=CONTINUE;
"""

COPY_REPAYMENTS = """
COPY INTO AMAR_WORKSHOP.BRONZE.RAW_REPAYMENTS
    (repayment_id, loan_id, due_date, paid_date, amount_due, amount_paid, is_late, _source_file)
FROM (
  SELECT $1:repayment_id,$1:loan_id,$1:due_date,$1:paid_date,$1:amount_due,
         $1:amount_paid,$1:is_late, METADATA$FILENAME
  FROM @AMAR_WORKSHOP.BRONZE.STG_S3_AMAR/repayments.csv
)
FILE_FORMAT=(FORMAT_NAME=AMAR_WORKSHOP.BRONZE.FF_CSV)
MATCH_BY_COLUMN_NAME=CASE_INSENSITIVE ON_ERROR=CONTINUE;
"""

COPY_SAVINGS = """
COPY INTO AMAR_WORKSHOP.BRONZE.RAW_SAVINGS
    (account_id, customer_id, account_type, balance, interest_rate, opened_at, status, _source_file)
FROM (
  SELECT $1:account_id,$1:customer_id,$1:account_type,$1:balance,$1:interest_rate,
         $1:opened_at,$1:status, METADATA$FILENAME
  FROM @AMAR_WORKSHOP.BRONZE.STG_S3_AMAR/savings.csv
)
FILE_FORMAT=(FORMAT_NAME=AMAR_WORKSHOP.BRONZE.FF_CSV)
MATCH_BY_COLUMN_NAME=CASE_INSENSITIVE ON_ERROR=CONTINUE;
"""

COPY_TRANSACTIONS = """
COPY INTO AMAR_WORKSHOP.BRONZE.RAW_TRANSACTIONS
    (txn_id, account_id, txn_type, channel, amount, txn_ts, _source_file)
FROM (
  SELECT $1:txn_id,$1:account_id,$1:txn_type,$1:channel,$1:amount,$1:txn_ts, METADATA$FILENAME
  FROM @AMAR_WORKSHOP.BRONZE.STG_S3_AMAR/transactions.csv
)
FILE_FORMAT=(FORMAT_NAME=AMAR_WORKSHOP.BRONZE.FF_CSV)
MATCH_BY_COLUMN_NAME=CASE_INSENSITIVE ON_ERROR=CONTINUE;
"""

# dbt Projects on Snowflake — runs transform compute inside Snowflake
DBT_BUILD = "EXECUTE DBT PROJECT AMAR_WORKSHOP.SILVER.AMAR_WORKSHOP ARGS='build';"
DBT_SNAPSHOT = "EXECUTE DBT PROJECT AMAR_WORKSHOP.SILVER.AMAR_WORKSHOP ARGS='snapshot';"
DQ_GATE = "CALL AMAR_WORKSHOP.GOLD.SP_DQ_GATE();"

with DAG(
    dag_id="amar_pipeline_end_to_end",
    description="Ingest S3->Bronze, transform via dbt-on-Snowflake, DQ gate, notify",
    default_args=default_args,
    schedule="@daily",
    start_date=datetime(2026, 6, 1),
    catchup=False,
    tags=["amar", "fsi", "workshop"],
) as dag:

    common = dict(
        conn_id=SNOWFLAKE_CONN_ID,
        hook_params={"warehouse": WAREHOUSE, "database": DATABASE},
    )

    with TaskGroup(group_id="ingest_bronze") as ingest:
        SQLExecuteQueryOperator(task_id="copy_customers", sql=COPY_CUSTOMERS, **common)
        SQLExecuteQueryOperator(task_id="copy_loans", sql=COPY_LOANS, **common)
        SQLExecuteQueryOperator(task_id="copy_repayments", sql=COPY_REPAYMENTS, **common)
        SQLExecuteQueryOperator(task_id="copy_savings", sql=COPY_SAVINGS, **common)
        SQLExecuteQueryOperator(task_id="copy_transactions", sql=COPY_TRANSACTIONS, **common)

    dbt_run = SQLExecuteQueryOperator(task_id="execute_dbt_project_build", sql=DBT_BUILD, **common)
    dbt_snapshot = SQLExecuteQueryOperator(task_id="execute_dbt_project_snapshot", sql=DBT_SNAPSHOT, **common)
    dq_gate = SQLExecuteQueryOperator(task_id="dq_gate", sql=DQ_GATE, **common)

    # Data pipeline end-to-end:
    # COPY INTO (Bronze)  ->  EXECUTE DBT PROJECT snapshot (SCD-2)
    #                     ->  EXECUTE DBT PROJECT build (Silver + Gold)  ->  DQ gate
    ingest >> dbt_snapshot >> dbt_run >> dq_gate
