# DEMO GUIDANCE — Amar Bank Snowflake Workshop (Bahasa Indonesia)

Panduan langkah-demi-langkah untuk instruktur. Audience: **Data Engineer**.
Orkestrasi **100% di Airflow** (tanpa Snowflake Tasks). Transform via **dbt Projects on Snowflake**.

> Semua data **sintetis**. Repo: lihat `README.md`. Prereq Airflow: `airflow/SETUP_AIRFLOW.md`.

---

## Urutan & estimasi waktu (2 hari)

| Hari | Session | Materi | File |
|------|---------|--------|------|
| 1 | **1 — Data Engineering** | Ingestion + dbt + pipeline Airflow + DQ | `sql/00-02`, `dbt/`, `airflow/` |
| 1 | **2 — Analytics** | Warehouse perf, cache, Streamlit | `sql/04`, `streamlit/` |
| 2 | **3 — Governance** | Masking, RAP, projection, DMF, lineage | `sql/03`, `docs/SESSION3_*` |
| 2 | **6 — Conversational AI** | Cortex Analyst + Search + Intelligence | `sql/06` |
| 2 | **5 — ML w/ Cortex Code** (bonus) | Prompting ML | `docs/SESSION5_*` |

---

## PERSIAPAN (H-1)

1. Jalankan `sql/00_setup.sql` (DB, schema, warehouse, file format).
2. Upload folder `data/` ke S3 bucket publik. Catat bucket+prefix.
3. Edit placeholder `<<S3_BUCKET>>` / `<<S3_PREFIX>>` di `sql/01_ingestion.sql`.
4. Deploy dbt: `cd dbt && snow dbt deploy AMAR_WORKSHOP --database AMAR_WORKSHOP --schema SILVER`.
5. Siapkan Airflow lokal (Astro) + connection key-pair (`airflow/SETUP_AIRFLOW.md`).
6. Verifikasi dengan `sql/99_prep_checklist.sql`.

---

## SESSION 1 — Data Engineering

**1.1 Ingestion (Airflow → S3 → Bronze)**
- Jalankan `sql/01_ingestion.sql` (buat stage + tabel Bronze + COPY INTO).
- Di Airflow UI, trigger DAG `amar_ingest_s3_to_snowflake`. Tunjukkan tiap task `copy_*`.
- Talking point: `MATCH_BY_COLUMN_NAME`, `_LOADED_AT`/`_SOURCE_FILE` untuk lineage.
- Demo **schema evolution**: bagian komentar di `01_ingestion.sql` (load `customers_v2_schemadrift.csv`).

**1.2 Transform (dbt Projects on Snowflake)**
- Tunjukkan struktur `dbt/`: staging (views) → snapshot SCD-2 → gold marts.
- Jalankan via DAG `amar_pipeline_end_to_end` (task `dbt_build`, `dbt_snapshot_scd2`).
- Tunjukkan **tests** (not_null, unique, accepted_values, relationships).

**1.3 Pipeline & DQ (orkestrasi di Airflow)**
- Tunjukkan graf DAG: `ingest_bronze → dbt_snapshot → dbt_build → dq_gate`.
- `dq_gate` memanggil `GOLD.SP_DQ_GATE()` (`sql/02_dq_checks.sql`).
- Talking point: **kenapa Airflow, bukan Snowflake Tasks** → satu orchestrator, retry/alert/dependency terpusat; Snowflake = compute.

**1.4 Notifikasi & monitoring**
- Sukses/gagal via callback Airflow + log per task. (Opsional: notification integration email di `02_dq_checks.sql`.)

---

## SESSION 2 — Data Analytics

**2.1 Query** (`sql/04_analytics.sql`): NPL per segmen, DPD distribution, top provinsi.
**2.2 Warehouse performance:** jalankan query berat di XSMALL → scale up ke LARGE → bandingkan durasi di **Query Profile**.
**2.3 Result cache:** `USE_CACHED_RESULT=TRUE`, jalankan query 2x → run kedua instan, 0 compute.
**2.4 Streamlit:** deploy `streamlit/streamlit_app.py` (Snowsight Streamlit / `snow streamlit deploy`). Tunjukkan KPI + chart dari GOLD marts. Demo *AI-assist* untuk generate chart baru.

---

## SESSION 3 — Data Governance

Jalankan `sql/03_governance.sql` lalu uji dengan berganti role:
- **Masking:** `USE ROLE AMAR_ANALYST; SELECT nik,email,phone,monthly_income FROM SILVER.STG_CUSTOMERS;` → tersamarkan. Bandingkan dengan `ACCOUNTADMIN`.
- **Row Access:** ANALYST hanya melihat `province='DKI Jakarta'`.
- **Projection:** ANALYST tidak bisa SELECT kolom `nik`.
- **DMF & Lineage:** ikuti `docs/SESSION3_GOVERNANCE_LINEAGE.md`.

---

## SESSION 6 — Conversational AI

Jalankan `sql/06_cortex_ai.sql`:
1. **Semantic View** `SV_LOAN_PORTFOLIO` untuk Cortex Analyst.
2. **Cortex Search** `CSS_PRODUCT_DOCS` atas dokumen produk/SOP (uji `SEARCH_PREVIEW`).
3. **Snowflake Intelligence** (Snowsight UI): buat agent, tambahkan tool Analyst (semantic view) + Search (service).
- Pertanyaan contoh: "Berapa NPL rate per segmen produk?", "Provinsi mana outstanding terbesar?", "Jelaskan SOP penagihan DPD > 90 hari".

---

## SESSION 5 — ML with Cortex Code (bonus)

Ikuti `docs/SESSION5_CORTEX_CODE.md`: prompting bertahap (EDA → fitur → train → registry → inference → SHAP) memprediksi `ever_default` dari `MART_CUSTOMER_360`.

---

## BAU / Skenario nyata (nilai jual DE)
- **Bad records:** load `customers_badrecords.csv` → DQ gate gagal → Airflow retry/alert → quarantine.
- **Backdated/incremental:** load `loans_incremental.csv` → dbt incremental + Time Travel.
- **Re-run:** trigger ulang DAG dari task tertentu di Airflow.

---

## SUSPEND RESOURCES (setelah workshop)
```sql
ALTER WAREHOUSE AMAR_WORKSHOP_WH SUSPEND;
-- (opsional bersih-bersih)
-- DROP DATABASE AMAR_WORKSHOP;
```
Di Airflow: `astro dev stop`.

---

## Troubleshooting ringkas
| Masalah | Solusi |
|---------|--------|
| COPY 0 rows | `LIST @BRONZE.STG_S3_AMAR;` cek URL bucket/prefix |
| `EXECUTE DBT PROJECT` not found | `snow dbt deploy` dulu |
| Airflow conn gagal | cek key-pair + role + account `ORG-ACCOUNT` |
| Semantic view error | pastikan GOLD marts sudah dibangun dbt |
| Masking tak berubah | pastikan `USE ROLE` benar (ANALYST vs ACCOUNTADMIN) |
