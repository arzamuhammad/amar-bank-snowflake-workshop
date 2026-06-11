# DEMO GUIDANCE — Amar Bank Snowflake Workshop

Panduan ini ditujukan untuk peserta yang **belum pernah memakai Snowflake sama sekali**.
Setiap session punya panduan **terpisah dan detail** (langkah-demi-langkah, tujuan, dan
"apa yang harus dilihat" dari setiap eksekusi).

> Semua data **sintetis**. Orkestrasi pipeline **100% di Airflow** (tanpa Snowflake Tasks).
> Transformasi pakai **dbt Projects on Snowflake**.

---

## Panduan per Session

| # | Session | File Panduan | Durasi |
|---|---------|--------------|--------|
| 0 | Persiapan & Orientasi Snowflake | [guides/GUIDE_SESSION0_SETUP.md](guides/GUIDE_SESSION0_SETUP.md) | 30–45 mnt |
| 1 | Data Engineering — **3 LAB**: COPY INTO → dbt di Workspace → Airflow | [guides/GUIDE_SESSION1_DATA_ENGINEERING.md](guides/GUIDE_SESSION1_DATA_ENGINEERING.md) | 2.5–3.5 jam |
| 2 | Data Analytics + **Build Streamlit pakai AI** | [guides/GUIDE_SESSION2_ANALYTICS.md](guides/GUIDE_SESSION2_ANALYTICS.md) | 1.5–2 jam |
| 3 | Data Governance (masking, RAP, DMF, lineage) | [guides/GUIDE_SESSION3_GOVERNANCE.md](guides/GUIDE_SESSION3_GOVERNANCE.md) | 1.5–2 jam |
| 6 | Conversational AI (Cortex Analyst + Search) | [guides/GUIDE_SESSION6_CONVERSATIONAL_AI.md](guides/GUIDE_SESSION6_CONVERSATIONAL_AI.md) | 1.5 jam |
| 5 | ML with Cortex Code (bonus) | [guides/GUIDE_SESSION5_CORTEX_CODE.md](guides/GUIDE_SESSION5_CORTEX_CODE.md) | 1.5 jam |

> 🔧 **Panduan tambahan:** instalasi & konfigurasi Snowflake CLI (`snow`) yang detail ada di
> **[guides/GUIDE_SNOWCLI_SETUP.md](guides/GUIDE_SNOWCLI_SETUP.md)** (dipakai di Session 1 LAB 3).
>
> 🧩 **Opsional Session 1 — LAB 4:** membangun pipeline native pakai **Snowflake Tasks**
> (alternatif Airflow) → **[guides/GUIDE_SESSION1_OPTIONAL_TASKS.md](guides/GUIDE_SESSION1_OPTIONAL_TASKS.md)**.

**Saran agenda 2 hari:**
- **Hari 1:** Session 0 → Session 1 → Session 2.
- **Hari 2:** Session 3 → Session 6 → Session 5 (bonus).

---

## Cara membaca panduan
Setiap langkah ditulis dengan format:
- 🎯 **Tujuan** — kenapa kita melakukan ini.
- 👉 **Langkah** — apa yang harus diklik / dijalankan (sangat eksplisit).
- 👀 **Yang harus dilihat** — hasil yang diharapkan & artinya.

Mulai dari **[Session 0 — Persiapan](guides/GUIDE_SESSION0_SETUP.md)**.
