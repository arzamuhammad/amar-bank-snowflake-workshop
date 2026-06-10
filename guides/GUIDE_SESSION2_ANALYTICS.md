# Session 2 — Data Analytics & Build Streamlit pakai AI (Detail untuk Pemula)

🎯 **Tujuan besar session ini:**
1. Menjalankan analitik di Snowflake & memahami **performa warehouse** dan **cache**.
2. **Membangun dashboard Streamlit hanya dengan mengetik perintah ke AI** (tanpa coding manual).

> Prasyarat: Session 1 selesai → tabel `GOLD.MART_LOAN_PERFORMANCE` & `GOLD.MART_CUSTOMER_360` sudah ada.

---

# BAGIAN A — Analitik & Performa (SQL)

Buka worksheet baru, set konteks: Role apa saja, Warehouse `AMAR_WORKSHOP_WH`,
Database `AMAR_WORKSHOP`, Schema `GOLD`. Referensi perintah: `sql/04_analytics.sql`.

## A.1 Query bisnis pertama

🎯 **Tujuan:** menjawab pertanyaan bisnis nyata: "Berapa NPL (kredit macet) per produk?"

👉 **Langkah:** jalankan:
```sql
SELECT product_segment,
       COUNT(*) AS n_loans,
       SUM(is_default) AS n_default,
       ROUND(100 * SUM(is_default)/COUNT(*), 2) AS npl_rate_pct,
       SUM(outstanding) AS total_outstanding
FROM GOLD.MART_LOAN_PERFORMANCE
GROUP BY product_segment
ORDER BY npl_rate_pct DESC;
```

👀 **Yang harus dilihat:** tabel berisi `Tunaiku` & `SMB` dengan kolom `npl_rate_pct`.
**Artinya:** dalam hitungan detik, Anda dapat metrik risiko portofolio dari jutaan baris.

## A.2 Performa Warehouse — Scale Up

🎯 **Tujuan:** membuktikan menambah ukuran "mesin" mempercepat query berat.

👉 **Langkah:**
1. Matikan cache agar adil:
   ```sql
   ALTER SESSION SET USE_CACHED_RESULT = FALSE;
   ALTER WAREHOUSE AMAR_WORKSHOP_WH SET WAREHOUSE_SIZE = 'XSMALL';
   ```
2. Jalankan query berat (join + agregasi) — lihat di `sql/04_analytics.sql` bagian A.2.
3. Catat durasinya (lihat panel **Query Details / Duration**).
4. Perbesar mesin lalu jalankan query **yang sama**:
   ```sql
   ALTER WAREHOUSE AMAR_WORKSHOP_WH SET WAREHOUSE_SIZE = 'LARGE';
   ```

👀 **Yang harus dilihat:** durasi query **turun signifikan** di warehouse LARGE.
**Artinya:** di Snowflake, menambah tenaga komputasi cukup 1 perintah (atau 1 klik),
tanpa migrasi server. Jangan lupa kecilkan lagi:
```sql
ALTER WAREHOUSE AMAR_WORKSHOP_WH SET WAREHOUSE_SIZE = 'SMALL';
```

> 📌 **Scale UP vs Scale OUT:** *up* = mesin lebih besar (query berat). *out* = banyak
> mesin paralel/multi-cluster (banyak user bersamaan).

## A.3 Result Cache

🎯 **Tujuan:** melihat query yang sama jadi instan & **gratis** (tanpa compute).

👉 **Langkah:**
```sql
ALTER SESSION SET USE_CACHED_RESULT = TRUE;
SELECT product_segment, COUNT(*) FROM GOLD.MART_LOAN_PERFORMANCE GROUP BY 1;  -- run #1
SELECT product_segment, COUNT(*) FROM GOLD.MART_LOAN_PERFORMANCE GROUP BY 1;  -- run #2
```

👀 **Yang harus dilihat:** run #2 selesai **hampir 0 detik**. Cek di **Query History**:
kolom *Bytes scanned* = 0 / dilayani dari cache. **Artinya:** hemat biaya untuk query berulang.

---

# BAGIAN B — Membangun Streamlit dengan AI (tanpa coding!)

🎯 **Tujuan:** Menunjukkan bahwa siapa pun (bahkan non-programmer) bisa membuat dashboard
interaktif **hanya dengan mengetik permintaan ke AI** di dalam Snowflake.

> **Konsep:** Streamlit = framework untuk membuat aplikasi data interaktif dengan Python.
> Di Snowsight ada editor Streamlit dengan **asisten AI (Cortex)** — kita cukup memberi
> instruksi bahasa natural, AI menuliskan kodenya.

## B.1 Membuat App Streamlit kosong

👉 **Langkah:**
1. Snowsight → menu kiri **Projects → Streamlit**.
2. Klik **+ Streamlit App** (kanan atas).
3. Isi: **App title** = `Amar Loan Dashboard`, **Warehouse** = `AMAR_WORKSHOP_WH`,
   **Database/Schema** = `AMAR_WORKSHOP` / `GOLD`. Klik **Create**.
