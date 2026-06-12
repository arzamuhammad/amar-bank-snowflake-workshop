-- =====================================================================
-- 04_analytics.sql  |  Amar Bank Workshop  |  Session 2 (Data Analytics)
-- Querying, warehouse performance (scale up/out), and result cache.
-- Runs on the GOLD marts produced by dbt.
-- =====================================================================
USE DATABASE AMAR_WORKSHOP;
USE SCHEMA GOLD;
USE WAREHOUSE AMAR_WORKSHOP_WH;

-- ---------------------------------------------------------------------
-- 1) Business queries (Data Analyst)
-- ---------------------------------------------------------------------
-- NPL rate per product segment
SELECT product_segment,
       COUNT(*)                               AS n_loans,
       SUM(is_default)                         AS n_default,
       ROUND(100 * SUM(is_default) / COUNT(*), 2) AS npl_rate_pct,
       SUM(outstanding)                        AS total_outstanding
FROM GOLD.MART_LOAN_PERFORMANCE
GROUP BY product_segment
ORDER BY npl_rate_pct DESC;

-- DPD distribution
SELECT dpd_bucket, COUNT(*) AS n_loans, SUM(outstanding) AS outstanding
FROM GOLD.MART_LOAN_PERFORMANCE
GROUP BY dpd_bucket ORDER BY 1;

-- Top provinces by customer & savings
SELECT province, COUNT(*) AS n_customers,
       SUM(total_savings_balance) AS savings_balance,
       AVG(credit_score) AS avg_score
FROM GOLD.MART_CUSTOMER_360
GROUP BY province ORDER BY n_customers DESC;

-- ---------------------------------------------------------------------
-- 2) Warehouse performance: SCALE UP (bigger WH for heavy query)
-- ---------------------------------------------------------------------
-- Run a heavy query and note duration in Query Profile.
ALTER WAREHOUSE AMAR_WORKSHOP_WH SET WAREHOUSE_SIZE = 'XSMALL';
ALTER SESSION SET USE_CACHED_RESULT = FALSE;     -- force real compute for the demo

SELECT c.province, l.product_segment,
       COUNT(*) AS loans, AVG(l.collection_ratio) AS avg_collection,
       SUM(l.outstanding) AS outstanding
FROM GOLD.MART_LOAN_PERFORMANCE l
JOIN GOLD.MART_CUSTOMER_360 c ON l.customer_id = c.customer_id
GROUP BY 1, 2 ORDER BY outstanding DESC;

-- Now scale up and re-run the SAME query; compare elapsed time.
ALTER WAREHOUSE AMAR_WORKSHOP_WH SET WAREHOUSE_SIZE = 'LARGE';
-- (re-run the query above)

-- SCALE OUT (multi-cluster) for concurrency - Enterprise+:
-- ALTER WAREHOUSE AMAR_WORKSHOP_WH SET MIN_CLUSTER_COUNT=1 MAX_CLUSTER_COUNT=3 SCALING_POLICY='STANDARD';

-- Reset to small after the demo
ALTER WAREHOUSE AMAR_WORKSHOP_WH SET WAREHOUSE_SIZE = 'SMALL';

-- ---------------------------------------------------------------------
-- 3) Result cache demo
-- ---------------------------------------------------------------------
ALTER SESSION SET USE_CACHED_RESULT = TRUE;
-- Run twice; 2nd run is near-instant & uses 0 compute (result cache).
SELECT product_segment, COUNT(*) FROM GOLD.MART_LOAN_PERFORMANCE GROUP BY 1;
SELECT product_segment, COUNT(*) FROM GOLD.MART_LOAN_PERFORMANCE GROUP BY 1;

-- Inspect: durasi & bytes_scanned (real-time, sesi ini).
-- CATATAN: INFORMATION_SCHEMA.QUERY_HISTORY_BY_SESSION() TIDAK punya kolom
-- percentage_scanned_from_cache. Kolom itu hanya ada di ACCOUNT_USAGE (lihat di bawah).
SELECT query_text, execution_status,
       total_elapsed_time, bytes_scanned
FROM TABLE(INFORMATION_SCHEMA.QUERY_HISTORY_BY_SESSION())
WHERE query_text ILIKE '%MART_LOAN_PERFORMANCE%'
ORDER BY start_time DESC LIMIT 5;

-- Untuk metrik cache (% scanned from cache), pakai ACCOUNT_USAGE
-- (butuh privilege; data ada latency hingga ~45 menit, cakupan 365 hari):
-- SELECT query_text, execution_status,
--        total_elapsed_time, bytes_scanned,
--        percentage_scanned_from_cache
-- FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
-- WHERE query_text ILIKE '%MART_LOAN_PERFORMANCE%'
-- ORDER BY start_time DESC LIMIT 5;
