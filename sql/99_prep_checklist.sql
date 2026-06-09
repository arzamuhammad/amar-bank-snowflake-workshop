-- =====================================================================
-- 99_prep_checklist.sql  |  Amar Bank Workshop
-- Run before the workshop to verify everything is in place.
-- =====================================================================
USE DATABASE AMAR_WORKSHOP;
USE WAREHOUSE AMAR_WORKSHOP_WH;

-- Objects
SHOW SCHEMAS IN DATABASE AMAR_WORKSHOP;
SHOW TABLES IN SCHEMA BRONZE;
SHOW STAGES IN SCHEMA BRONZE;
SHOW FILE FORMATS IN SCHEMA BRONZE;

-- Stage reachable + files present
LIST @BRONZE.STG_S3_AMAR;

-- Row counts (after a pipeline run)
SELECT 'RAW_CUSTOMERS' t, COUNT(*) n FROM BRONZE.RAW_CUSTOMERS
UNION ALL SELECT 'RAW_LOANS', COUNT(*) FROM BRONZE.RAW_LOANS
UNION ALL SELECT 'RAW_REPAYMENTS', COUNT(*) FROM BRONZE.RAW_REPAYMENTS
UNION ALL SELECT 'RAW_SAVINGS', COUNT(*) FROM BRONZE.RAW_SAVINGS
UNION ALL SELECT 'RAW_TRANSACTIONS', COUNT(*) FROM BRONZE.RAW_TRANSACTIONS;

-- dbt outputs present?
-- SHOW TABLES IN SCHEMA SILVER;
-- SHOW TABLES IN SCHEMA GOLD;

-- DQ gate
-- CALL GOLD.SP_DQ_GATE();

-- Roles
SHOW ROLES LIKE 'AMAR_%';
