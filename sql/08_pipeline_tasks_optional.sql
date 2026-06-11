-- =====================================================================
-- 08_pipeline_tasks_optional.sql  |  Amar Bank Workshop  |  Session 1 (OPSIONAL)
-- Membangun data pipeline NATIVE di Snowflake memakai TASKS — ALTERNATIF Airflow.
-- Alur sama: COPY INTO (Bronze) -> EXECUTE DBT PROJECT (snapshot+build) -> DQ gate.
--
-- Prasyarat:
--   - sql/00_setup.sql  (DB/schema/warehouse/file format) sudah dijalankan
--   - sql/01_ingestion.sql BAGIAN 1 (stage + tabel Bronze) sudah dijalankan
--   - DBT PROJECT object AMAR_WORKSHOP.SILVER.AMAR_WORKSHOP sudah ter-deploy (LAB 2)
--   - sql/02_dq_checks.sql (GOLD.SP_DQ_GATE) sudah dibuat
--   - Role punya CREATE TASK + EXECUTE TASK (ACCOUNTADMIN aman)
--
-- CATATAN: semua task dalam satu task graph WAJIB berada di schema yang sama.
--          Di sini semua task dibuat di schema BRONZE; body task boleh merujuk schema lain.
-- =====================================================================
USE DATABASE AMAR_WORKSHOP;
USE SCHEMA BRONZE;
USE WAREHOUSE AMAR_WORKSHOP_WH;

-- ---------------------------------------------------------------------
-- 1) Stored procedure: jalankan 5 COPY INTO (satu task hanya 1 statement,
--    jadi multi-COPY dibungkus dalam SP).
-- ---------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE BRONZE.SP_INGEST_BRONZE()
RETURNS STRING
LANGUAGE SQL
AS
$$
BEGIN
  COPY INTO BRONZE.RAW_CUSTOMERS    FROM @BRONZE.STG_S3_AMAR/customers.csv
       FILE_FORMAT=(FORMAT_NAME=BRONZE.FF_CSV_NOHEADER) ON_ERROR=CONTINUE;
  COPY INTO BRONZE.RAW_LOANS        FROM @BRONZE.STG_S3_AMAR/loans.csv
       FILE_FORMAT=(FORMAT_NAME=BRONZE.FF_CSV_NOHEADER) ON_ERROR=CONTINUE;
  COPY INTO BRONZE.RAW_REPAYMENTS   FROM @BRONZE.STG_S3_AMAR/repayments.csv
       FILE_FORMAT=(FORMAT_NAME=BRONZE.FF_CSV_NOHEADER) ON_ERROR=CONTINUE;
  COPY INTO BRONZE.RAW_SAVINGS      FROM @BRONZE.STG_S3_AMAR/savings.csv
       FILE_FORMAT=(FORMAT_NAME=BRONZE.FF_CSV_NOHEADER) ON_ERROR=CONTINUE;
  COPY INTO BRONZE.RAW_TRANSACTIONS FROM @BRONZE.STG_S3_AMAR/transactions.csv
       FILE_FORMAT=(FORMAT_NAME=BRONZE.FF_CSV_NOHEADER) ON_ERROR=CONTINUE;
  RETURN 'Bronze ingest selesai';
END;
$$;

-- ---------------------------------------------------------------------
-- 2) Task graph (DAG): ROOT -> snapshot -> build -> DQ
-- ---------------------------------------------------------------------
-- ROOT: terjadwal (contoh: tiap hari 02:00 WIB). Bisa diganti sesuai kebutuhan.
CREATE OR REPLACE TASK BRONZE.TASK_ROOT_INGEST
  WAREHOUSE = AMAR_WORKSHOP_WH
  SCHEDULE  = 'USING CRON 0 2 * * * Asia/Jakarta'
  COMMENT   = 'Step 1: COPY INTO semua tabel Bronze'
  AS
    CALL BRONZE.SP_INGEST_BRONZE();

-- Step 2: dbt snapshot (SCD-2) setelah ingest sukses
CREATE OR REPLACE TASK BRONZE.TASK_DBT_SNAPSHOT
  WAREHOUSE = AMAR_WORKSHOP_WH
  AFTER BRONZE.TASK_ROOT_INGEST
  AS
    EXECUTE DBT PROJECT AMAR_WORKSHOP.SILVER.AMAR_WORKSHOP ARGS='snapshot';

-- Step 3: dbt build (Silver + Gold)
CREATE OR REPLACE TASK BRONZE.TASK_DBT_BUILD
  WAREHOUSE = AMAR_WORKSHOP_WH
  AFTER BRONZE.TASK_DBT_SNAPSHOT
  AS
    EXECUTE DBT PROJECT AMAR_WORKSHOP.SILVER.AMAR_WORKSHOP ARGS='build';

-- Step 4: Data Quality gate
CREATE OR REPLACE TASK BRONZE.TASK_DQ_GATE
  WAREHOUSE = AMAR_WORKSHOP_WH
  AFTER BRONZE.TASK_DBT_BUILD
  AS
    CALL AMAR_WORKSHOP.GOLD.SP_DQ_GATE();

-- ---------------------------------------------------------------------
-- 3) Aktifkan task graph
--    PENTING: resume task ANAK dulu, baru ROOT (urutan dari bawah ke atas).
-- ---------------------------------------------------------------------
ALTER TASK BRONZE.TASK_DQ_GATE       RESUME;
ALTER TASK BRONZE.TASK_DBT_BUILD     RESUME;
ALTER TASK BRONZE.TASK_DBT_SNAPSHOT  RESUME;
ALTER TASK BRONZE.TASK_ROOT_INGEST   RESUME;

-- ---------------------------------------------------------------------
-- 4) Jalankan SEKARANG tanpa menunggu jadwal (demo)
-- ---------------------------------------------------------------------
EXECUTE TASK BRONZE.TASK_ROOT_INGEST;

-- ---------------------------------------------------------------------
-- 5) Monitoring
-- ---------------------------------------------------------------------
-- Lihat graph & status task:
SHOW TASKS IN SCHEMA BRONZE;

-- Riwayat eksekusi (1 jam terakhir):
SELECT name, state, scheduled_time, completed_time, error_message
FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY(
        SCHEDULED_TIME_RANGE_START => DATEADD('hour', -1, CURRENT_TIMESTAMP())))
ORDER BY scheduled_time DESC;

-- (Snowsight: Monitoring -> Task History / Graph untuk visual DAG)

-- ---------------------------------------------------------------------
-- 6) Membersihkan (kalau selesai / mau matikan jadwal)
-- ---------------------------------------------------------------------
-- ALTER TASK BRONZE.TASK_ROOT_INGEST   SUSPEND;
-- ALTER TASK BRONZE.TASK_DBT_SNAPSHOT  SUSPEND;
-- ALTER TASK BRONZE.TASK_DBT_BUILD     SUSPEND;
-- ALTER TASK BRONZE.TASK_DQ_GATE       SUSPEND;
-- DROP TASK BRONZE.TASK_DQ_GATE;
-- DROP TASK BRONZE.TASK_DBT_BUILD;
-- DROP TASK BRONZE.TASK_DBT_SNAPSHOT;
-- DROP TASK BRONZE.TASK_ROOT_INGEST;
-- DROP PROCEDURE BRONZE.SP_INGEST_BRONZE();
