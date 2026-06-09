-- =====================================================================
-- 02_dq_checks.sql  |  Amar Bank Workshop  |  Session 1 (pipeline)
-- Data-quality gate called BY AIRFLOW (not by a Snowflake Task).
-- The SP returns a JSON verdict and RAISES on failure so the Airflow
-- task fails -> Airflow handles retry / notification.
-- =====================================================================
USE DATABASE AMAR_WORKSHOP;
USE SCHEMA GOLD;
USE WAREHOUSE AMAR_WORKSHOP_WH;

CREATE OR REPLACE PROCEDURE GOLD.SP_DQ_GATE()
RETURNS VARIANT
LANGUAGE SQL
AS
$$
DECLARE
    bad_nik       INT;
    bad_score     INT;
    dup_customer  INT;
    null_segment  INT;
    orphan_loans  INT;
    verdict       VARIANT;
    total_issues  INT;
BEGIN
    -- NIK must be 16 digits
    SELECT COUNT(*) INTO :bad_nik
      FROM SILVER.STG_CUSTOMERS WHERE LENGTH(nik) <> 16 OR NOT nik RLIKE '^[0-9]+$';

    -- credit score range 300-850
    SELECT COUNT(*) INTO :bad_score
      FROM SILVER.STG_CUSTOMERS WHERE credit_score < 300 OR credit_score > 850;

    -- duplicate customer ids
    SELECT COUNT(*) INTO :dup_customer FROM (
        SELECT customer_id FROM SILVER.STG_CUSTOMERS GROUP BY customer_id HAVING COUNT(*) > 1
    );

    -- mandatory segment
    SELECT COUNT(*) INTO :null_segment
      FROM SILVER.STG_CUSTOMERS WHERE segment IS NULL OR segment = '';

    -- referential integrity: loans must reference a known customer
    SELECT COUNT(*) INTO :orphan_loans
      FROM SILVER.STG_LOANS l
      LEFT JOIN SILVER.STG_CUSTOMERS c ON l.customer_id = c.customer_id
      WHERE c.customer_id IS NULL;

    total_issues := :bad_nik + :bad_score + :dup_customer + :null_segment + :orphan_loans;

    verdict := OBJECT_CONSTRUCT(
        'checked_at', CURRENT_TIMESTAMP()::STRING,
        'bad_nik', :bad_nik,
        'bad_credit_score', :bad_score,
        'duplicate_customer_id', :dup_customer,
        'null_segment', :null_segment,
        'orphan_loans', :orphan_loans,
        'total_issues', :total_issues,
        'status', IFF(:total_issues = 0, 'PASS', 'FAIL')
    );

    IF (:total_issues > 0) THEN
        RETURN OBJECT_INSERT(:verdict, 'raised', TRUE);
        -- NOTE: to hard-fail the Airflow task, uncomment the next line instead:
        -- RAISE STATEMENT_ERROR;
    END IF;

    RETURN :verdict;
END;
$$;

-- Call it (Airflow: SQLExecuteQueryOperator -> CALL GOLD.SP_DQ_GATE();)
CALL GOLD.SP_DQ_GATE();

-- ---------------------------------------------------------------------
-- OPTIONAL: email notification integration (admin-created once).
-- Airflow normally owns alerting, but this lets a SP email directly.
-- ---------------------------------------------------------------------
-- CREATE OR REPLACE NOTIFICATION INTEGRATION AMAR_EMAIL_INT
--     TYPE = EMAIL ENABLED = TRUE
--     ALLOWED_RECIPIENTS = ('<<NOTIFY_EMAIL>>');
-- CALL SYSTEM$SEND_EMAIL('AMAR_EMAIL_INT', '<<NOTIFY_EMAIL>>',
--     'Amar pipeline DQ result', 'See dashboard for details.');
