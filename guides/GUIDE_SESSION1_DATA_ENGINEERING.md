# Session 1 — Data Engineering (Versi Sangat Detail untuk Pemula)

> Kalau Anda belum pernah pakai Snowflake **maupun** Airflow, baca halaman ini pelan-pelan
> dari atas. Jangan loncat. Setiap istilah dijelaskan dengan analogi.

🎯 **Tujuan akhir:** data Amar Bank mengalir otomatis:
**file di S3 → masuk Snowflake (mentah) → dirapikan → siap dipakai bisnis**, dan semua
itu dijalankan oleh **Airflow** hanya dengan sekali klik.

---

## 0. PETA BESAR — pahami ini dulu (5 menit)

Ada **3 "pemain"** dalam workshop ini. Bayangkan seperti dapur restoran:

| Pemain | Analogi | Perannya | Jalan di mana? |
|--------|---------|----------|----------------|
| **Snowflake** | Dapur + gudang bahan | Tempat data disimpan & semua pekerjaan berat (COPY, transform) benar-benar dikerjakan | Cloud |
| **dbt** | Buku resep masakan | Kumpulan "resep" SQL untuk mengubah data mentah jadi data rapi | File di folder `dbt/` (dikirim ke Snowflake) |
| **Airflow** | Kepala koki / mandor | Mengatur **urutan** pekerjaan & menyuruh Snowflake mengerjakannya, lalu memantau | Laptop Anda (via Docker) |

**Hal paling penting yang sering bikin bingung:**
> Airflow **tidak** mengolah data sendiri. Airflow hanya **menyuruh** Snowflake:
> "Hei Snowflake, jalankan COPY ini", lalu "jalankan transformasi dbt", lalu "cek kualitas".
> Semua pengolahan terjadi **di dalam Snowflake**. Airflow cuma sang pengatur.

**Gambaran alur (yang akan Anda jalankan):**
```
            ┌─────────────── AIRFLOW (di laptop, sang pengatur) ───────────────┐
            │  Trigger 1x → suruh Snowflake kerjakan langkah 1,2,3,4 berurutan  │
            └─────────────────────────────┬─────────────────────────────────────┘
                                           │  (mengirim perintah SQL)
                                           ▼
 S3 (file CSV) ──①COPY──► Snowflake BRONZE ──②dbt──► SILVER ──③dbt──► GOLD ──④cek kualitas
```

---

## 1. APA YANG HARUS DISIAPKAN DULU (sekali saja)

Sebelum menyentuh Airflow, ada beberapa hal yang dipasang **sekali** oleh instruktur.
Ini ibarat menyiapkan dapur sebelum koki mulai bekerja.

### Daftar persiapan & DI MANA dijalankan

| # | Yang disiapkan | Caranya | Di mana |
|---|----------------|---------|---------|
| A | Database, schema, warehouse, file format | jalankan `sql/00_setup.sql` | **Snowflake** (Snowsight worksheet) |
| B | Upload 5 file CSV ke bucket S3 | upload manual | **AWS S3** |
| C | Stage + tabel Bronze kosong | jalankan bagian CREATE di `sql/01_ingestion.sql` | **Snowflake** |
| D | Prosedur cek kualitas (`SP_DQ_GATE`) | jalankan `sql/02_dq_checks.sql` | **Snowflake** |
| E | "Resep" dbt dikirim ke Snowflake | `snow dbt deploy ...` (lihat bagian 3) | **Terminal** |
| F | Airflow dinyalakan di laptop | `astro dev start` (lihat bagian 2) | **Terminal** |
| G | Airflow dikasih "kunci" ke Snowflake | tambah Connection (lihat bagian 2) | **Airflow UI** |

> 💡 Catatan: langkah A, C, D itu kita jalankan **manual sekali** supaya objeknya ada.
> Nanti, **Airflow** yang akan menjalankan bagian COPY (isi tabel) & transformasi secara
> berulang/otomatis. Jadi: *struktur* dibuat manual sekali, *pengisian data* diotomasi Airflow.

