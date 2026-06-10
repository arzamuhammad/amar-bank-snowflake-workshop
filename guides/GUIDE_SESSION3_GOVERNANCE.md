# Session 3 — Data Governance (Detail untuk Pemula)

🎯 **Tujuan besar:** melindungi data sensitif (PII) dan menjaga kepercayaan data dengan
kontrol kelas enterprise: **masking, row access, projection, data quality (DMF), dan lineage** —
semuanya **di dalam** Snowflake, di atas tabel dari Session 1.

> Prasyarat: Session 1 selesai (`SILVER.STG_CUSTOMERS` & `GOLD.MART_*` ada).
> Referensi perintah: `sql/03_governance.sql`.

---

## Konsep singkat (2 menit)
- **PII** (Personally Identifiable Information) = data pribadi: NIK, NPWP, email, telepon.
- **Role** = identitas akses. Di workshop ada `AMAR_ANALYST`, `AMAR_DATA_ENGINEER`, `AMAR_AUDITOR`.
- **Masking Policy** = aturan menyamarkan kolom tergantung role yang melihat.
- **Row Access Policy** = aturan membatasi **baris** yang boleh dilihat.
- **Projection Policy** = aturan melarang kolom tertentu di-SELECT.
- **DMF (Data Metric Function)** = "test kualitas data" yang berjalan terjadwal.
- **Lineage** = peta asal-usul data (dari S3 sampai dashboard).

---

## 3.0 Menyiapkan governance

🎯 **Tujuan:** membuat role, tag, policy, dan DMF.
👉 **Langkah:** jalankan seluruh `sql/03_governance.sql` (sebagai `ACCOUNTADMIN`).
👀 **Yang harus dilihat:** sederet pesan sukses membuat role, masking policy,
row access policy, projection policy, dan DMF.

---

## 3.1 Dynamic Data Masking (menyamarkan PII)

🎯 **Tujuan:** membuktikan kolom sensitif **otomatis tersamarkan** untuk role tertentu.

👉 **Langkah — lihat sebagai ADMIN (data asli):**
```sql
USE ROLE ACCOUNTADMIN;
SELECT customer_id, nik, email, phone, monthly_income
FROM SILVER.STG_CUSTOMERS LIMIT 5;
```
👀 NIK, email, phone, income **terlihat utuh**.

👉 **Langkah — lihat sebagai ANALYST (tersamarkan):**
```sql
USE ROLE AMAR_ANALYST;
SELECT customer_id, email, phone, monthly_income
FROM SILVER.STG_CUSTOMERS LIMIT 5;
```
👀 **Yang harus dilihat:** email jadi `****@...`, phone sebagian `XXXXXX`,
`monthly_income` jadi `NULL`. **Data yang sama, tampilan berbeda tergantung role — tanpa
menyalin/menggandakan tabel.**

> 💡 Untuk DE: satu policy melindungi kolom di mana pun ia dipakai. Tidak perlu bikin
> "view khusus" per tim.

---

## 3.2 Row Access Policy (membatasi baris)

🎯 **Tujuan:** ANALYST hanya boleh melihat nasabah provinsi tertentu (mis. DKI Jakarta).

👉 **Langkah:**
```sql
USE ROLE AMAR_ANALYST;
SELECT DISTINCT province FROM SILVER.STG_CUSTOMERS;
```
👀 **Yang harus dilihat:** hanya muncul `DKI Jakarta`. Bandingkan dengan `ACCOUNTADMIN`
yang melihat semua provinsi. **Pembatasan terjadi di level baris, otomatis.**

---

## 3.3 Projection Policy (melarang kolom di-SELECT)

🎯 **Tujuan:** mencegah ANALYST menarik kolom `nik` sama sekali.

👉 **Langkah:**
```sql
USE ROLE AMAR_ANALYST;
SELECT nik FROM SILVER.STG_CUSTOMERS LIMIT 1;
```
👀 **Yang harus dilihat:** query **ditolak/error** karena kolom `nik` dilindungi
projection policy untuk role ini. **Bahkan tidak boleh "diproyeksikan", bukan sekadar disamarkan.**

---

## 3.4 Data Quality dengan DMF

🎯 **Tujuan:** memantau kualitas data secara terjadwal & otomatis.

👉 **Langkah — lihat hasil pengukuran DMF:**
```sql
USE ROLE ACCOUNTADMIN;
SELECT measurement_time, metric_name, table_name, value
FROM TABLE(SNOWFLAKE.LOCAL.DATA_QUALITY_MONITORING_RESULTS(
  REF_ENTITY_NAME   => 'AMAR_WORKSHOP.SILVER.STG_CUSTOMERS',
  REF_ENTITY_DOMAIN => 'TABLE'))
ORDER BY measurement_time DESC;
```
👀 **Yang harus dilihat:** baris hasil metrik: `NULL_COUNT` (email kosong),
`DUPLICATE_COUNT` (customer_id), dan `DMF_CREDIT_SCORE_RANGE` (skor di luar 300–850).

> Jika belum ada hasil, lakukan perubahan data agar DMF (`TRIGGER_ON_CHANGES`) terpicu,
> mis. load `customers_badrecords.csv` lalu jalankan ulang dbt build.

**Artinya:** kualitas data dimonitor sebagai kode, ter-audit, tanpa tool eksternal.

---

## 3.5 Data Lineage (Horizon)

🎯 **Tujuan:** menelusuri aliran data dari sumber sampai konsumsi & analisis dampak.

👉 **Langkah (UI):**
1. Snowsight → **Catalog / Governance → Lineage** (atau Database Explorer → pilih objek → tab **Lineage**).
2. Pilih objek `AMAR_WORKSHOP.GOLD.MART_CUSTOMER_360`.

👀 **Yang harus dilihat:** graf alur:
```
@STG_S3_AMAR (S3) → BRONZE.RAW_CUSTOMERS → SILVER.STG_CUSTOMERS → GOLD.MART_CUSTOMER_360
                    BRONZE.RAW_LOANS      → SILVER.STG_LOANS      ↗
```
👉 Klik **upstream/downstream** untuk *impact analysis*: "Kalau kolom di Bronze berubah,
objek apa yang terdampak?"

**Via SQL (opsional):**
```sql
SELECT * FROM TABLE(SNOWFLAKE.CORE.GET_LINEAGE(
  'AMAR_WORKSHOP.GOLD.MART_CUSTOMER_360', 'TABLE', 'UPSTREAM', 5));
```

---

## 3.6 Kembalikan role
```sql
USE ROLE ACCOUNTADMIN;
```

## Ringkasan Session 3
- ✅ PII tersamarkan otomatis per role (masking).
- ✅ Baris & kolom dibatasi sesuai role (row access & projection).
- ✅ Kualitas data dimonitor otomatis (DMF).
- ✅ Asal-usul data terlihat & bisa dianalisis dampaknya (lineage).

➡️ Lanjut ke **[Session 6 — Conversational AI](GUIDE_SESSION6_CONVERSATIONAL_AI.md)**.
