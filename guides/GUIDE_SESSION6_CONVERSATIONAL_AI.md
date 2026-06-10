# Session 6 — Conversational AI (Detail untuk Pemula)

🎯 **Tujuan besar:** membangun "chatbot data" yang bisa menjawab pertanyaan bisnis Amar Bank
dalam bahasa natural — gabungan **Cortex Analyst** (tanya data angka) + **Cortex Search**
(tanya dokumen/SOP) lewat agent **Snowflake Intelligence**.

> Prasyarat: Session 1 selesai (`GOLD.MART_*` ada). Referensi: `sql/06_cortex_ai.sql`.

---

## Konsep singkat (2 menit)
- **Cortex Analyst** = AI yang mengubah pertanyaan bahasa natural menjadi SQL, lalu
  menjawab dari data Anda. Ia butuh **Semantic View** (kamus arti tabel/kolom/metrik).
- **Semantic View** = lapisan "makna bisnis" di atas tabel (mis. metrik `npl_rate`,
  sinonim `pinjaman`=`kredit`). **Bukan** view biasa.
- **Cortex Search** = mesin pencari semantik untuk **teks/dokumen** (SOP, produk).
- **Snowflake Intelligence** = tempat membuat **agent** yang menggabungkan keduanya.

---

## 6.1 Membuat Semantic View (untuk Cortex Analyst)

🎯 **Tujuan:** memberi AI "kamus" agar paham tabel pinjaman & nasabah.

👉 **Langkah:** jalankan bagian **CREATE SEMANTIC VIEW** di `sql/06_cortex_ai.sql`.
Lalu cek:
```sql
SHOW SEMANTIC VIEWS IN SCHEMA AMAR_WORKSHOP.GOLD;
```
👀 **Yang harus dilihat:** muncul `SV_LOAN_PORTFOLIO`. Di dalamnya terdefinisi
dimensi (provinsi, segmen produk), fakta (outstanding), dan metrik (`npl_rate`,
`total_outstanding`, dll) — lengkap dengan **sinonim Bahasa Indonesia**.

---

## 6.2 Menguji Cortex Analyst

🎯 **Tujuan:** bertanya ke data pakai bahasa natural.

👉 **Langkah (UI):**
1. Snowsight → **AI & ML → Cortex Analyst** (atau **Studio → Cortex Analyst**).
2. Pilih semantic view **`AMAR_WORKSHOP.GOLD.SV_LOAN_PORTFOLIO`**.
3. Ketik pertanyaan, mis.:
   - "Berapa NPL rate per segmen produk?"
   - "Provinsi mana dengan total outstanding terbesar?"
   - "Berapa jumlah nasabah per segmen?"

👀 **Yang harus dilihat:** AI menampilkan **jawaban + SQL** yang ia buat + tabel/grafik.
**Artinya:** user bisnis bisa tanya data tanpa bisa SQL. (SQL bisa diklik untuk transparansi.)

---

## 6.3 Membuat Cortex Search (untuk dokumen/SOP)

🎯 **Tujuan:** bisa mencari jawaban dari dokumen produk & SOP Amar.

👉 **Langkah:** jalankan bagian **PRODUCT_DOCS** + **CREATE CORTEX SEARCH SERVICE** di
`sql/06_cortex_ai.sql`. Lalu uji:
```sql
SELECT PARSE_JSON(SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
  'AMAR_WORKSHOP.GOLD.CSS_PRODUCT_DOCS',
  '{"query":"bagaimana proses penagihan kredit macet?","columns":["title","content"],"limit":3}'
))['results'] AS results;
```
👀 **Yang harus dilihat:** hasil pencarian mengembalikan dokumen "SOP Penagihan"
sebagai yang paling relevan. **Pencarian berdasarkan makna, bukan sekadar kata kunci.**

---

## 6.4 Merangkai Agent (Snowflake Intelligence)

🎯 **Tujuan:** satu chatbot yang bisa menjawab pertanyaan **angka** maupun **dokumen**.

👉 **Langkah (UI):**
1. Snowsight → **AI & ML → Snowflake Intelligence** → **Create agent**.
2. Beri nama, mis. `Amar_Assistant`.
3. **Tambah tool 1 — Cortex Analyst:** pilih semantic view `SV_LOAN_PORTFOLIO`.
4. **Tambah tool 2 — Cortex Search:** pilih service `CSS_PRODUCT_DOCS`.
5. Simpan, lalu buka jendela chat agent.

👉 **Coba tanyakan (campuran):**
- "Berapa NPL rate Tunaiku vs SMB?" → dijawab Analyst (angka).
- "Jelaskan SOP penagihan untuk DPD di atas 90 hari." → dijawab Search (dokumen).
- "Provinsi mana outstanding terbesar, dan apa kebijakan credit scoring kita?" → gabungan.

👀 **Yang harus dilihat:** agent **memilih tool yang tepat** secara otomatis dan menjawab
dalam bahasa natural, lengkap dengan sumber/SQL. **Inilah chatbot data end-to-end di Snowflake.**

---

## Ringkasan Session 6
- ✅ Semantic View memberi makna bisnis untuk Cortex Analyst.
- ✅ Cortex Analyst menjawab pertanyaan data dalam bahasa natural.
- ✅ Cortex Search mencari jawaban dari dokumen/SOP.
- ✅ Snowflake Intelligence menggabungkan keduanya jadi satu agent.

➡️ Lanjut ke **[Session 5 — ML with Cortex Code (bonus)](GUIDE_SESSION5_CORTEX_CODE.md)**.