---

## 2. AIRFLOW — DIJELASKAN PELAN-PELAN

### 2.1 Apa itu Airflow, DAG, dan kenapa "sudah ada job"?

- **Airflow** = aplikasi pengatur pipeline. Punya tampilan web (UI).
- **DAG** = singkatan dari *Directed Acyclic Graph*. Anggap saja **DAG = satu "pipeline" / "job"** =
  selembar resep berisi urutan langkah (task) yang harus dijalankan.
- **Bagaimana DAG dibuat?** DAG itu sebenarnya **file Python** di dalam folder `airflow/dags/`.

> ❓ **"Kenapa pas saya buka Airflow, job-nya sudah ada?"**
> Karena di repo ini kita **sudah menyiapkan** 2 file DAG:
> - `airflow/dags/dag_ingest_s3_to_snowflake.py`
> - `airflow/dags/dag_pipeline_end_to_end.py`
>
> Saat Airflow menyala, ia **otomatis membaca semua file** di folder `dags/` dan
> menampilkannya sebagai job di UI. Jadi Anda **tidak perlu membuat job dari nol** —
> sudah kami siapkan. Yang Anda lakukan hanya **menyalakan & menjalankannya.**

Dua job (DAG) yang tersedia:

| Nama DAG di UI | Isinya | Untuk apa |
|----------------|--------|-----------|
| `amar_ingest_s3_to_snowflake` | hanya langkah COPY (5 task) | latihan pertama yang simpel: isi tabel Bronze |
| `amar_pipeline_end_to_end` | COPY → dbt snapshot → dbt build → cek kualitas | pipeline penuh end-to-end |

### 2.2 Menyalakan Airflow

🎯 **Tujuan:** menghidupkan Airflow di laptop Anda.

👉 **Langkah:** buka terminal, masuk ke folder `airflow`, lalu:
```bash
cd airflow
astro dev start
```
Tunggu beberapa menit (Docker membangun & menyalakan container).

👀 **Yang harus dilihat:** di akhir muncul **URL Airflow UI** (mis. `http://localhost:8080`)
dan kredensial `admin` / `admin`. Buka URL itu di browser → login.

👀 Di halaman utama (**DAGs**), Anda akan melihat **2 job** di atas tadi. **Itu wajar dan benar** —
karena file-nya sudah ada di `dags/`.

> Untuk **mematikan** Airflow nanti: `astro dev stop`. Reset total: `astro dev kill`.

### 2.3 Menambah Connection (KENAPA ini perlu?)

🎯 **Tujuan:** memberi Airflow "alamat + kunci" agar bisa masuk & menyuruh Snowflake.

> ❓ **"Kenapa harus menambah connection?"**
> Airflow berjalan di laptop Anda, Snowflake ada di cloud. Keduanya **belum saling kenal**.
> *Connection* = catatan berisi **alamat akun Snowflake + cara login** (pakai key-pair RSA).
> Tanpa ini, saat job dijalankan Airflow tidak tahu harus menghubungi Snowflake yang mana
> dan akan gagal "tidak ada koneksi".

👉 **Langkah (lewat UI):**
1. Di Airflow UI, menu atas **Admin → Connections**.
2. Klik tombol **+** (Add a new record).
3. Isi:
   - **Connection Id:** `snowflake_default`  ← harus persis ini (dipakai di DAG)
   - **Connection Type:** `Snowflake`
   - **Account:** `<YOUR_SNOWFLAKE_ACCOUNT>` (format `ORG-ACCOUNT`)
   - **Login:** `<username Snowflake Anda>`
   - **Schema:** `BRONZE`
   - **Warehouse:** `AMAR_WORKSHOP_WH`
   - **Database:** `AMAR_WORKSHOP`
   - **Role:** `AMAR_DATA_ENGINEER`
   - **Extra:** (untuk key-pair)
     ```json
     {"private_key_file": "/usr/local/airflow/include/snowflake_key.p8"}
     ```
