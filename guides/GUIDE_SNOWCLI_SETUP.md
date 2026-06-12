# GUIDE — Instalasi & Konfigurasi Snowflake CLI (`snow`) — OPSIONAL

> ⚠️ **OPSIONAL.** Pipeline Airflow di workshop ini **TIDAK butuh** `snow` CLI — Airflow
> menjalankan `EXECUTE DBT PROJECT` lewat Airflow Connection (key-pair), bukan lewat `snow`.
> Pakai panduan ini **hanya jika** Anda ingin deploy/menjalankan dbt atau cek koneksi
> **dari terminal** (alternatif UI Workspace). Banyak yang error di tahap konfigurasi koneksi,
> jadi langkahnya dibuat detail.

Sumber resmi: <https://docs.snowflake.com/en/developer-guide/snowflake-cli/installation/installation>

---

## A. Apa itu `snow` CLI & kenapa perlu?
`snow` = alat command-line resmi Snowflake. Di workshop ini dipakai untuk:
- **Cek koneksi** ke Snowflake dari terminal (`snow connection test`).
- (Opsional) **deploy / execute** dbt project dari terminal (`snow dbt deploy` / `snow dbt execute`)
  sebagai alternatif dari UI Workspace.

> ℹ️ **Penting:** `snow` CLI **berbeda** dari koneksi Airflow. Airflow punya Connection sendiri
> (lihat SETUP_AIRFLOW.md). `snow` CLI dipakai di **terminal Anda**, bukan di dalam Airflow.

---

## B. Instalasi

### B.1 — Windows
Pilih salah satu:
```powershell
# Opsi 1: winget
winget install -e --id Snowflake.SnowflakeCLI

# Opsi 2: lewat Python (butuh Python 3.10+)
pip install snowflake-cli
```
> Atau download installer .msi dari repo resmi:
> <https://sfc-repo.snowflakecomputing.com/snowflake-cli/index.html>

### B.2 — macOS
```bash
brew tap snowflakedb/snowflake-cli
brew install snowflake-cli
```

### B.3 — Linux (atau via Python di OS apa pun)
```bash
pip install snowflake-cli
# atau (disarankan, terisolasi):  uv tool install snowflake-cli
```

### Verifikasi instalasi
```bash
snow --version
snow --help
```
👀 **Yang harus dilihat:** muncul versi & daftar command (`connection`, `sql`, `dbt`, dll).

> ⚠️ Windows: kalau muncul `snow: command not found`, **tutup & buka ulang** PowerShell
> (agar PATH ter-refresh). Pakai PowerShell / Git Bash, bukan CMD lama.

---

## C. Konfigurasi koneksi (BAGIAN YANG SERING ERROR)

`snow` menyimpan koneksi di file **`config.toml`**. Ada 2 cara: **interaktif** (paling mudah) atau **manual**.

### C.1 — Cara interaktif (disarankan)
Jalankan:
```bash
snow connection add
```
Lalu isi saat diminta (key-pair, BUKAN password):
```
Enter connection name: amar
Enter account: <YOUR_SNOWFLAKE_ACCOUNT>      <- format ORG-ACCOUNT, mis. ABCD-XY12345
Enter user: <username Snowflake Anda>
Enter password: (KOSONGKAN, tekan Enter)
Enter role: ACCOUNTADMIN
Enter warehouse: AMAR_WORKSHOP_WH
Enter database: AMAR_WORKSHOP
Enter schema: SILVER
Enter host: (kosongkan)
Enter port: (kosongkan)
Enter region: (kosongkan)
Enter authenticator: SNOWFLAKE_JWT          <- WAJIB untuk key-pair
Enter private key file: /path/lengkap/ke/snowflake_key.p8
Enter token file path: (kosongkan)
```
👀 **Yang harus dilihat:** `Wrote new connection amar to config.toml`.

Jadikan default (opsional):
```bash
snow connection set-default amar
```

