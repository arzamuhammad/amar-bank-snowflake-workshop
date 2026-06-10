# Session 0 — Persiapan & Orientasi Snowflake (Untuk Pemula)

🎯 **Tujuan session ini:** memastikan semua peserta bisa login ke Snowflake,
mengenal antarmuka (Snowsight), dan paham konsep dasar **sebelum** masuk ke lab.

> Jika Anda sama sekali belum pernah pakai Snowflake, **jangan lewati halaman ini.**

---

## 0.1 Konsep dasar Snowflake (5 menit baca)

Bayangkan Snowflake seperti "Google Docs untuk data": semua di cloud, tidak ada
server yang Anda urus. Beberapa istilah yang akan sering muncul:

| Istilah | Analogi sederhana | Penjelasan |
|---------|-------------------|------------|
| **Account** | Alamat rumah | Tempat data perusahaan Anda tinggal di cloud. |
| **Database** | Lemari arsip | Wadah paling besar untuk menyimpan tabel. |
| **Schema** | Laci di dalam lemari | Pengelompokan tabel di dalam database. |
| **Table** | Map/berkas di laci | Tempat baris & kolom data tersimpan. |
| **Warehouse** | Mesin/genset | **Komputer** yang menjalankan query. Bisa dinyalakan/dimatikan, diperbesar/diperkecil. Bayar saat menyala saja. |
| **Stage** | Loading dock gudang | "Pintu" untuk memasukkan file (mis. dari S3) ke Snowflake. |
| **Role** | Kartu akses gedung | Menentukan Anda boleh lihat/melakukan apa. |

> Penting: **Warehouse di Snowflake = compute (CPU)**, BUKAN tempat menyimpan data.
> Tempat menyimpan data = Database/Schema/Table. Ini sering membingungkan pemula.

**Arsitektur Medallion** (pola yang kita pakai):
```
S3 (file mentah) → BRONZE (data mentah) → SILVER (dibersihkan) → GOLD (siap pakai bisnis)
```

---

## 0.2 Login ke Snowsight

🎯 **Tujuan:** masuk ke antarmuka web Snowflake.

👉 **Langkah:**
1. Buka browser → buka URL akun Snowflake (diberikan instruktur), contoh:
   `https://app.snowflake.com`
2. Masukkan **akun**, lalu **username** & **password** (atau SSO) dari instruktur.
3. Setelah masuk, Anda berada di **Snowsight** (UI utama Snowflake).

👀 **Yang harus dilihat:** menu kiri berisi **Projects**, **Data**, **AI & ML**,
**Monitoring**, **Admin**. Ini "rumah" kita selama workshop.

---

## 0.3 Mengenal Worksheet (tempat menulis SQL)

🎯 **Tujuan:** tahu di mana kita mengetik & menjalankan perintah SQL.

👉 **Langkah:**
1. Menu kiri → **Projects** → **Worksheets**.
2. Klik tombol **+ → SQL Worksheet** (kanan atas).
3. Di kanan atas worksheet, pilih **Role**, **Warehouse**, **Database**, **Schema**
   (selector konteks). Untuk sekarang biarkan default.
4. Ketik perintah uji:
   ```sql
   SELECT CURRENT_VERSION(), CURRENT_USER(), CURRENT_ROLE();
   ```
5. Blok perintah lalu tekan **Cmd/Ctrl + Enter** (atau klik tombol ▶ Run).

👀 **Yang harus dilihat:** muncul tabel hasil di bawah berisi versi Snowflake,
nama user Anda, dan role Anda. **Selamat — Anda baru saja menjalankan query pertama!**

> Tips: untuk menjalankan **satu** perintah, taruh kursor di perintah itu lalu Run.
> Untuk menjalankan **semua** perintah di worksheet, pilih semua (Cmd/Ctrl+A) lalu Run.

---

## 0.4 Menjalankan file SQL workshop

🎯 **Tujuan:** tahu cara memakai file `.sql` dari repo ini.

👉 **Langkah:**
1. Buka file SQL di repo (mis. `sql/00_setup.sql`) lewat teks editor.
2. **Copy** seluruh isinya.
3. **Paste** ke SQL Worksheet baru di Snowsight.
4. Jalankan dari atas ke bawah (boleh per blok agar paham tiap langkah).

> Alternatif (untuk yang sudah install **Snowflake CLI**):
> `snow sql -f sql/00_setup.sql`

---

## 0.5 Setup awal (dijalankan instruktur / sekali saja)

🎯 **Tujuan:** menyiapkan database, schema, warehouse, dan format file workshop.

👉 **Langkah:** jalankan `sql/00_setup.sql`.

👀 **Yang harus dilihat:**
- Pesan sukses `Warehouse AMAR_WORKSHOP_WH successfully created.`
- `Database AMAR_WORKSHOP successfully created.`
- Daftar file format di akhir (FF_CSV, FF_PARQUET, dll).

**Verifikasi cepat:**
```sql
SHOW DATABASES LIKE 'AMAR_WORKSHOP';
SHOW SCHEMAS IN DATABASE AMAR_WORKSHOP;   -- harus ada BRONZE, SILVER, GOLD, GOVERNANCE
SHOW WAREHOUSES LIKE 'AMAR_WORKSHOP_WH';
```

👀 **Yang harus dilihat:** database `AMAR_WORKSHOP` ada, 4 schema muncul, warehouse ada.

---

## 0.6 Checklist sebelum lanjut ke Session 1

- [ ] Bisa login ke Snowsight.
- [ ] Bisa membuat worksheet & menjalankan `SELECT CURRENT_VERSION();`.
- [ ] `sql/00_setup.sql` sudah dijalankan → DB/schema/warehouse ada.
- [ ] (Untuk Session 1) Airflow lokal sudah disiapkan — lihat `../airflow/SETUP_AIRFLOW.md`.

➡️ Lanjut ke **[Session 1 — Data Engineering](GUIDE_SESSION1_DATA_ENGINEERING.md)**.
