-- =====================================================================
-- 00_setup.sql  |  Amar Bank Snowflake Workshop
-- Database, schemas, warehouse, and file formats.
-- Run ONCE by an admin (ACCOUNTADMIN / SYSADMIN) before the workshop.
-- =====================================================================

-- ---- Warehouse (lab compute) -----------------------------------------
CREATE WAREHOUSE IF NOT EXISTS AMAR_WORKSHOP_WH
    WAREHOUSE_SIZE = 'SMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'Amar Bank workshop warehouse';

-- ---- Database & medallion schemas ------------------------------------
CREATE DATABASE IF NOT EXISTS AMAR_WORKSHOP
    COMMENT = 'Amar Bank hands-on workshop (synthetic data only)';

USE DATABASE AMAR_WORKSHOP;

CREATE SCHEMA IF NOT EXISTS BRONZE     COMMENT = 'Raw landed data from S3 (COPY INTO)';
CREATE SCHEMA IF NOT EXISTS SILVER     COMMENT = 'dbt staging + SCD-2 dimensions';
CREATE SCHEMA IF NOT EXISTS GOLD       COMMENT = 'dbt marts (business-ready)';
CREATE SCHEMA IF NOT EXISTS GOVERNANCE COMMENT = 'Tags, policies, DMFs, RBAC';

USE SCHEMA BRONZE;
USE WAREHOUSE AMAR_WORKSHOP_WH;

-- ---- File formats ----------------------------------------------------
CREATE OR REPLACE FILE FORMAT BRONZE.FF_CSV
    TYPE = CSV
    PARSE_HEADER = TRUE
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    TRIM_SPACE = TRUE
    NULL_IF = ('', 'NULL', 'null')
    ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE
    COMMENT = 'CSV with header (use MATCH_BY_COLUMN_NAME on COPY)';

CREATE OR REPLACE FILE FORMAT BRONZE.FF_CSV_NOHEADER
    TYPE = CSV
    SKIP_HEADER = 1
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    TRIM_SPACE = TRUE
    NULL_IF = ('', 'NULL', 'null')
    ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE;

CREATE OR REPLACE FILE FORMAT BRONZE.FF_PARQUET TYPE = PARQUET;

CREATE OR REPLACE FILE FORMAT BRONZE.FF_JSON TYPE = JSON STRIP_OUTER_ARRAY = FALSE;

SHOW FILE FORMATS IN SCHEMA BRONZE;
