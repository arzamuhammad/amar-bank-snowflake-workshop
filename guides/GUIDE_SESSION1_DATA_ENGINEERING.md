# Session 1 — Data Engineering (Detail untuk Pemula)

🎯 **Tujuan besar session ini:** membangun pipeline data lengkap untuk Amar Bank:
**ambil data dari S3 → simpan di Snowflake (Bronze) → bersihkan & bentuk dengan dbt
(Silver/Gold) → semua dijalankan otomatis oleh Airflow → cek kualitas data.**

**Yang akan Anda kuasai:** stage & COPY INTO, arsitektur medallion, dbt Projects on
Snowflake, orkestrasi Airflow, dan data quality gate.

> Prasyarat: sudah selesai **Session 0**. Airflow lokal sudah jalan
> (lihat `../airflow/SETUP_AIRFLOW.md`).

---

## Peta alur Session 1
```
            (Airflow DAG menjalankan semuanya secara otomatis)
 S3 (CSV)  ──COPY INTO──►  BRONZE.RAW_*  ──dbt──►  SILVER.STG_* / SCD2  ──dbt──►  GOLD.MART_*  ──►  DQ Gate
   1.1                        1.2                      1.3                          1.4            1.5
```

---

## Bagian 1.1 — Memasukkan data dari S3 ke Bronze

### Konsep (1 menit)
- **Stage** = "pintu" antara file di S3 dan tabel Snowflake.
- **File Format** = aturan membaca file (CSV pakai header? pemisah koma?).
- **COPY INTO** = perintah menyalin isi file ke dalam tabel.
- **Bronze** = data **mentah** apa adanya (belum dibersihkan).

### Langkah

🎯 **Tujuan:** membuat stage ke bucket S3 publik & menyalin 5 file CSV ke 5 tabel Bronze.

👉 **Langkah:**
1. Pastikan data sudah diunggah ke S3 bucket publik (folder `data/` repo ini).
2. Buka `sql/01_ingestion.sql`. Ganti placeholder:
   - `<<S3_BUCKET>>` → nama bucket Anda (mis. `amar-workshop-public`)
   - `<<S3_PREFIX>>` → folder di dalam bucket (mis. `data`)
3. Jalankan bagian **CREATE STAGE** (Option A — bucket publik):
   ```sql
   CREATE OR REPLACE STAGE BRONZE.STG_S3_AMAR
       URL = 's3://amar-workshop-public/data/'
       DIRECTORY = (ENABLE = TRUE);
   ```
4. Cek isi stage:
   ```sql
   LIST @BRONZE.STG_S3_AMAR;
   ```

👀 **Yang harus dilihat:** daftar file: `customers.csv`, `loans.csv`, `repayments.csv`,
`savings.csv`, `transactions.csv`, dll. **Artinya Snowflake sudah bisa "melihat" file di S3.**

5. Jalankan bagian **CREATE TABLE** (membuat 5 tabel Bronze kosong).
6. Jalankan bagian **COPY INTO** (5 perintah).

👀 **Yang harus dilihat:** setiap COPY menampilkan status `LOADED` dengan jumlah baris,
mis. `customers.csv … 5000 rows loaded`. Lalu verifikasi:
```sql
SELECT 'RAW_CUSTOMERS' t, COUNT(*) n FROM BRONZE.RAW_CUSTOMERS
UNION ALL SELECT 'RAW_LOANS', COUNT(*) FROM BRONZE.RAW_LOANS;
```
Harus muncul: customers 5.000, loans 8.000. **Selamat, data sudah masuk Snowflake!**

> 💡 **Kenapa ini penting buat DE:** tidak perlu server ETL terpisah — cukup SQL.
> Kolom `_loaded_at` & `_source_file` otomatis terisi → berguna untuk audit & lineage.

### (Opsional) Demo Schema Evolution
🎯 **Tujuan:** menunjukkan Snowflake bisa otomatis menyesuaikan kolom baru.
👉 Jalankan blok berkomentar di `01_ingestion.sql` yang me-load `customers_v2_schemadrift.csv`
(file ini punya kolom tambahan `loyalty_tier`, `referral_code`).
👀 **Yang harus dilihat:** kolom baru otomatis muncul di tabel tanpa error.

