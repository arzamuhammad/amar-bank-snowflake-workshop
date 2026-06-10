# Session 5 — Machine Learning with Cortex Code (AI-Assisted)

> Tujuan: mereproduksi workflow ML (credit scoring) **dengan bantuan Cortex Code** —
> belajar teknik *prompting* alih-alih menulis semua kode manual.
> Audience: Data Engineer & Data Analyst. Data: GOLD marts dari Session 1.

> ⚠️ Catatan: Session 4 (ML end-to-end manual) **di-take out**. Session 5 ini berdiri
> sendiri sebagai pengenalan AI-assisted development.

---

## A. Persiapan
- Pakai **Cortex Code** (di Snowsight atau CLI ini).
- Dataset: `AMAR_WORKSHOP.GOLD.MART_CUSTOMER_360` (punya `ever_default` sebagai target,
  `credit_score`, `monthly_income`, `total_outstanding`, `n_loans`, dst).
- Target prediksi: **`ever_default`** (apakah nasabah pernah gagal bayar).

---

## B. Prinsip prompting yang baik
1. **Beri konteks**: sebutkan database/schema/tabel dan kolom target.
2. **Spesifik & bertahap**: minta satu langkah (EDA → fitur → train → register → inference).
3. **Minta validasi**: minta Cortex Code menjalankan & menampilkan hasil/metrik.
4. **Iterasi**: review kode yang dihasilkan, perbaiki via prompt lanjutan.

---

## C. Urutan prompt (copy-paste ke Cortex Code)

**1) Eksplorasi data**
```
Gunakan tabel AMAR_WORKSHOP.GOLD.MART_CUSTOMER_360. Tampilkan schema,
jumlah baris, dan distribusi kolom target ever_default. Buat ringkasan
statistik untuk credit_score, monthly_income, total_outstanding.
```

**2) Feature engineering**
```
Buat dataset training dari MART_CUSTOMER_360 dengan fitur numerik
(credit_score, monthly_income, age, n_loans, total_outstanding,
total_savings_balance, n_transactions) dan target ever_default.
Tangani null dan buat train/test split 80/20.
```

**3) Training (Snowpark ML / snowflake-ml-python)**
```
Latih model klasifikasi XGBoost untuk memprediksi ever_default
memakai snowflake-ml-python. Tampilkan akurasi, ROC-AUC, dan
confusion matrix pada test set.
```

**4) Registrasi ke Model Registry**
```
Daftarkan model ke Snowflake Model Registry dengan nama
AMAR_CREDIT_DEFAULT, version V1, sertakan metrik dan sample_input_data
untuk inferensi via SQL.
```

**5) Inference**
```
Jalankan batch inference: prediksi probabilitas default untuk semua
nasabah di MART_CUSTOMER_360 dan simpan ke tabel
AMAR_WORKSHOP.GOLD.CUSTOMER_DEFAULT_SCORES.
```

**6) Explainability (opsional)**
```
Hitung SHAP feature importance untuk model AMAR_CREDIT_DEFAULT V1
dan jelaskan 5 fitur paling berpengaruh.
```

---

## D. Yang harus di-review (penting!)
- Apakah dependency/package yang dipilih ada di Snowflake conda channel?
- Apakah `target_platform` saat `log_model` sesuai (WAREHOUSE untuk inferensi SQL)?
- Apakah ada kebocoran data (target ikut jadi fitur)?
- Apakah hasil metrik masuk akal (jangan 100% — indikasi leakage)?

**Outcome:** pipeline ML credit-scoring yang sama seperti pendekatan manual,
tetapi dihasilkan & diorkestrasi lewat prompt Cortex Code.
