# Session 5 — ML with Cortex Code (Detail untuk Pemula) — BONUS

🎯 **Tujuan besar:** membangun model Machine Learning (memprediksi nasabah berisiko gagal
bayar) **dengan bantuan AI coding assistant (Cortex Code)** — Anda memberi instruksi,
AI menuliskan & menjalankan kodenya. Cocok untuk yang belum mahir Python/ML.

> Prasyarat: Session 1 selesai (`GOLD.MART_CUSTOMER_360` ada).
> Target prediksi: kolom **`EVER_DEFAULT`** (1 = pernah gagal bayar, 0 = tidak).

---

## Konsep singkat (2 menit)
- **Machine Learning** = melatih model dari data historis untuk memprediksi sesuatu.
- **Cortex Code** = asisten AI yang bisa menulis & menjalankan kode (Python/SQL) atas perintah Anda.
- **Model Registry** = "lemari" tempat menyimpan model terlatih di Snowflake agar bisa dipakai ulang.
- **Inference** = memakai model untuk membuat prediksi pada data baru.

> **Prinsip prompting:** beri konteks (tabel & kolom), minta **satu langkah**, minta AI
> **menjalankan & menampilkan hasil**, lalu iterasi.

---

## 5.1 Membuka Cortex Code
👉 **Langkah:** buka Cortex Code (di Snowsight atau CLI). Pastikan terhubung ke akun
workshop & database `AMAR_WORKSHOP`.

---

## 5.2 Urutan prompt (copy-paste satu per satu)

### Prompt 1 — Eksplorasi data
```
Gunakan tabel AMAR_WORKSHOP.GOLD.MART_CUSTOMER_360. Tampilkan schema, jumlah baris,
dan distribusi kolom target EVER_DEFAULT. Buat ringkasan statistik untuk
credit_score, monthly_income, dan total_outstanding.
```
👀 **Yang dilihat:** ringkasan jumlah baris & berapa persen nasabah `EVER_DEFAULT=1`
(menunjukkan data tidak seimbang — penting untuk ML).

### Prompt 2 — Feature engineering
```
Buat dataset training dari MART_CUSTOMER_360 dengan fitur numerik: credit_score,
monthly_income, age, n_loans, total_outstanding, total_savings_balance, n_transactions.
Targetnya EVER_DEFAULT. Tangani nilai null dan buat train/test split 80/20.
```
👀 **Yang dilihat:** konfirmasi ukuran data latih/uji & daftar fitur.

### Prompt 3 — Melatih model
```
Latih model klasifikasi XGBoost untuk memprediksi EVER_DEFAULT memakai
snowflake-ml-python. Tampilkan akurasi, ROC-AUC, dan confusion matrix pada test set.
```
👀 **Yang dilihat:** metrik performa. **Catatan:** jika akurasi ~100%, curigai kebocoran
data (fitur yang "membocorkan" jawaban) — minta AI memeriksanya.

### Prompt 4 — Simpan ke Model Registry
```
Daftarkan model ke Snowflake Model Registry dengan nama AMAR_CREDIT_DEFAULT version V1.
Sertakan metrik dan sample_input_data agar bisa dipakai untuk inferensi.
```
👀 **Yang dilihat:** konfirmasi model tersimpan; cek `SHOW MODELS IN SCHEMA ...`.

### Prompt 5 — Inference (prediksi massal)
```
Jalankan batch inference: prediksi probabilitas default untuk semua nasabah di
MART_CUSTOMER_360 dan simpan ke tabel AMAR_WORKSHOP.GOLD.CUSTOMER_DEFAULT_SCORES
berisi customer_id dan predicted_default_probability.
```
👀 **Yang dilihat:** tabel baru berisi skor risiko tiap nasabah → bisa dipakai bisnis.

### Prompt 6 — Explainability (opsional)
```
Hitung SHAP feature importance untuk model AMAR_CREDIT_DEFAULT V1 dan jelaskan 5 fitur
paling berpengaruh terhadap prediksi default.
```
👀 **Yang dilihat:** daftar fitur paling berpengaruh (mis. credit_score, total_outstanding).

---

## 5.3 Hal penting untuk di-review (jangan asal terima output AI)
- Apakah package yang dipakai ada di Snowflake conda channel?
- Apakah ada **kebocoran data** (kolom yang seharusnya tidak jadi fitur)?
- Apakah metrik masuk akal (bukan 100% sempurna)?
- Apakah `target_platform` model sesuai kebutuhan (WAREHOUSE untuk inferensi via SQL)?

## Ringkasan Session 5
- ✅ Membangun pipeline ML (EDA → fitur → train → registry → inference) **lewat prompt AI**.
- ✅ Belajar mengevaluasi & mengoreksi kode hasil AI (bukan menerima mentah-mentah).
- ✅ Hasil prediksi tersimpan sebagai tabel skor risiko nasabah.

⬅️ Kembali ke **[DEMO_GUIDANCE (index)](../DEMO_GUIDANCE.md)**.