---

## Bagian 1.2 — Transformasi dengan dbt (Bronze → Silver)

### Konsep (1 menit)
- **dbt** = alat untuk menulis transformasi data pakai SQL + otomatis bikin tabel/view,
  test, dan dokumentasi.
- **dbt Projects on Snowflake** = dbt yang **dijalankan di dalam** Snowflake (objek native),
  dipanggil via `EXECUTE DBT PROJECT`.
- **Silver** = data sudah **dibersihkan** (tipe data benar, kolom turunan, dll).

### Langkah

🎯 **Tujuan:** deploy project dbt ke Snowflake, lalu jalankan transformasi.

👉 **Langkah (sekali, oleh instruktur):**
1. Dari terminal, masuk folder `dbt/`:
   ```bash
   cd dbt
   snow dbt deploy AMAR_WORKSHOP --database AMAR_WORKSHOP --schema SILVER
   ```
2. Verifikasi project ter-deploy:
   ```sql
   SHOW DBT PROJECTS IN SCHEMA AMAR_WORKSHOP.SILVER;
   ```

👀 **Yang harus dilihat:** ada 1 baris `AMAR_WORKSHOP` (project dbt Anda).

👉 **Jalankan transformasi (manual dulu untuk paham, nanti via Airflow):**
```sql
EXECUTE DBT PROJECT AMAR_WORKSHOP.SILVER.AMAR_WORKSHOP ARGS='build';
```

👀 **Yang harus dilihat:** log dbt: model `stg_customers`, `stg_loans`, dst dibuat,
diikuti GOLD `mart_loan_performance`, `mart_customer_360`, lalu **PASS** untuk tests.
Verifikasi:
```sql
SELECT * FROM SILVER.STG_CUSTOMERS LIMIT 5;
SELECT * FROM GOLD.MART_LOAN_PERFORMANCE LIMIT 5;
```

> 💡 **Yang dipelajari DE:** satu perintah `dbt build` = transform + test + docs.
> Kolom seperti `dpd_bucket` dan `collection_ratio` dihitung otomatis di Gold.

### Demo SCD Type-2 (riwayat perubahan data)
🎯 **Tujuan:** menyimpan **riwayat** perubahan nasabah (mis. pindah provinsi).
👉 Jalankan:
```sql
EXECUTE DBT PROJECT AMAR_WORKSHOP.SILVER.AMAR_WORKSHOP ARGS='snapshot';
SELECT customer_id, province, dbt_valid_from, dbt_valid_to
FROM SILVER.DIM_CUSTOMERS_SCD2 LIMIT 10;
```
👀 **Yang harus dilihat:** kolom `dbt_valid_from`/`dbt_valid_to`. Baris aktif punya
`dbt_valid_to = NULL`. **Inilah cara melacak "data seperti apa pada tanggal X".**

---

## Bagian 1.3 — Orkestrasi dengan Airflow (otomatisasi)

### Konsep (1 menit)
- **Airflow** = penjadwal & pengatur pipeline. Pipeline digambarkan sebagai **DAG**
  (urutan task: A → B → C).
- Di workshop ini, **semua orkestrasi ada di Airflow** (bukan Snowflake Tasks).
  Snowflake hanya jadi tempat compute + storage.

### Langkah

🎯 **Tujuan:** menjalankan seluruh pipeline (ingest → dbt → DQ) sekali klik di Airflow.

👉 **Langkah:**
1. Buka Airflow UI di browser: `http://localhost:8080` (login `admin`/`admin`).
2. Di daftar DAG, cari **`amar_pipeline_end_to_end`**. Aktifkan toggle (kiri) jika mati.
3. Klik nama DAG → tab **Graph**. Anda akan lihat alur:
   ```
   ingest_bronze (5 task COPY)  →  dbt_snapshot_scd2  →  dbt_build  →  dq_gate
   ```
4. Klik tombol **▶ (Trigger DAG)** di kanan atas.

