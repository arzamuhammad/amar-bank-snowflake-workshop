"""
DAG: amar_pipeline_end_to_end
Orchestration lives ENTIRELY in Airflow (no Snowflake Tasks/Streams).

Flow:  ingest (COPY INTO Bronze)  ->  dbt build (EXECUTE DBT PROJECT)
       ->  dbt snapshot (SCD-2)   ->  DQ gate  ->  notify

Requires:
  - Airflow connection id "snowflake_default" (key-pair auth recommended)
  - provider: apache-airflow-providers-snowflake
  - dbt project deployed to Snowflake as AMAR_WORKSHOP.SILVER.AMAR_BANK_WORKSHOP
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
  FROM @AMAR_WORKSHOP.BRONZE.STG_S3_AMAR/customers.csv
  FILE_FORMAT=(FORMAT_NAME=AMAR_WORKSHOP.BRONZE.FF_CSV_NOHEADER)
  ON_ERROR=CONTINUE;
"""

COPY_LOANS = """
COPY INTO AMAR_WORKSHOP.BRONZE.RAW_LOANS
  FROM @AMAR_WORKSHOP.BRONZE.STG_S3_AMAR/loans.csv
  FILE_FORMAT=(FORMAT_NAME=AMAR_WORKSHOP.BRONZE.FF_CSV_NOHEADER)
  ON_ERROR=CONTINUE;
"""

COPY_REPAYMENTS = """
COPY INTO AMAR_WORKSHOP.BRONZE.RAW_REPAYMENTS
  FROM @AMAR_WORKSHOP.BRONZE.STG_S3_AMAR/repayments.csv
  FILE_FORMAT=(FORMAT_NAME=AMAR_WORKSHOP.BRONZE.FF_CSV_NOHEADER)
  ON_ERROR=CONTINUE;
"""

COPY_SAVINGS = """
COPY INTO AMAR_WORKSHOP.BRONZE.RAW_SAVINGS
  FROM @AMAR_WORKSHOP.BRONZE.STG_S3_AMAR/savings.csv
  FILE_FORMAT=(FORMAT_NAME=AMAR_WORKSHOP.BRONZE.FF_CSV_NOHEADER)
  ON_ERROR=CONTINUE;
"""

COPY_TRANSACTIONS = """
COPY INTO AMAR_WORKSHOP.BRONZE.RAW_TRANSACTIONS
  FROM @AMAR_WORKSHOP.BRONZE.STG_S3_AMAR/transactions.csv
  FILE_FORMAT=(FORMAT_NAME=AMAR_WORKSHOP.BRONZE.FF_CSV_NOHEADER)
  ON_ERROR=CONTINUE;
"""

# dbt Projects on Snowflake — runs transform compute inside Snowflake
# Nama project = AMAR_BANK_WORKSHOP (lihat: SHOW DBT PROJECTS IN SCHEMA AMAR_WORKSHOP.SILVER)
DBT_BUILD = "EXECUTE DBT PROJECT AMAR_WORKSHOP.SILVER.AMAR_BANK_WORKSHOP ARGS='build';"
DBT_SNAPSHOT = "EXECUTE DBT PROJECT AMAR_WORKSHOP.SILVER.AMAR_BANK_WORKSHOP ARGS='snapshot';"
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
