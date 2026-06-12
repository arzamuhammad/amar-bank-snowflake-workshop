# SETUP_AIRFLOW.md — Menjalankan Apache Airflow di Laptop Lokal

> Orkestrasi pipeline workshop ini **100% di Airflow** (tanpa Snowflake Tasks).
> Airflow men-trigger `COPY INTO` (ingest) dan `EXECUTE DBT PROJECT` (transform) di Snowflake.

---

## A. Prasyarat (Prerequisites) — WAJIB sebelum hari-H

### Hardware / OS
- Laptop **RAM minimal 8 GB** (disarankan 16 GB) — Airflow jalan di Docker.
- Disk kosong **≥ 10 GB**.
- OS: **Windows 10/11**, macOS, atau Linux.

### Software yang dibutuhkan (semua OS)
| Tool | Versi | Cek |
|------|-------|-----|
| **Docker Desktop** | terbaru, status *Running* | `docker --version` |
| **Astro CLI** (disarankan) | ≥ 1.28 | `astro version` |
| Python | 3.10–3.12 (untuk dbt lokal opsional) | `python --version` |
| Snowflake CLI (`snow`) | terbaru (untuk `snow dbt deploy`) | `snow --version` |
| Git | terbaru | `git --version` |

> **Cara instalasi per-OS ada di Section A.1 (Windows), A.2 (macOS), A.3 (Linux).**

### Akses & Kredensial
- **Akun Snowflake** workshop + **warehouse** `AMAR_WORKSHOP_WH`.
- **Key-pair (RSA)** untuk auth Airflow→Snowflake (BUKAN password) — cara generate per-OS ada di bawah.
- Setelah punya key, daftarkan public key ke user Snowflake:
  ```sql
  ALTER USER <user> SET RSA_PUBLIC_KEY='<isi snowflake_key.pub tanpa baris BEGIN/END>';
  ```
- **Outbound HTTPS (443)** ke `*.snowflakecomputing.com` (cek firewall/proxy kantor).
- **S3 bucket publik** workshop sudah berisi data (lihat `data/`).

---

## A.1 Instalasi di WINDOWS (10/11) — langkah lengkap

> Di Windows, Docker Desktop berjalan di atas **WSL2** (Windows Subsystem for Linux).
> Ikuti urutan ini dari awal.

### Langkah 1 — Aktifkan WSL2
1. Buka **PowerShell sebagai Administrator** (klik kanan Start → *Terminal (Admin)*).
2. Jalankan:
   ```powershell
   wsl --install
   ```
   Ini meng-install WSL2 + Ubuntu. **Restart** laptop jika diminta.
3. Verifikasi (VERSION harus 2):
   ```powershell
   wsl --list --verbose
   ```

### Langkah 2 — Install Docker Desktop
1. Download dari <https://www.docker.com/products/docker-desktop/> lalu install.
2. Buka Docker Desktop → **Settings → General** → centang **Use the WSL 2 based engine**.
3. **Settings → Resources → WSL Integration** → aktifkan untuk distro Ubuntu Anda.
4. Pastikan ikon Docker (kanan bawah) berstatus **Running**.
5. Cek di PowerShell: `docker --version`.