### C.2 — Cara manual (edit `config.toml`)
Lokasi file `config.toml`:
| OS | Lokasi |
|----|--------|
| macOS | `~/Library/Application Support/snowflake/config.toml` (atau `~/.snowflake/config.toml` jika ada) |
| Linux | `~/.config/snowflake/config.toml` (atau `~/.snowflake/config.toml`) |
| Windows | `%USERPROFILE%\AppData\Local\snowflake\config.toml` |

Isi:
```toml
default_connection_name = "amar"

[connections.amar]
account = "<YOUR_SNOWFLAKE_ACCOUNT>"
user = "<username>"
authenticator = "SNOWFLAKE_JWT"
private_key_file = "/path/lengkap/ke/snowflake_key.p8"
role = "ACCOUNTADMIN"
warehouse = "AMAR_WORKSHOP_WH"
database = "AMAR_WORKSHOP"
schema = "SILVER"
```
> ⚠️ **macOS/Linux WAJIB set permission file** (kalau tidak, `snow` menolak membacanya):
> ```bash
> chmod 0600 "<path config.toml>"
> ```

---

## D. Daftarkan public key ke user Snowflake (kalau belum)
Key-pair perlu didaftarkan **sekali** ke user Anda di Snowflake:
```sql
ALTER USER <username> SET RSA_PUBLIC_KEY='<isi snowflake_key.pub TANPA baris BEGIN/END>';
```
> Cara generate `snowflake_key.p8` & `.pub` ada di `../airflow/SETUP_AIRFLOW.md` (per OS).
> Public key & private key harus **sepasang** (dibuat bersamaan).

---

## E. Tes koneksi
```bash
snow connection test -c amar
```
👀 **Yang harus dilihat:** tabel dengan `Status | OK`, plus Host/Account/User/Role.
Coba juga query:
```bash
snow sql -c amar -q "SELECT CURRENT_USER(), CURRENT_ROLE(), CURRENT_WAREHOUSE();"
```

---

## F. Troubleshooting (error yang sering muncul)

| Pesan error | Penyebab | Solusi |
|-------------|----------|--------|
| `250001 Could not connect to Snowflake ... 404 Not Found` | `account` salah | Pakai format **ORG-ACCOUNT** (lihat Snowsight → Admin → Accounts), bukan URL lengkap |
| `JWT token is invalid` / `Invalid JWT` | public key belum/ salah didaftarkan | Ulangi bagian D; pastikan key publik = pasangan key privat yang dipakai |
| `Could not find private key file` | path salah | Pakai **path absolut** ke `snowflake_key.p8`; cek file benar-benar ada |
| `config.toml ... permissions` (macOS/Linux) | permission file terlalu terbuka | `chmod 0600 <config.toml>` |
| `authenticator` error / minta password | `authenticator` tidak diisi | Set `authenticator = "SNOWFLAKE_JWT"` |
| `snow: command not found` (Windows) | PATH belum refresh | Tutup & buka ulang PowerShell; atau install ulang |
| key dibuat dengan passphrase | private key terenkripsi | Set env `PRIVATE_KEY_PASSPHRASE=<passphrase>` atau buat key tanpa passphrase (`-nocrypt`) |

> Diagnostik mendalam: `snow connection test -c amar --enable-diag --diag-log-path ~/sf_diag`

---

## G. (Opsional) Pakai `snow` untuk dbt project
Setelah koneksi OK, Anda bisa deploy/execute dbt dari terminal (alternatif UI Workspace):
```bash
cd dbt
snow dbt deploy AMAR_WORKSHOP --database AMAR_WORKSHOP --schema SILVER -c amar
snow dbt execute AMAR_WORKSHOP --database AMAR_WORKSHOP --schema SILVER -c amar --args "build"
```
> Di workshop, **deploy dilakukan lewat UI Workspace (Session 1 LAB 2)**. Bagian ini hanya
> alternatif terminal bila Anda lebih suka CLI.
