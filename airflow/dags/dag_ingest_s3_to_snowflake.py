"""
DAG: amar_ingest_s3_to_snowflake
Ingestion-only DAG (Session 1, step 1). Loads the 5 Bronze tables from the
public S3 stage. Good first hands-on before adding dbt transform.
"""
from datetime import datetime, timedelta

from airflow import DAG
from airflow.providers.snowflake.operators.snowflake import SnowflakeOperator

SNOWFLAKE_CONN_ID = "snowflake_default"

default_args = {"owner": "data_engineering", "retries": 1, "retry_delay": timedelta(minutes=1)}

TABLES = {
    "customers": "customers.csv",
    "loans": "loans.csv",
    "repayments": "repayments.csv",
    "savings": "savings.csv",
    "transactions": "transactions.csv",
}

# Minimal COPY (relies on table column order + MATCH_BY_COLUMN_NAME via header)
def copy_sql(table, file):
    return f"""
    COPY INTO AMAR_WORKSHOP.BRONZE.RAW_{table.upper()}
    FROM @AMAR_WORKSHOP.BRONZE.STG_S3_AMAR/{file}
    FILE_FORMAT=(FORMAT_NAME=AMAR_WORKSHOP.BRONZE.FF_CSV)
    MATCH_BY_COLUMN_NAME=CASE_INSENSITIVE ON_ERROR=CONTINUE;
    """

with DAG(
    dag_id="amar_ingest_s3_to_snowflake",
    description="COPY INTO Bronze tables from public S3 stage",
    default_args=default_args,
    schedule=None,
    start_date=datetime(2026, 6, 1),
    catchup=False,
    tags=["amar", "fsi", "workshop", "ingestion"],
) as dag:
    for tbl, fname in TABLES.items():
        SnowflakeOperator(
            task_id=f"copy_{tbl}",
            sql=copy_sql(tbl, fname),
            snowflake_conn_id=SNOWFLAKE_CONN_ID,
            warehouse="AMAR_WORKSHOP_WH",
            database="AMAR_WORKSHOP",
        )
