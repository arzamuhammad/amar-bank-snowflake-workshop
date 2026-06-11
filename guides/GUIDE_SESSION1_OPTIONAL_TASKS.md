# Session 1 — LAB 4 (OPSIONAL): Data Pipeline Native di Snowflake pakai TASKS

> Alternatif **Airflow**. Di sini orkestrasi pipeline (COPY INTO → dbt → DQ) dibuat **100% di
> dalam Snowflake** memakai **Tasks** — tanpa tool eksternal, tanpa Docker.
> Bagus untuk tim yang ingin tetap di ekosistem Snowflake.

🎯 **Tujuan:** memahami cara membangun pipeline terjadwal & berurutan memakai **Task graph** Snowflake.

> Prasyarat: LAB 1 (tabel Bronze + stage), LAB 2 (DBT PROJECT object ter-deploy), dan
> `sql/02_dq_checks.sql` (SP_DQ_GATE) sudah ada. File: `../sql/08_pipeline_tasks_optional.sql`.

---

## Konsep singkat
- **Task** = unit kerja terjadwal di Snowflake yang menjalankan **satu** perintah SQL (atau memanggil SP).
- **Task graph (DAG)** = beberapa task dirangkai dengan klausa `AFTER` → berjalan berurutan.
- **ROOT task** = task paling atas; punya `SCHEDULE` (jadwal). Task anak jalan setelah parent sukses.
- ⚠️ **Semua task dalam satu graph harus di schema yang sama.** (Di sini semua di `BRONZE`.)

Perbandingan dengan Airflow:
| Aspek | Snowflake Tasks | Airflow |
|-------|-----------------|---------|
| Lokasi | Di dalam Snowflake | Di laptop/server terpisah |
| Install | Tidak ada | Docker/Astro |
| Cocok untuk | Pipeline murni Snowflake | Orkestrasi lintas banyak sistem |

---

## Langkah-langkah

### 1) Bungkus 5 COPY dalam stored procedure
🎯 Satu task = satu statement, jadi 5 COPY dibungkus dalam `SP_INGEST_BRONZE`.
👉 Jalankan bagian **(1)** di `sql/08_pipeline_tasks_optional.sql`.
👀 Muncul `Procedure SP_INGEST_BRONZE successfully created.`

### 2) Buat task graph
🎯 Rangkai: `TASK_ROOT_INGEST → TASK_DBT_SNAPSHOT → TASK_DBT_BUILD → TASK_DQ_GATE`.
👉 Jalankan bagian **(2)**. Tiap task:
- `TASK_ROOT_INGEST` (terjadwal) → `CALL SP_INGEST_BRONZE()` (COPY INTO)
- `TASK_DBT_SNAPSHOT` `AFTER` root → `EXECUTE DBT PROJECT ... ARGS='snapshot'`
- `TASK_DBT_BUILD` `AFTER` snapshot → `EXECUTE DBT PROJECT ... ARGS='build'`
- `TASK_DQ_GATE` `AFTER` build → `CALL SP_DQ_GATE()`

👀 Tiap task dibuat. **Inilah pipeline COPY INTO → dbt jobs, tapi orkestrasinya di Snowflake.**

### 3) Aktifkan (RESUME) — urutan penting!
🎯 Task dibuat dalam keadaan *suspended*. Harus di-RESUME **dari anak ke root**.
👉 Jalankan bagian **(3)**:
```sql
ALTER TASK BRONZE.TASK_DQ_GATE       RESUME;
ALTER TASK BRONZE.TASK_DBT_BUILD     RESUME;
ALTER TASK BRONZE.TASK_DBT_SNAPSHOT  RESUME;
ALTER TASK BRONZE.TASK_ROOT_INGEST   RESUME;   -- root terakhir
```
> Kenapa anak dulu? Root tidak boleh di-resume kalau ada anak yang masih suspended.

### 4) Jalankan sekarang (tanpa menunggu jadwal)
👉 Bagian **(4)**:
```sql
EXECUTE TASK BRONZE.TASK_ROOT_INGEST;
```
👀 Seluruh graph berjalan berurutan otomatis.

### 5) Pantau
👉 Bagian **(5)** atau Snowsight → **Monitoring → Task History / Graph**.
```sql
SELECT name, state, scheduled_time, completed_time, error_message
FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY(
        SCHEDULED_TIME_RANGE_START => DATEADD('hour', -1, CURRENT_TIMESTAMP())))
ORDER BY scheduled_time DESC;
```
👀 Lihat status tiap task: `SUCCEEDED` / `FAILED` + waktu. Verifikasi data:
```sql
SELECT COUNT(*) FROM AMAR_WORKSHOP.GOLD.MART_LOAN_PERFORMANCE;
```

### 6) Matikan jadwal setelah selesai (hemat biaya)
👉 Bagian **(6)** (SUSPEND/DROP). Minimal **SUSPEND root** agar tidak jalan terjadwal terus:
```sql
ALTER TASK BRONZE.TASK_ROOT_INGEST SUSPEND;
```

---

## Troubleshooting
| Gejala | Solusi |
|--------|--------|
| `Cannot resume root task ... has suspended predecessors/successors` | RESUME anak dulu, baru root (Langkah 3) |
| `EXECUTE DBT PROJECT ... does not exist` | Deploy dulu di LAB 2 (`SHOW DBT PROJECTS ...`) |
| Task tidak jalan terjadwal | Pastikan root sudah `RESUME` & `SCHEDULE` benar |
| Tidak punya izin | Perlu `CREATE TASK`/`EXECUTE TASK` (ACCOUNTADMIN aman) |

> **Kesimpulan:** ini cara Snowflake-native untuk pipeline COPY→dbt→DQ. Bedanya dengan
> Airflow: orkestrasi & jadwal tinggal di Snowflake (tanpa server terpisah).

⬅️ Kembali ke **[Session 1](GUIDE_SESSION1_DATA_ENGINEERING.md)** • **[Index](../DEMO_GUIDANCE.md)**