### Langkah 3 — Install tools dengan winget
Windows 10/11 modern sudah punya **winget**. Di PowerShell:
```powershell
winget install --id Git.Git -e
winget install --id Python.Python.3.12 -e
winget install --id Astronomer.Astro -e
```
> Jika `winget` tidak ada, pakai **Chocolatey** (<https://chocolatey.org/install>):
> ```powershell
> choco install git python astro -y
> ```
> Atau install Astro CLI manual (PowerShell Admin):
> ```powershell
> Invoke-WebRequest -Uri https://install.astronomer.io -OutFile install-astro.ps1
> .\install-astro.ps1
> ```

### Langkah 4 — Install Snowflake CLI
```powershell
pip install snowflake-cli
snow --version
```

### Langkah 5 — Generate key-pair RSA di Windows
**Cara A — Git Bash** (terpasang bersama Git, sudah ada `openssl`). Buka *Git Bash*:
```bash
openssl genrsa 2048 | openssl pkcs8 -topk8 -inform PEM -out snowflake_key.p8 -nocrypt
openssl rsa -in snowflake_key.p8 -pubout -out snowflake_key.pub
```
**Cara B — ssh-keygen** (sudah ada di Windows, jalankan di PowerShell):
```powershell
ssh-keygen -t rsa -b 2048 -m PKCS8 -f snowflake_key -N '""'
ssh-keygen -f snowflake_key -e -m PKCS8 > snowflake_key.pub
```
Lalu **copy** file private key (`snowflake_key.p8` / `snowflake_key`) ke folder `airflow/include/`.

### Langkah 6 — Lanjut ke Section B
Buka **PowerShell** atau **Git Bash**, `cd` ke folder `airflow`, lalu `astro dev start`.

> 💡 **Tips Windows penting:**
> - Simpan repo di drive lokal (mis. `C:\workshop`); hindari path berisi spasi bila bisa.
> - Jika DAG/script error karena akhir baris (CRLF): `git config --global core.autocrlf input`, lalu checkout ulang.
> - Jalankan `astro`/`docker`/`snow` dari **PowerShell** atau **Git Bash**, bukan CMD lama.

---

## A.2 Instalasi di macOS
```bash
# Homebrew (https://brew.sh)
brew install astro git python snowflake-cli
# Docker Desktop: download dari docker.com lalu jalankan
# Key-pair RSA:
openssl genrsa 2048 | openssl pkcs8 -topk8 -inform PEM -out snowflake_key.p8 -nocrypt
openssl rsa -in snowflake_key.p8 -pubout -out snowflake_key.pub
```

## A.3 Instalasi di Linux (Ubuntu/Debian)
```bash
curl -sSL https://install.astronomer.io | sudo bash      # Astro CLI
sudo apt-get update && sudo apt-get install -y git python3-pip openssl
pip install snowflake-cli
# Docker Engine: ikuti https://docs.docker.com/engine/install/
# Key-pair RSA:
openssl genrsa 2048 | openssl pkcs8 -topk8 -inform PEM -out snowflake_key.p8 -nocrypt
openssl rsa -in snowflake_key.p8 -pubout -out snowflake_key.pub
```

---

## B. Menjalankan Airflow Lokal (Astro CLI)

1. Dari folder `airflow/`:
   ```bash
   cd airflow
   astro dev start
   ```
   Setelah selesai, Astro menampilkan **URL Airflow UI** (mis. `http://localhost:8080`
   atau `http://airflow.localhost:<port>`) — buka URL tsb di browser.
   Login default: `admin` / `admin`.

2. Struktur yang dipakai Astro:
   - `dags/` → DAG workshop (sudah ada).
   - `requirements.txt` → provider Snowflake (sudah ada).
   - `Dockerfile` → base image Astro Runtime.

> **Alternatif tanpa Astro:** `pip install -r requirements.txt` lalu `airflow standalone`
> (lebih ringan, tapi rawan konflik dependency). Astro lebih direkomendasikan.
> Di Windows, jalankan alternatif ini **di dalam WSL/Ubuntu**, bukan di PowerShell.

---

## C. Membuat Connection Snowflake di Airflow

**Opsi 1 — UI:** Admin → Connections → +
- Connection Id: `snowflake_default`
- Connection Type: `Snowflake`
- Account: `<YOUR_SNOWFLAKE_ACCOUNT>` (format `ORG-ACCOUNT`, isi sesuai akun Anda)
- Login: `<user>`
- Schema: `BRONZE`, Database: `AMAR_WORKSHOP`, Warehouse: `AMAR_WORKSHOP_WH`, Role: `ACCOUNTADMIN`
- Extra (key-pair):
  ```json
  {"private_key_file": "/usr/local/airflow/include/snowflake_key.p8"}
  ```
  (taruh file key di `airflow/include/` — path di atas adalah path **di dalam container**, sama untuk semua OS)

**Opsi 2 — CLI:**
```bash
astro dev run connections add snowflake_default \
  --conn-type snowflake \
  --conn-login <user> \
  --conn-schema BRONZE \
  --conn-extra '{"account":"<YOUR_SNOWFLAKE_ACCOUNT>","database":"AMAR_WORKSHOP","warehouse":"AMAR_WORKSHOP_WH","role":"ACCOUNTADMIN","private_key_file":"/usr/local/airflow/include/snowflake_key.p8"}'
```
> Di Windows PowerShell, perintah multi-baris pakai backtick (`` ` ``) sebagai ganti `\`,
> atau tulis dalam satu baris.

---

## D. dbt Project harus sudah ter-deploy ke Snowflake

DAG `amar_pipeline_end_to_end` memanggil `EXECUTE DBT PROJECT`, jadi **DBT PROJECT object**
harus sudah ada di Snowflake.

**Cara utama (workshop):** deploy lewat **Snowflake Workspace (UI)** — lihat
`../guides/GUIDE_SESSION1_DATA_ENGINEERING.md` **LAB 2**. Verifikasi:
```sql
SHOW DBT PROJECTS IN SCHEMA AMAR_WORKSHOP.SILVER;
```

**Alternatif (terminal):** pakai Snowflake CLI — lihat `../guides/GUIDE_SNOWCLI_SETUP.md`:
```bash
cd ../dbt
snow dbt deploy AMAR_WORKSHOP --database AMAR_WORKSHOP --schema SILVER -c amar
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
| (Windows) `astro`/`docker`/`snow` not recognized | Tutup & buka ulang PowerShell setelah install; pastikan tool ada di PATH. |
| (Windows) Docker tidak Running | Buka Docker Desktop, tunggu *Running*; pastikan **WSL2 engine** aktif (Settings → General). |
| (Windows) DAG/script gagal karena CRLF | `git config --global core.autocrlf input` lalu clone/checkout ulang. |
| (Windows) `wsl --install` gagal | Aktifkan *Virtual Machine Platform* & *Windows Subsystem for Linux* via *Turn Windows features on/off*, lalu restart. |

> Catatan: Airflow lokal = untuk **belajar/dev**. Untuk produksi gunakan
> **MWAA (AWS)** / Cloud Composer / Astronomer managed.