4. Pastikan file private key Anda ada di `airflow/include/snowflake_key.p8`
   (path di Extra adalah lokasi file **di dalam container**, bukan di laptop).
5. Klik **Save**. (Opsional: klik **Test** untuk cek koneksi.)

👀 **Yang harus dilihat:** connection `snowflake_default` muncul di daftar. Kalau di-Test,
muncul pesan sukses. **Sekarang Airflow sudah bisa "bicara" ke Snowflake.**

> 🔑 Cara membuat key-pair RSA ada di `SETUP_AIRFLOW.md` (Windows/macOS/Linux),
> dan public key-nya didaftarkan ke user Snowflake (`ALTER USER ... SET RSA_PUBLIC_KEY=...`).

---

## 3. "DEPLOY DBT" — KENAPA & APA BEDANYA dengan Airflow?

> ❓ **"Tadi kok tiba-tiba disuruh deploy? Deploy apa?"**

Ini bagian yang paling sering bikin bingung. Mari pelan-pelan.

- Folder `dbt/` di repo berisi **"resep" transformasi** (file-file SQL: staging, marts, dll).
- Resep ini ada di **laptop Anda**, sedangkan kita ingin transformasi **berjalan di dalam Snowflake**.
- Jadi resep itu harus **"dikirim/didaftarkan" ke Snowflake** terlebih dulu — **sekali saja**.
  Proses inilah yang disebut **deploy dbt project**.
- Setelah ter-deploy, Snowflake punya objek bernama "dbt project" yang bisa dijalankan dengan
  perintah `EXECUTE DBT PROJECT`. Nantinya **Airflow yang memanggil perintah ini.**

📌 **Bedakan dua hal ini (sering tertukar):**
| Istilah | Artinya | Frekuensi |
|---------|---------|-----------|
| `astro dev start` | Menyalakan **Airflow** di laptop | tiap mau pakai |
| `snow dbt deploy` | Mengirim **resep dbt** ke Snowflake | **sekali** (atau saat resep berubah) |

🎯 **Tujuan:** mengirim resep dbt ke Snowflake.

👉 **Langkah (di terminal, sekali saja):**
```bash
cd ../dbt          # dari folder airflow, pindah ke folder dbt
snow dbt deploy AMAR_WORKSHOP --database AMAR_WORKSHOP --schema SILVER
```

👀 **Yang harus dilihat:** pesan sukses. Verifikasi di Snowflake:
```sql
SHOW DBT PROJECTS IN SCHEMA AMAR_WORKSHOP.SILVER;
```
muncul 1 baris `AMAR_WORKSHOP`. **Resep dbt sekarang sudah "hidup" di dalam Snowflake.**

---

## 4. MENJALANKAN PIPELINE (akhirnya!)

Setelah semua siap (objek Snowflake ada, dbt ter-deploy, Airflow nyala + connection ada),
sekarang tinggal **menjalankan job**.

### 4.1 Latihan pertama — job ingest saja

🎯 **Tujuan:** memahami satu bagian terkecil dulu (mengisi tabel Bronze dari S3).

👉 **Langkah:**
1. Di Airflow UI, halaman **DAGs**, cari `amar_ingest_s3_to_snowflake`.
2. Nyalakan **toggle** di kiri nama DAG (kalau masih abu-abu/off).
3. Klik nama DAG → tab **Graph** (lihat kotak-kotak task: `copy_customers`, `copy_loans`, dst).
4. Klik tombol **▶ Trigger** (kanan atas).

👀 **Yang harus dilihat:**
- Tiap kotak task berubah: **abu → kuning (sedang jalan) → hijau (sukses)**.
- Klik salah satu kotak → **Logs** → Anda bisa lihat perintah `COPY INTO` yang dikirim ke
  Snowflake & hasilnya (berapa baris dimuat).
- Verifikasi di Snowflake:
  ```sql
  SELECT COUNT(*) FROM AMAR_WORKSHOP.BRONZE.RAW_CUSTOMERS;   -- harus 5000
  ```
