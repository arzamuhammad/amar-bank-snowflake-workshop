-- =====================================================================
-- 06_cortex_ai.sql  |  Amar Bank Workshop  |  Session 6 (Conversational AI)
-- 1) Cortex Analyst  -> Semantic View over GOLD marts (NL-to-SQL)
-- 2) Cortex Search   -> semantic search over product/SOP documents
-- 3) Snowflake Intelligence -> agent combining Analyst + Search (UI)
-- Run AFTER dbt has built the GOLD marts.
-- =====================================================================
USE DATABASE AMAR_WORKSHOP;
USE SCHEMA GOLD;
USE WAREHOUSE AMAR_WORKSHOP_WH;

-- ---------------------------------------------------------------------
-- 1) SEMANTIC VIEW for Cortex Analyst
-- ---------------------------------------------------------------------
CREATE OR REPLACE SEMANTIC VIEW AMAR_WORKSHOP.GOLD.SV_LOAN_PORTFOLIO
  TABLES (
    loans AS AMAR_WORKSHOP.GOLD.MART_LOAN_PERFORMANCE
      PRIMARY KEY (loan_id)
      WITH SYNONYMS ('pinjaman', 'kredit')
      COMMENT = 'Loan-level performance',
    customers AS AMAR_WORKSHOP.GOLD.MART_CUSTOMER_360
      PRIMARY KEY (customer_id)
      WITH SYNONYMS ('nasabah', 'customer')
      COMMENT = 'Customer 360'
  )
  RELATIONSHIPS (
    loans_to_customers AS loans (customer_id) REFERENCES customers (customer_id)
  )
  FACTS (
    loans.outstanding AS outstanding,
    loans.plafond AS plafond,
    loans.is_default AS is_default
  )
  DIMENSIONS (
    loans.product_segment AS product_segment WITH SYNONYMS ('produk', 'segmen produk'),
    loans.dpd_bucket AS dpd_bucket WITH SYNONYMS ('bucket dpd', 'tunggakan'),
    loans.status AS status,
    customers.province AS province WITH SYNONYMS ('provinsi', 'wilayah'),
    customers.segment AS segment WITH SYNONYMS ('segmen nasabah'),
    customers.city AS city WITH SYNONYMS ('kota')
  )
  METRICS (
    loans.total_loans AS COUNT(loans.loan_id) COMMENT = 'Jumlah pinjaman',
    loans.npl_rate AS AVG(loans.is_default) COMMENT = 'NPL rate (0-1)',
    loans.total_outstanding AS SUM(loans.outstanding) COMMENT = 'Total outstanding',
    customers.total_customers AS COUNT(customers.customer_id) COMMENT = 'Jumlah nasabah',
    customers.total_savings AS SUM(customers.total_savings_balance) COMMENT = 'Total saldo tabungan'
  )
  COMMENT = 'Amar Bank loan portfolio & customer semantic view for Cortex Analyst';

-- Inspect
SHOW SEMANTIC VIEWS IN SCHEMA AMAR_WORKSHOP.GOLD;
-- DESCRIBE SEMANTIC VIEW AMAR_WORKSHOP.GOLD.SV_LOAN_PORTFOLIO;

-- ---------------------------------------------------------------------
-- 2) CORTEX SEARCH over product / SOP documents
-- ---------------------------------------------------------------------
CREATE OR REPLACE TABLE AMAR_WORKSHOP.GOLD.PRODUCT_DOCS (
    doc_id   STRING,
    title    STRING,
    category STRING,
    content  STRING
);

INSERT INTO AMAR_WORKSHOP.GOLD.PRODUCT_DOCS VALUES
('DOC001','Tunaiku - Pinjaman Tanpa Agunan','Produk',
 'Tunaiku adalah produk pinjaman digital tanpa agunan dari Amar Bank. Plafon Rp 2 juta hingga Rp 100 juta, tenor 3 sampai 36 bulan. Pengajuan via aplikasi, pencairan cepat. Bunga flat per bulan sesuai profil risiko nasabah.'),
('DOC002','Senyumku - Tabungan Digital','Produk',
 'Senyumku adalah tabungan digital tanpa biaya admin dengan bunga kompetitif. Tersedia fitur celengan otomatis dan deposito. Pembukaan rekening 100% online dengan verifikasi e-KYC.'),
('DOC003','SOP Penagihan (Collection)','SOP',
 'Penagihan dilakukan bertahap berdasarkan Days Past Due (DPD). DPD 1-30 reminder via aplikasi dan WhatsApp. DPD 31-60 telepon collection. DPD 61-90 kunjungan. DPD di atas 90 hari masuk proses write-off dan restrukturisasi.'),
('DOC004','SOP KYC & Anti Fraud','SOP',
 'Verifikasi identitas wajib menggunakan NIK 16 digit dan e-KYC. Transaksi mencurigakan dipantau berdasarkan channel dan pola. NPWP diperlukan untuk plafon besar. Data PII wajib dimasking untuk role non-auditor.'),
('DOC005','Kebijakan Credit Scoring','Kebijakan',
 'Credit score nasabah berkisar 300-850. Skor di bawah 580 dikategorikan risiko tinggi. Keputusan kredit mempertimbangkan skor, penghasilan bulanan, dan riwayat pembayaran cicilan.');

CREATE OR REPLACE CORTEX SEARCH SERVICE AMAR_WORKSHOP.GOLD.CSS_PRODUCT_DOCS
  ON content
  ATTRIBUTES title, category
  WAREHOUSE = AMAR_WORKSHOP_WH
  TARGET_LAG = '1 hour'
  AS (
    SELECT doc_id, title, category, content
    FROM AMAR_WORKSHOP.GOLD.PRODUCT_DOCS
  );

-- Test the search service
SELECT PARSE_JSON(
  SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
    'AMAR_WORKSHOP.GOLD.CSS_PRODUCT_DOCS',
    '{"query": "bagaimana proses penagihan kredit macet?", "columns":["title","content"], "limit":3}'
  )
)['results'] AS results;

-- ---------------------------------------------------------------------
-- 3) SNOWFLAKE INTELLIGENCE agent (create in Snowsight UI)
--    Snowsight > AI & ML > Snowflake Intelligence > Create agent
--    Add tools:
--      - Cortex Analyst -> Semantic View  AMAR_WORKSHOP.GOLD.SV_LOAN_PORTFOLIO
--      - Cortex Search   -> Service        AMAR_WORKSHOP.GOLD.CSS_PRODUCT_DOCS
--    Sample questions:
--      "Berapa NPL rate per segmen produk?"
--      "Provinsi mana dengan outstanding terbesar?"
--      "Jelaskan SOP penagihan untuk DPD di atas 90 hari"
-- ---------------------------------------------------------------------
