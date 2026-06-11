-- =====================================================================
-- 01_ingestion.sql  |  Amar Bank Snowflake Workshop  |  Session 1
--
-- ISI FILE INI DIBAGI 2 BAGIAN:
--   BAGIAN 1 (WAJIB, jalankan manual SEKALI): membuat STRUKTUR -> stage + tabel Bronze.
--   BAGIAN 2 (OPSIONAL): COPY INTO untuk uji manual. DI PIPELINE NYATA, COPY INTO
--            DIJALANKAN OLEH AIRFLOW (DAG amar_ingest_s3_to_snowflake / _end_to_end),
--            jadi Anda TIDAK perlu menjalankan COPY INTO di sini kalau pakai Airflow.
--
-- >>> EDIT THESE PLACEHOLDERS before running <<<
--   <<S3_BUCKET>>  e.g. amar-workshop-public
--   <<S3_PREFIX>>  e.g. data            (folder inside the bucket)
--   <<AWS_REGION>> e.g. ap-southeast-3  (only needed for storage integration)
-- =====================================================================
USE DATABASE AMAR_WORKSHOP;
USE SCHEMA BRONZE;
USE WAREHOUSE AMAR_WORKSHOP_WH;

-- #####################################################################
-- ## BAGIAN 1 - STRUKTUR (WAJIB, jalankan manual sekali)             ##
-- ## stage + tabel Bronze harus ADA sebelum Airflow bisa COPY ke sana ##
-- #####################################################################

-- ---------------------------------------------------------------------
-- OPTION A (workshop default): PUBLIC bucket, no credentials needed.
-- ---------------------------------------------------------------------
CREATE OR REPLACE STAGE BRONZE.STG_S3_AMAR
    URL = 's3://<<S3_BUCKET>>/<<S3_PREFIX>>/'
    DIRECTORY = (ENABLE = TRUE)
    COMMENT = 'Public S3 bucket with synthetic workshop data';

-- ---------------------------------------------------------------------
-- OPTION B (production pattern): Storage Integration (private bucket).
-- Uncomment + have an admin run, then use it on the stage.
-- ---------------------------------------------------------------------
-- CREATE STORAGE INTEGRATION IF NOT EXISTS AMAR_S3_INT
--     TYPE = EXTERNAL_STAGE STORAGE_PROVIDER = 'S3' ENABLED = TRUE
--     STORAGE_AWS_ROLE_ARN = 'arn:aws:iam::<acct>:role/<role>'
--     STORAGE_ALLOWED_LOCATIONS = ('s3://<<S3_BUCKET>>/<<S3_PREFIX>>/');
-- DESC INTEGRATION AMAR_S3_INT;  -- copy STORAGE_AWS_IAM_USER_ARN + EXTERNAL_ID into the IAM trust policy
-- CREATE OR REPLACE STAGE BRONZE.STG_S3_AMAR
--     STORAGE_INTEGRATION = AMAR_S3_INT
--     URL = 's3://<<S3_BUCKET>>/<<S3_PREFIX>>/';

LIST @BRONZE.STG_S3_AMAR;

