# Amar Bank — Snowflake Data Engineering Workshop

Hands-on workshop materials for **PT Bank Amar Indonesia Tbk** (digital bank — Tunaiku, Senyumku, SMB).
Audience: **Data Engineers**. Tools: **Apache Airflow** (orchestration) + **dbt Projects on Snowflake** (transformation).

> ⚠️ All data here is **synthetic** (generated). No real customer/PII data.

---

## Architecture

```
Airflow (local, Docker)              AWS S3 (public, workshop only)        Snowflake
─────────────────────                ──────────────────────────────       ───────────────────────────
 DAG: ingest  ──COPY INTO──────────▶  customers/loans/... .csv  ──stage──▶  BRONZE.RAW_*  (landing)
 DAG: pipeline                                                              SILVER.STG_* / DIM_*_SCD2  (dbt)
   └─ EXECUTE DBT PROJECT ──────────────────────────────────────────────▶  GOLD.MART_*                (dbt)
   └─ CALL SP_DQ_GATE  (data-quality gate)                                  + Governance (mask/RAP/DMF)
```

**Orchestration is 100% in Airflow** — no Snowflake Tasks/Streams. Snowflake = compute + storage; dbt runs inside Snowflake via `EXECUTE DBT PROJECT`.

---

## Prerequisites

### 1. Airflow (local laptop) — primary focus
| Requirement | Detail |
|-------------|--------|
| **Docker Desktop** | Installed & running. RAM **≥ 8 GB** (16 GB recommended), disk ≥ 10 GB. |
| **Astro CLI** | `brew install astro` (or per OS). Used to run Airflow locally. |
| **Provider** | `apache-airflow-providers-snowflake` (in `airflow/requirements.txt`). |
| **Airflow Connection** | `snowflake_default` using **key-pair (RSA)** auth — not password. |
| **Network** | Outbound HTTPS (443) to `*.snowflakecomputing.com`. |

➡️ Full step-by-step: **[airflow/SETUP_AIRFLOW.md](airflow/SETUP_AIRFLOW.md)**

### 2. Snowflake
- Account + role with privileges to create DB/schema/warehouse, stage, policies, DMFs, roles.
- Warehouse `AMAR_WORKSHOP_WH` (created by `sql/00_setup.sql`).
- **Snowflake CLI (`snow`)** for `snow dbt deploy`.
- Key-pair public key registered on the Snowflake user (for Airflow + dbt).

### 3. AWS S3
- A **public-read** S3 bucket (workshop only) holding the files in `data/`.
- Note bucket name, region, and prefix → fill placeholders in `sql/01_ingestion.sql`.

### 4. Local tooling (optional, for dbt dev)
- Python 3.10–3.12, `pip install dbt-snowflake` if you want to run dbt outside Snowflake.

---

## Repository layout

```
.
├── data/                       # synthetic CSV/Parquet/JSON (+ schema-drift, bad-records, incremental)
├── scripts/generate_data.py    # regenerate the synthetic dataset
├── sql/
│   ├── 00_setup.sql            # DB, schemas, warehouse, file formats
│   ├── 01_ingestion.sql        # external stage (public S3) + COPY INTO Bronze
│   ├── 02_dq_checks.sql        # SP_DQ_GATE (data-quality gate called by Airflow)
│   ├── 03_governance.sql       # masking, row access, projection, DMF, RBAC
│   ├── 04_analytics.sql        # Session 2: warehouse scale + result cache
│   ├── 06_cortex_ai.sql        # Session 6: semantic view + Cortex Search
│   └── 99_prep_checklist.sql   # pre-workshop verification
├── streamlit/streamlit_app.py  # Session 2: portfolio dashboard (SiS)
├── docs/
│   ├── SESSION3_GOVERNANCE_LINEAGE.md   # lineage/Horizon + DMF review
│   └── SESSION5_CORTEX_CODE.md          # ML via Cortex Code prompting
├── DEMO_GUIDANCE.md            # step-by-step guide (Bahasa Indonesia)
├── dbt/                        # dbt Projects on Snowflake
│   ├── dbt_project.yml, profiles.yml
│   ├── models/staging/         # stg_* (views) + tests/docs
│   ├── snapshots/              # dim_customers_scd2 (SCD-2)
│   └── models/gold/            # mart_loan_performance, mart_customer_360
└── airflow/
    ├── Dockerfile, requirements.txt
    ├── SETUP_AIRFLOW.md
    └── dags/
        ├── dag_ingest_s3_to_snowflake.py     # ingest only
        └── dag_pipeline_end_to_end.py        # ingest → dbt → DQ gate
```

---

## Quick start

```bash
# 1) (optional) regenerate data
python3 scripts/generate_data.py

# 2) upload data/ to your public S3 bucket, then edit placeholders in sql/01_ingestion.sql

# 3) in Snowflake (Snowsight or snow sql): run setup + ingestion + governance
#    sql/00_setup.sql -> sql/01_ingestion.sql -> sql/03_governance.sql

# 4) deploy dbt project to Snowflake
cd dbt && snow dbt deploy AMAR_WORKSHOP --database AMAR_WORKSHOP --schema SILVER

# 5) run Airflow locally and trigger the pipeline DAG
cd ../airflow && astro dev start   # UI: http://localhost:8080
```

---

## Workshop sessions
1. **Data Engineering** (focus): ingestion (Airflow→S3→Snowflake), transformation (dbt on Snowflake), pipeline orchestration in Airflow, DQ + notifications. → `sql/00-02`, `dbt/`, `airflow/`
2. **Data Analytics**: warehouse performance, caching, Streamlit + AI. → `sql/04_analytics.sql`, `streamlit/`
3. **Data Governance**: masking, row access, projection policies, DMF, lineage (Horizon). → `sql/03_governance.sql`, `docs/SESSION3_GOVERNANCE_LINEAGE.md`
4. **Conversational AI**: Cortex Analyst + Search + Snowflake Intelligence. → `sql/06_cortex_ai.sql`
5. **ML with Cortex Code** (bonus): AI-assisted credit-scoring ML via prompting. → `docs/SESSION5_CORTEX_CODE.md`

➡️ Full instructor walkthrough: **[DEMO_GUIDANCE.md](DEMO_GUIDANCE.md)**