**Artinya:** Airflow berhasil menyuruh Snowflake mengisi tabel. 🎉

### 4.2 Pipeline penuh — end to end

🎯 **Tujuan:** menjalankan seluruh alur sekali klik.

👉 **Langkah:**
1. Di DAGs, nyalakan & buka `amar_pipeline_end_to_end` → tab **Graph**.
2. Perhatikan urutannya:
   ```
   ingest_bronze (5 COPY)  →  dbt_snapshot_scd2  →  dbt_build  →  dq_gate
   ```
3. Klik **▶ Trigger**.

👀 **Yang harus dilihat:** kotak menyala hijau berurutan dari kiri ke kanan. Tiap kotak:
- `ingest_bronze` = isi Bronze (COPY)
- `dbt_snapshot_scd2` = simpan riwayat perubahan nasabah (SCD-2)
- `dbt_build` = bangun SILVER & GOLD (Snowflake menjalankan `EXECUTE DBT PROJECT`)
- `dq_gate` = cek kualitas data (panggil `SP_DQ_GATE`)

Verifikasi hasil akhir di Snowflake:
```sql
SELECT * FROM AMAR_WORKSHOP.GOLD.MART_LOAN_PERFORMANCE LIMIT 10;
```

> 💡 **Kenapa Airflow, bukan Snowflake Tasks?** Karena banyak tim DE memakai Airflow sebagai
> **satu pengatur** untuk semua sistem (bukan hanya Snowflake). Jadwal, urutan, retry, dan
> notifikasi terpusat di Airflow; Snowflake fokus jadi mesin pengolah.

---

## 5. MEMANTAU & KALAU GAGAL

👀 **Memantau:** klik DAG → tab **Grid**. Tiap kolom = satu kali run. Hijau=sukses, merah=gagal.
Klik kotak merah → **Logs** untuk lihat pesan error.

👀 **Retry otomatis:** DAG sudah diatur mencoba ulang (`retries`) bila gagal sementara.

**Troubleshooting Airflow yang umum:**
| Gejala | Penyebab & Solusi |
|--------|-------------------|
| Task merah, log: *"No connection: snowflake_default"* | Connection belum dibuat / id salah → ulangi bagian 2.3 |
| Task merah, log: *authentication failed* | Key-pair salah / public key belum didaftarkan ke user Snowflake |
| `dbt_build` gagal: *EXECUTE DBT PROJECT not found* | Belum `snow dbt deploy` → ulangi bagian 3 |
| `copy_*` sukses tapi 0 rows | File belum diupload ke S3 / path stage salah → cek `LIST @BRONZE.STG_S3_AMAR;` |
| DAG tidak muncul di UI | Pastikan Airflow sudah `astro dev start`; file ada di `airflow/dags/` |

---

## 6. RINGKASAN URUTAN (cheat-sheet)

```
SEKALI SAJA (persiapan):
  1. Snowflake : jalankan 00_setup.sql               (DB/schema/WH/format)
  2. S3        : upload data/*.csv ke bucket
  3. Snowflake : jalankan bagian CREATE di 01_ingestion.sql (stage + tabel Bronze)
  4. Snowflake : jalankan 02_dq_checks.sql            (buat SP_DQ_GATE)
  5. Terminal  : snow dbt deploy ...                  (kirim resep dbt ke Snowflake)
  6. Terminal  : cd airflow && astro dev start        (nyalakan Airflow)
  7. Airflow UI: Admin → Connections → tambah snowflake_default

TIAP MAU MENJALANKAN PIPELINE:
  8. Airflow UI: nyalakan & Trigger DAG (ingest dulu, lalu end_to_end)
  9. Airflow UI: pantau Graph/Grid + Logs
 10. Snowflake : verifikasi GOLD.MART_* terisi
```

➡️ Lanjut ke **[Session 2 — Analytics + Build Streamlit pakai AI](GUIDE_SESSION2_ANALYTICS.md)**.