-- ---------------------------------------------------------------------
-- Bronze tables (raw landing). _LOADED_AT terisi otomatis (DEFAULT) untuk audit.
-- ---------------------------------------------------------------------
CREATE OR REPLACE TABLE BRONZE.RAW_CUSTOMERS (
    customer_id    STRING,
    nik            STRING,
    npwp           STRING,
    full_name      STRING,
    gender         STRING,
    birth_date     DATE,
    province       STRING,
    city           STRING,
    segment        STRING,
    credit_score   NUMBER,
    monthly_income NUMBER,
    phone          STRING,
    email          STRING,
    created_at     TIMESTAMP_NTZ,
    updated_at     TIMESTAMP_NTZ,
    _loaded_at     TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

CREATE OR REPLACE TABLE BRONZE.RAW_LOANS (
    loan_id       STRING,
    customer_id   STRING,
    product_type  STRING,
    plafond       NUMBER,
    tenor_months  NUMBER,
    interest_rate FLOAT,
    disbursed_at  DATE,
    status        STRING,
    dpd           NUMBER,
    is_default    NUMBER,
    outstanding   NUMBER,
    updated_at    TIMESTAMP_NTZ,
    _loaded_at    TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

CREATE OR REPLACE TABLE BRONZE.RAW_REPAYMENTS (
    repayment_id STRING,
    loan_id      STRING,
    due_date     DATE,
    paid_date    DATE,
    amount_due   NUMBER,
    amount_paid  NUMBER,
    is_late      NUMBER,
    _loaded_at   TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

CREATE OR REPLACE TABLE BRONZE.RAW_SAVINGS (
    account_id    STRING,
    customer_id   STRING,
    account_type  STRING,
    balance       NUMBER,
    interest_rate FLOAT,
    opened_at     DATE,
    status        STRING,
    _loaded_at    TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

CREATE OR REPLACE TABLE BRONZE.RAW_TRANSACTIONS (
    txn_id       STRING,
    account_id   STRING,
    txn_type     STRING,
    channel      STRING,
    amount       NUMBER,
    txn_ts       TIMESTAMP_NTZ,
    _loaded_at   TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- #####################################################################
-- ## BAGIAN 2 - COPY INTO (OPSIONAL / hanya untuk uji manual)        ##
-- ##                                                                  ##
-- ## ! KALAU ANDA PAKAI AIRFLOW: LEWATI bagian ini. Airflow yang     ##
-- ##    menjalankan COPY INTO (lihat airflow/dags/...).               ##
-- ## Jalankan blok di bawah HANYA jika ingin mencoba ingest manual    ##
-- ## tanpa Airflow, atau untuk demo cepat satu kali.                  ##
-- #####################################################################
-- ---------------------------------------------------------------------
-- COPY INTO standar (tanpa transform). File header di-skip oleh FF_CSV_NOHEADER.
-- Kolom file dipetakan ke kolom tabel BERDASARKAN POSISI; kolom _loaded_at terisi
-- otomatis dari DEFAULT (ERROR_ON_COLUMN_COUNT_MISMATCH=FALSE mengizinkan selisih kolom).
COPY INTO BRONZE.RAW_CUSTOMERS
  FROM @BRONZE.STG_S3_AMAR/customers.csv
  FILE_FORMAT = (FORMAT_NAME = BRONZE.FF_CSV_NOHEADER)
  ON_ERROR = CONTINUE;

COPY INTO BRONZE.RAW_LOANS
  FROM @BRONZE.STG_S3_AMAR/loans.csv
  FILE_FORMAT = (FORMAT_NAME = BRONZE.FF_CSV_NOHEADER)
  ON_ERROR = CONTINUE;

COPY INTO BRONZE.RAW_REPAYMENTS
  FROM @BRONZE.STG_S3_AMAR/repayments.csv
  FILE_FORMAT = (FORMAT_NAME = BRONZE.FF_CSV_NOHEADER)
  ON_ERROR = CONTINUE;

COPY INTO BRONZE.RAW_SAVINGS
  FROM @BRONZE.STG_S3_AMAR/savings.csv
  FILE_FORMAT = (FORMAT_NAME = BRONZE.FF_CSV_NOHEADER)
  ON_ERROR = CONTINUE;

COPY INTO BRONZE.RAW_TRANSACTIONS
  FROM @BRONZE.STG_S3_AMAR/transactions.csv
  FILE_FORMAT = (FORMAT_NAME = BRONZE.FF_CSV_NOHEADER)
  ON_ERROR = CONTINUE;

-- ---------------------------------------------------------------------
-- DEMO: file formats (Parquet + semi-structured JSON)
-- ---------------------------------------------------------------------
-- SELECT $1 FROM @BRONZE.STG_S3_AMAR/transactions.parquet (FILE_FORMAT => BRONZE.FF_PARQUET) LIMIT 10;
-- SELECT $1 FROM @BRONZE.STG_S3_AMAR/savings.json (FILE_FORMAT => BRONZE.FF_JSON) LIMIT 10;

-- ---------------------------------------------------------------------
-- DEMO: Schema Evolution (customers_v2 adds loyalty_tier, referral_code)
-- ---------------------------------------------------------------------
-- ALTER TABLE BRONZE.RAW_CUSTOMERS SET ENABLE_SCHEMA_EVOLUTION = TRUE;
-- COPY INTO BRONZE.RAW_CUSTOMERS
--   FROM @BRONZE.STG_S3_AMAR/customers_v2_schemadrift.csv
--   FILE_FORMAT = (FORMAT_NAME = BRONZE.FF_CSV)          -- PARSE_HEADER=TRUE
--   MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE ON_ERROR = CONTINUE;
-- (schema evolution memakai MATCH_BY_COLUMN_NAME TANPA transform SELECT -> valid)
-- (kolom baru muncul otomatis; baris lama jadi NULL)

-- ---- Quick verification ----------------------------------------------
SELECT 'RAW_CUSTOMERS' t, COUNT(*) n FROM BRONZE.RAW_CUSTOMERS
UNION ALL SELECT 'RAW_LOANS', COUNT(*) FROM BRONZE.RAW_LOANS
UNION ALL SELECT 'RAW_REPAYMENTS', COUNT(*) FROM BRONZE.RAW_REPAYMENTS
UNION ALL SELECT 'RAW_SAVINGS', COUNT(*) FROM BRONZE.RAW_SAVINGS
UNION ALL SELECT 'RAW_TRANSACTIONS', COUNT(*) FROM BRONZE.RAW_TRANSACTIONS;
