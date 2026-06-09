# SETUP_AIRFLOW.md — Menjalankan Apache Airflow di Laptop Lokal

> Orkestrasi pipeline workshop ini **100% di Airflow** (tanpa Snowflake Tasks).
> Airflow men-trigger `COPY INTO` (ingest) dan `EXECUTE DBT PROJECT` (transform) di Snowflake.

---

## A. Prasyarat (Prerequisites) — WAJIB sebelum hari-H

### Hardware / OS
- Laptop **RAM minimal 8 GB** (disarankan 16 GB) — Airflow jalan di Docker.
- Disk kosong **≥ 10 GB**.
- OS: macOS / Linux / Windows (WSL2).

### Software
| Tool | Versi | Cek |
|------|-------|-----|
| **Docker Desktop** | terbaru, status *Running* | `docker --version` |
| **Astro CLI** (disarankan) | ≥ 1.28 | `astro version` |
| Python | 3.10–3.12 (untuk dbt lokal opsional) | `python3 --version` |
| Snowflake CLI (`snow`) | terbaru (untuk `snow dbt deploy`) | `snow --version` |
| Git | terbaru | `git --version` |

Install Astro CLI:
```bash
# macOS
brew install astro
# Linux / Windows: lihat https://www.astronomer.io/docs/astro/cli/install-cli
```

### Akses & Kredensial
- **Akun Snowflake** workshop + **warehouse** `AMAR_WORKSHOP_WH`.
- **Key-pair (RSA)** untuk auth Airflow→Snowflake (BUKAN password). Generate:
  ```bash
  openssl genrsa 2048 | openssl pkcs8 -topk8 -inform PEM -out snowflake_key.p8 -nocrypt
  openssl rsa -in snowflake_key.p8 -pubout -out snowflake_key.pub
  ```
  Lalu daftarkan public key ke user Snowflake:
  ```sql
  ALTER USER <user> SET RSA_PUBLIC_KEY='<isi snowflake_key.pub tanpa header/footer>';
  ```
- **Outbound HTTPS (443)** ke `*.snowflakecomputing.com` (cek firewall/proxy kantor).
- **S3 bucket publik** workshop sudah berisi data (lihat `data/`).

---

## B. Menjalankan Airflow Lokal (Astro CLI)

1. Dari folder `airflow/`:
   ```bash
   cd airflow
   astro dev start
   ```
   Airflow UI: <http://localhost:8080> (user/pass: `admin`/`admin`).

2. Struktur yang dipakai Astro:
   - `dags/` → DAG workshop (sudah ada).
   - `requirements.txt` → provider Snowflake (sudah ada).
   - `Dockerfile` → base image Astro Runtime.

> **Alternatif tanpa Astro:** `pip install -r requirements.txt` lalu `airflow standalone`
> (lebih ringan, tapi rawan konflik dependency). Astro lebih direkomendasikan.

---

## C. Membuat Connection Snowflake di Airflow

**Opsi 1 — UI:** Admin → Connections → +
- Connection Id: `snowflake_default`
- Connection Type: `Snowflake`
- Account: `<YOUR_SNOWFLAKE_ACCOUNT>` (atau akun Anda)
- Login: `<user>`
- Schema: `BRONZE`, Database: `AMAR_WORKSHOP`, Warehouse: `AMAR_WORKSHOP_WH`, Role: `AMAR_DATA_ENGINEER`
- Extra (key-pair):
  ```json
  {"private_key_file": "/usr/local/airflow/include/snowflake_key.p8"}
  ```
  (taruh file key di `airflow/include/`)

**Opsi 2 — CLI:**
```bash
astro dev run connections add snowflake_default \
  --conn-type snowflake \
  --conn-login <user> \
  --conn-schema BRONZE \
  --conn-extra '{"account":"<YOUR_SNOWFLAKE_ACCOUNT>","database":"AMAR_WORKSHOP","warehouse":"AMAR_WORKSHOP_WH","role":"AMAR_DATA_ENGINEER","private_key_file":"/usr/local/airflow/include/snowflake_key.p8"}'
```

---

## D. Deploy dbt Project ke Snowflake (sekali, sebelum DAG transform)

DAG `amar_pipeline_end_to_end` memanggil `EXECUTE DBT PROJECT`, jadi project dbt
harus sudah ter-deploy sebagai object Snowflake:
```bash
cd ../dbt
snow dbt deploy AMAR_WORKSHOP --database AMAR_WORKSHOP --schema SILVER
# verifikasi:
snow sql -q "SHOW DBT PROJECTS IN SCHEMA AMAR_WORKSHOP.SILVER;"
```

---

## E. Menjalankan Pipeline

1. Di Airflow UI, aktifkan & trigger DAG:
   - `amar_ingest_s3_to_snowflake` → ingest saja (latihan pertama), **atau**
   - `amar_pipeline_end_to_end` → ingest → dbt snapshot → dbt build → DQ gate.
2. Pantau via Grid/Graph view + Logs tiap task.
3. Verifikasi hasil di Snowflake: jalankan `sql/99_prep_checklist.sql`.

---

## F. Troubleshooting

| Gejala | Solusi |
|--------|--------|
| `astro dev start` gagal | Pastikan Docker Desktop Running; cek port 8080 tidak dipakai. |
| Connection test gagal | Cek `account` (pakai `ORG-ACCOUNT`), key-pair terdaftar, role punya akses. |
| `EXECUTE DBT PROJECT` not found | Jalankan `snow dbt deploy` dulu; cek nama project & schema. |
| COPY 0 rows | Cek `LIST @BRONZE.STG_S3_AMAR;` — URL bucket/prefix benar & file ada. |
| Provider import error | `requirements.txt` ter-install? `astro dev restart` setelah ubah requirements. |

> Catatan: Airflow lokal = untuk **belajar/dev**. Untuk produksi gunakan
> **MWAA (AWS)** / Cloud Composer / Astronomer managed.
