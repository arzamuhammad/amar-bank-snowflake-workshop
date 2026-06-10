# Session 3 — Lineage (Horizon) & DMF Review

> Governance SQL inti (masking, row access, projection, DMF, RBAC) ada di `sql/03_governance.sql`.
> Dokumen ini melengkapi bagian **Lineage** dan **review hasil DMF** yang dilakukan via Snowsight UI.

---

## A. Data Lineage (Snowflake Horizon)

Tujuan: menelusuri aliran data **S3 → BRONZE → SILVER → GOLD** dan melakukan *impact analysis*.

**Langkah (Snowsight UI):**
1. Buka **Snowsight → Catalog → Database Explorer** (atau **Governance → Lineage**).
2. Pilih objek, mis. `AMAR_WORKSHOP.GOLD.MART_CUSTOMER_360`.
3. Klik tab **Lineage**. Akan tampak graf:
   ```
   @STG_S3_AMAR (S3)  →  BRONZE.RAW_CUSTOMERS  →  SILVER.STG_CUSTOMERS  →  GOLD.MART_CUSTOMER_360
                          BRONZE.RAW_LOANS      →  SILVER.STG_LOANS      ↗
                          BRONZE.RAW_SAVINGS    →  SILVER.STG_SAVINGS    ↗
                          BRONZE.RAW_TRANSACTIONS → SILVER.STG_TRANSACTIONS ↗
   ```
4. **Upstream** = sumber; **Downstream** = konsumen (mis. semantic view, Streamlit).

**Impact analysis (talking point):** "Kalau kolom `province` di Bronze berubah, objek apa saja yang terdampak?" → lihat downstream dari `RAW_CUSTOMERS`.

**Via SQL (opsional):**
```sql
SELECT * FROM TABLE(SNOWFLAKE.CORE.GET_LINEAGE(
  'AMAR_WORKSHOP.GOLD.MART_CUSTOMER_360', 'TABLE', 'UPSTREAM', 5));
```

---

## B. Review hasil Data Metric Functions (DMF)

DMF sudah di-attach di `sql/03_governance.sql` (NULL_COUNT, DUPLICATE_COUNT, custom credit-score range) dengan schedule `TRIGGER_ON_CHANGES`.

**Lihat hasil pengukuran:**
```sql
SELECT measurement_time, metric_name, table_name, column_names, value
FROM TABLE(SNOWFLAKE.LOCAL.DATA_QUALITY_MONITORING_RESULTS(
  REF_ENTITY_NAME   => 'AMAR_WORKSHOP.SILVER.STG_CUSTOMERS',
  REF_ENTITY_DOMAIN => 'TABLE'))
ORDER BY measurement_time DESC;
```

**Demo memunculkan pelanggaran (gunakan data bad-records):**
1. Load `data/customers_badrecords.csv` ke Bronze (NIK invalid, score out-of-range, duplikat).
2. Jalankan ulang dbt build → `STG_CUSTOMERS` ter-refresh → DMF terpicu.
3. Lihat `DMF_CREDIT_SCORE_RANGE > 0` dan `DUPLICATE_COUNT > 0`.
4. Hubungkan ke **Alert / notifikasi** (di workshop ini alerting ada di Airflow / `SP_DQ_GATE`).

**Talking points ke audience DE:**
- DMF = *data quality as code*, terjadwal & ter-audit di Snowflake.
- Masking + Row Access + Projection = perlindungan PII berlapis berbasis role.
- Lineage = kepercayaan & impact analysis tanpa tool eksternal.