4. Akan terbuka editor: kiri = kode, kanan = preview app.

👀 **Yang harus dilihat:** sebuah app contoh tampil di sebelah kanan.

## B.2 Membuka asisten AI

👉 **Langkah:** di dalam editor Streamlit, cari tombol/panel **AI** (ikon Cortex /
"Ask Copilot" — biasanya di toolbar editor atau klik kanan). Buka panel chat AI.

> Jika fitur AI assistant belum aktif di akun, Anda tetap bisa **paste** kode jadi dari
> file `streamlit/streamlit_app.py` (solusi referensi) — tapi tujuan demo ini adalah
> memakai AI.

## B.3 Prompt siap copy-paste

Ketik/paste prompt berikut **satu per satu** ke asisten AI. Setelah tiap prompt, klik
**Run** untuk melihat hasilnya di preview.

### Prompt 1 — Kerangka & koneksi data
```
Buatkan aplikasi Streamlit-in-Snowflake untuk dashboard portofolio pinjaman Amar Bank.
Gunakan get_active_session() dari snowflake.snowpark.context untuk koneksi.
Ambil data dari dua tabel:
- AMAR_WORKSHOP.GOLD.MART_LOAN_PERFORMANCE
- AMAR_WORKSHOP.GOLD.MART_CUSTOMER_360
Beri judul "Amar Bank - Loan Portfolio Dashboard" dan caption bahwa data ini sintetis.
Gunakan @st.cache_data agar query tidak diulang terus.
```

### Prompt 2 — Baris KPI
```
Tambahkan 4 kartu metrik (st.metric) dalam satu baris kolom:
1. Total Loans = jumlah baris MART_LOAN_PERFORMANCE
2. NPL Rate = rata-rata kolom IS_DEFAULT dikali 100, format persen
3. Total Outstanding = total kolom OUTSTANDING, tampilkan dalam miliar Rupiah
4. Total Customers = jumlah baris MART_CUSTOMER_360
```

### Prompt 3 — Grafik portofolio per produk
```
Tambahkan tab "Portfolio". Di dalamnya buat bar chart outstanding per PRODUCT_SEGMENT
dari MART_LOAN_PERFORMANCE, dan tampilkan juga tabel ringkasan berisi jumlah pinjaman,
total outstanding, dan NPL rate per segmen.
```

### Prompt 4 — Grafik risiko (DPD)
```
Tambahkan tab "Risk / DPD". Buat pie/donut chart yang menampilkan jumlah pinjaman
per DPD_BUCKET dari MART_LOAN_PERFORMANCE.
```

### Prompt 5 — Analisis nasabah per provinsi + filter interaktif
```
Tambahkan tab "Customer 360". Buat bar chart jumlah nasabah per PROVINCE dari
MART_CUSTOMER_360, urut dari terbanyak. Tambahkan st.selectbox untuk memfilter
berdasarkan SEGMENT (Tunaiku, Senyumku, SMB) yang memengaruhi seluruh chart di tab ini.
```

### Prompt 6 — Mempercantik
```
Rapikan tampilan: gunakan layout wide, beri ikon emoji pada judul tiap section,
dan beri warna berbeda untuk tiap kategori pada chart.
```

👀 **Yang harus dilihat di tiap langkah:**
- Setelah Prompt 1–2: judul + 4 kartu KPI muncul (Total Loans, NPL Rate, dst).
- Setelah Prompt 3–5: muncul 3 tab dengan grafik batang, donut, dan filter dropdown.
- Filter SEGMENT mengubah grafik secara **interaktif** — inilah kekuatan Streamlit.

## B.4 Menyimpan & membagikan

👉 **Langkah:** klik **Save**. Bagikan app ke role lain via tombol **Share** (mis. ke
`AMAR_ANALYST`).

👀 **Yang harus dilihat:** app tersimpan & bisa dibuka ulang dari Projects → Streamlit.

> 💡 **Pesan kunci ke customer:** "Dari nol sampai dashboard interaktif **tanpa menulis
> kode manual** — cukup memberi instruksi ke AI, dan semuanya berjalan **di dalam**
> Snowflake (data tidak keluar)."

---

## Ringkasan Session 2
- ✅ Bisa menjawab pertanyaan bisnis dengan SQL di Snowflake.
- ✅ Paham scale up/out & result cache (kcontrol biaya + performa).
- ✅ Membangun dashboard Streamlit **menggunakan AI** lewat prompt copy-paste.

📎 **Solusi referensi** (jika AI assistant tidak tersedia): `streamlit/streamlit_app.py`.

➡️ Lanjut ke **[Session 3 — Data Governance](GUIDE_SESSION3_GOVERNANCE.md)**.