👀 **Yang harus dilihat:**
- Kotak task berubah warna: **kuning (running) → hijau (success)** satu per satu.
- Klik salah satu task → **Logs** → lihat perintah SQL yang dijalankan & hasilnya.
- Setelah semua hijau, pipeline selesai end-to-end **otomatis**.

> 💡 **Talking point penting:** "Kenapa Airflow, bukan Snowflake Tasks?"
> → Banyak tim DE sudah punya Airflow sebagai **satu** orchestrator untuk semua sistem
> (bukan hanya Snowflake). Dependency, retry, jadwal, dan alert terpusat di Airflow.
> Snowflake fokus jadi engine compute. (Snowflake Tasks tetap bisa dipakai bila tak ada Airflow.)

### Latihan: DAG ingest saja
👉 Coba juga DAG **`amar_ingest_s3_to_snowflake`** (hanya bagian ingest) untuk memahami
bagian terkecil sebelum pipeline penuh.

---

## Bagian 1.4 — Data Quality Gate

### Konsep
Sebelum data dipakai bisnis, kita cek dulu: ada NIK invalid? skor di luar rentang?
duplikat? Ini disebut **data quality gate**.

### Langkah
🎯 **Tujuan:** memastikan data lolos pemeriksaan kualitas.
👉 Jalankan manual:
```sql
CALL GOLD.SP_DQ_GATE();
```
👀 **Yang harus dilihat:** hasil JSON, mis.:
```json
{ "status": "PASS", "bad_nik": 0, "bad_credit_score": 0, "duplicate_customer_id": 0, ... }
```
`status = PASS` berarti data bersih. Di Airflow, task `dq_gate` menjalankan ini otomatis.

### Demo "data kotor" (penting untuk DE)
🎯 **Tujuan:** melihat apa yang terjadi saat data buruk masuk.
👉 **Langkah:**
1. Load file `data/customers_badrecords.csv` ke Bronze (NIK pendek, skor 9999, duplikat):
   ```sql
   COPY INTO BRONZE.RAW_CUSTOMERS
     FROM @BRONZE.STG_S3_AMAR/customers_badrecords.csv
     FILE_FORMAT=(FORMAT_NAME=BRONZE.FF_CSV)
     MATCH_BY_COLUMN_NAME=CASE_INSENSITIVE ON_ERROR=CONTINUE;
   ```
2. Jalankan ulang dbt build, lalu `CALL GOLD.SP_DQ_GATE();`

👀 **Yang harus dilihat:** sekarang `status = FAIL`, dengan `bad_nik`, `bad_credit_score`,
`duplicate_customer_id` > 0. **Inilah momen "pipeline menangkap masalah sebelum ke bisnis".**

---

## Bagian 1.5 — Notifikasi & Monitoring

🎯 **Tujuan:** tahu cara memantau pipeline & dapat notifikasi bila gagal.

👉 **Langkah & 👀 yang dilihat:**
- **Airflow Grid view:** klik DAG → tab **Grid**. Tiap kolom = satu run; hijau=sukses,
  merah=gagal. Klik kotak merah → **Logs** untuk diagnosis.
- **Retry otomatis:** DAG sudah diset `retries=2`. Jika task gagal sementara, Airflow
  mencoba lagi otomatis.
- **(Opsional) Email:** lihat blok komentar di `sql/02_dq_checks.sql` untuk notifikasi
  email langsung dari Snowflake.

---

## Ringkasan Session 1 (apa yang sudah dicapai)
- ✅ Data dari S3 masuk ke Snowflake (Bronze) lewat COPY INTO.
- ✅ Transformasi rapi Bronze→Silver→Gold dengan dbt (+ tests, + SCD-2).
- ✅ Semua dijalankan otomatis oleh Airflow (satu klik).
- ✅ Data quality gate menjaga kualitas sebelum data dipakai.

**Tabel `GOLD.MART_*` inilah yang dipakai di Session 2 (Analytics), 3 (Governance), dan 6 (AI).**

➡️ Lanjut ke **[Session 2 — Analytics + Build Streamlit pakai AI](GUIDE_SESSION2_ANALYTICS.md)**.
