# Workspace Rules: Finku: Budget & Money Manager (`GEMINI.md`)

Aturan kerja (*Workspace Rules*) ini dirancang khusus untuk agen AI di [Google Antigravity IDE](https://antigravity.google/docs/rules/) sebagai acuan arsitektur tunggal (*Single Source of Truth*) dalam membangun dan menguji aplikasi mobile [**Finku: Budget & Money Manager**](https://finku.id/id) (studi kasus PT Sahabat Finansial Kamu di [Google Play Store](https://play.google.com/store/apps/details?id=com.finku&hl=id) dan [Apple App Store](https://apps.apple.com/id/app/finku-budget-money-manager/id1587320325)). Simpan berkas ini dengan nama `GEMINI.md` atau `AGENTS.md` pada direktori utama (*root*) proyek Anda.

## 1. Prinsip Utama & Batasan Arsitektur (Core Invariants)

1. **Backend Tunggal (Eksklusif Supabase)**: Gunakan [**Supabase**](https://supabase.com/docs) ([Supabase PostgreSQL](https://supabase.com/docs/guides/database/overview), [Supabase Auth](https://supabase.com/docs/guides/auth), [Supabase Realtime](https://supabase.com/docs/guides/realtime), dan [Supabase Storage](https://supabase.com/docs)) untuk seluruh layanan backend. **DILARANG** mengimpor, mengonfigurasi, atau mencampur pustaka Firebase (`cloud_firestore`, `firebase_auth`, `firebase_core`) di dalam kode proyek.

2. **Target Kinerja & Kualitas (KPI Wajib)**:

   * **Cold Start Aplikasi**: Kurang dari `2.0 detik` pada perangkat kelas menengah; seluruh pemrosesan OCR dan AI wajib berjalan secara *asynchronous* tanpa memblokir *UI thread*.

   * **Modul 1 — OCR Scan Struk**: Waktu ekstraksi kurang dari `3.0 detik` (`< 2.5 detik` untuk struk cetak jelas) dengan *Field Extraction Accuracy* minimal `90%` pada nama merchant, tanggal, dan total nominal.

   * **Modul 2 — FinGPT AI Chat**: Waktu respons kurang dari `2.0 detik` dengan *Precision & Recall* kategorisasi serta ekstraksi entitas minimal `92%`.

   * **Modul 3 — Sinkronisasi Mode Bersama**: Latensi sinkronisasi lintas perangkat kurang dari `1.5 detik` via [Supabase Realtime Postgres Changes](https://supabase.com/docs/guides/realtime/postgres-changes) dengan konsistensi data `100%` (*zero race condition*).

   * **Modul 4 — Visualisasi Grafik Anggaran**: *Frame rate* stabil pada `60 FPS` (waktu render kurang dari `500 ms` untuk `500+` transaksi) dan akurasi kalkulasi agregasi `100%`.

3. **Kesiapan Otomatisasi Pengujian (Testability)**: Setiap komponen interaktif UI wajib memiliki atribut aksesibilitas/`Semantics` label dan `Key` yang eksplisit agar dapat diinspeksi dan dijalankan secara otomatis oleh [Maestro Studio](https://docs.maestro.dev/maestro-studio/run-tests-with-maestro-studio), dipantau lewat [scrcpy](https://scrcpy.org/), dan dieksekusi oleh *test runner* [Ruby](https://www.browserstack.com/docs/app-automate/appium/getting-started/ruby/cucumber/local-testing).

## 2. Stack Teknologi Resmi Proyek

| Lapisan Sistem | Teknologi / Pustaka yang Digunakan | Aturan Implementasi |
| ----- | ----- | ----- |
| **Mobile Frontend** | Flutter (Dart) + Riverpod (*State Management*) | Gunakan arsitektur *Feature-First Clean Architecture*; aktifkan `Semantics` untuk [dukungan Flutter di Maestro](https://docs.maestro.dev/get-started/supported-platform/flutter) |
| **Backend & Database** | [Supabase PostgreSQL](https://supabase.com/docs/guides/database/overview) (`supabase_flutter`) | Seluruh tabel di skema `public` wajib mengaktifkan [Row Level Security (RLS)](https://supabase.com/docs/guides/database/postgres/row-level-security) |
| **Real-Time Sync** | [Supabase Realtime](https://supabase.com/docs/guides/realtime/realtime-listening-flutter) (`stream()` & `PostgresChangeEvent`) | Gunakan *WebSocket channel* berfilter `wallet_id` untuk pembaruan instan tanpa *pull-to-refresh* manual |
| **Offline Database** | SQLite Lokal (`drift` atau `sqflite`) | Simpan antrean mutasi lokal saat *offline* dan sinkronkan ke Supabase dengan strategi *Last-Write-Wins* saat *online* |
| **Computer Vision (OCR)** | Google ML Kit Text Recognition + `image` | Jalankan pra-pemrosesan (*auto-crop*, *deskew*, *contrast enhancement*) sebelum ekstraksi teks |
| **NLP Engine (FinGPT)** | Gemini API (*Structured JSON Mode*) | Wajib mengembalikan struktur JSON tervalidasi mengacu pada fitur [FinGPT Finku](https://finku.id/id/blog/aplikasi-keuangan-yang-bikin-hidup-finansial-terkontrol) |
| **Visualisasi Grafik** | `fl_chart` | Render *Donut Chart*, *Bar/Line Chart*, dan *Progress Bar* dinamis tanpa *jank* pada dataset besar |
| **QA & Automation** | [Maestro CLI/Studio](https://docs.maestro.dev/maestro-cli) + [scrcpy](https://scrcpy.org/) + [Ruby](https://www.browserstack.com/docs/app-automate/appium/getting-started/ruby/cucumber/local-testing) | Simpan alur pengujian di folder `maestro/flows/*.yaml` dan skrip eksekutor di `qa/run_tests.rb` |

## 3. Struktur Direktori Proyek

Agen harus menjaga struktur folder berikut saat membuat atau memodifikasi berkas:

```
finku_app/
├── GEMINI.md                          # Workspace rules untuk Google Antigravity IDE
├── lib/
│   ├── core/
│   │   ├── config/supabase_config.dart
│   │   ├── constants/category_taxonomy.dart
│   │   ├── sync/offline_sync_engine.dart
│   │   └── utils/currency_normalizer.dart
│   ├── features/
│   │   ├── auth/                      # Modul Pendukung: Login & Sign Up (Supabase Auth)
│   │   ├── ocr_scan/                  # Modul 1: FR-OCR-01 s/d FR-OCR-04
│   │   ├── fingpt_chat/               # Modul 2: FR-AI-01 s/d FR-AI-04
│   │   ├── shared_wallet/             # Modul 3: FR-SYNC-01 s/d FR-SYNC-04
│   │   ├── budget_analytics/          # Modul 4: FR-VIS-01 s/d FR-VIS-03
│   │   └── settings/                  # Modul Pendukung: Profil, Set Budget, & Logout
│   └── main.dart
├── supabase/
│   └── migrations/
│       ├── 001_initial_schema_and_rls.sql
│       └── 002_profiles_avatar_and_shared_wallet_rbac.sql
├── maestro/
│   ├── flows/
│   │   ├── tc_ocr_scan.yaml
│   │   ├── tc_ai_fingpt.yaml
│   │   ├── tc_sync_shared_wallet.yaml
│   │   └── tc_vis_budget_chart.yaml
│   └── test_assets/                   # Sampel 20-30 foto struk uji
└── qa/
    ├── run_tests.rb                   # Skrip Ruby eksekutor Maestro & kalkulator akurasi
    └── reports/
```

## 4. Skema Database PostgreSQL Supabase & Row Level Security (RLS)

Setiap perubahan pada skema database di `supabase/migrations/` wajib mematuhi definisi SQL dan kebijakan [Supabase Row Level Security (RLS)](https://supabase.com/docs/guides/database/postgres/row-level-security) di bawah ini agar skenario pengujian konkurensi (`TC-SYNC-02`), *offline-to-online* (`TC-SYNC-03`), dan pembatasan akses `viewer` (`TC-SYNC-04`) berjalan valid:

```sql
-- 1. Enum untuk Peran Anggota Mode Bersama & Sumber Pencatatan
create type public.wallet_role as enum ('owner', 'editor', 'viewer');
create type public.tx_source as enum ('manual', 'ocr', 'ai_chat');

-- 1b. Tabel Profil Pengguna + Foto Avatar (Storage bucket `avatars`) & Trigger `on_auth_user_created`
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null,
  full_name text not null,
  avatar_initials text not null default 'FK',
  avatar_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- 2. Tabel Dompet (Mendukung Dompet Pribadi & Dompet Bersama / Shared Wallet)
create table public.wallets (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  is_shared boolean not null default false,
  invite_code text unique,
  created_by uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- 3. Tabel Anggota Dompet Bersama (RBAC: Owner, Editor, Viewer)
create table public.wallet_members (
  wallet_id uuid not null references public.wallets(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role public.wallet_role not null default 'viewer',
  joined_at timestamptz not null default now(),
  primary key (wallet_id, user_id)
);

-- 4. Tabel Anggaran Bulanan (Monthly Budgets per Kategori)
create table public.budgets (
  id uuid primary key default gen_random_uuid(),
  wallet_id uuid not null references public.wallets(id) on delete cascade,
  category text not null,
  month_period text not null, -- Format: 'YYYY-MM' (contoh: '2026-11')
  limit_amount bigint not null check (limit_amount > 0),
  updated_at timestamptz not null default now(),
  unique (wallet_id, category, month_period)
);

-- 5. Tabel Transaksi (Mendukung Deduplikasi Offline & Last-Write-Wins)
create table public.transactions (
  id uuid primary key default gen_random_uuid(),
  client_tx_id text not null unique, -- UUID lokal perangkat untuk cegah duplikasi saat Offline Sync (TC-SYNC-03)
  wallet_id uuid not null references public.wallets(id) on delete cascade,
  created_by uuid not null references auth.users(id),
  merchant_name text not null,
  category text not null,
  amount bigint not null check (amount > 0), -- Disimpan dalam Rupiah bulat (integer)
  source public.tx_source not null default 'manual',
  receipt_url text,
  tx_date date not null default current_date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now() -- Acuan waktu Last-Write-Wins (FR-SYNC-04)
);

-- Aktifkan Row Level Security (RLS) pada semua tabel
alter table public.wallets enable row level security;
alter table public.wallet_members enable row level security;
alter table public.budgets enable row level security;
alter table public.transactions enable row level security;

-- Kebijakan RLS Transaksi: Semua anggota (owner, editor, viewer) dapat membaca (SELECT)
create policy "Anggota dapat melihat transaksi dompet"
  on public.transactions for select
  to authenticated
  using (
    exists (
      select 1 from public.wallet_members wm
      where wm.wallet_id = transactions.wallet_id
        and wm.user_id = auth.uid()
    )
  );

-- Kebijakan RLS Transaksi: HANYA 'owner' dan 'editor' yang dapat menambah/mengubah/menghapus (TC-SYNC-04)
create policy "Hanya owner dan editor yang dapat memodifikasi transaksi"
  on public.transactions for all
  to authenticated
  using (
    exists (
      select 1 from public.wallet_members wm
      where wm.wallet_id = transactions.wallet_id
        and wm.user_id = auth.uid()
        and wm.role in ('owner', 'editor')
    )
  )
  with check (
    exists (
      select 1 from public.wallet_members wm
      where wm.wallet_id = transactions.wallet_id
        and wm.user_id = auth.uid()
        and wm.role in ('owner', 'editor')
    )
  );

-- Aktifkan publikasi Supabase Realtime untuk sinkronisasi instan (< 1.5 detik)
alter publication supabase_realtime add table public.transactions;
alter publication supabase_realtime add table public.budgets;
```

## 5. Aturan Teknis & Kontrak Data per Modul Fokus Pengujian

### Modul 1: Pemindaian Struk Belanja (`FR-OCR-01` s/d `FR-OCR-04`)

1. **Pra-Pemrosesan Gambar (`FR-OCR-02`)**: Sebelum mengirim gambar ke Google ML Kit Text Recognition, jalankan fungsi *auto-crop*, *deskewing* (koreksi kemiringan hingga `30 derajat` untuk `TC-OCR-03`), dan *contrast stretching* (untuk struk kusut/pudar pada `TC-OCR-02`).

2. **Normalisasi Angka Multi-Format (`TC-OCR-04`)**: Buat fungsi utilitas `CurrencyNormalizer.parseRupiah(String raw)` yang menormalisasi format angka bertitik (`15.000` atau `Rp 15.000,-`) maupun berkoma/desimal (`15,000.00`) menjadi integer murni (`15000`) tanpa kesalahan *parsing*.

3. **Kontrak JSON Hasil Ekstraksi OCR (`FR-OCR-03`)**:

   ```json
   {
     "merchant_name": "Indomaret",
     "tx_date": "2026-11-18",
     "items": [
       {"name": "Indomie Goreng", "qty": 2, "price": 6400}
     ],
     "tax_amount": 704,
     "discount_amount": 0,
     "total_amount": 7104,
     "suggested_category": "Belanja Harian",
     "confidence_score": 0.96
   }
   ```

4. **Antarmuka Pratinjau (`FR-OCR-04`)**: Selalu tampilkan formulir pratinjau (*Review Form*) agar pengguna dapat memeriksa atau mengedit hasil ekstraksi sebelum menekan tombol simpan.

### Modul 2: Pencatatan Pengeluaran Berbasis AI / FinGPT (`FR-AI-01` s/d `FR-AI-04`)

1. **Taksonomi Kategori Baku (`TC-AI-04`)**: AI hanya boleh memetakan transaksi ke dalam daftar kategori resmi berikut agar perhitungan grafik konsisten:
   * `Makanan & Minuman`
   * `Transportasi`
   * `Belanja Harian`
   * `Tagihan & Utilitas`
   * `Hiburan & Gaya Hidup`
   * `Kesehatan`
   * `Pendidikan`
   * `Lainnya`

2. **Pemecahan Multi-Transaksi & Bahasa Slang (`TC-AI-02`)**: *System prompt* pada Gemini API wajib mampu mengubah singkatan nominal bahasa sehari-hari (`rb`, `ribu`, `k`, `jt`) menjadi integer Rupiah dan memecah kalimat majemuk (contoh: *"Beli bensin 50rb, parkir 2rb, sama jajan kopi 18k pakai OVO"*) menjadi *array* berisi 3 objek transaksi independen dengan sumber dompet `OVO`.

3. **Penanganan Kalimat Ambigu (`TC-AI-03`)**: Jika input pengguna tidak mencantumkan nominal atau jenis transaksi yang jelas (contoh: *"Tadi habis bayar tagihan bulanan"*), AI **dilarang** membuat transaksi bernilai `Rp0`. Kembalikan `needs_clarification: true` beserta kalimat pertanyaan klarifikasi.

4. **Kontrak JSON Respons FinGPT**:

   ```json
   {
     "intent": "record_expense",
     "needs_clarification": false,
     "clarification_message": null,
     "transactions": [
       {
         "item_name": "Bensin",
         "amount": 50000,
         "category": "Transportasi",
         "wallet_name": "OVO",
         "tx_date": "2026-11-18"
       }
     ]
   }
   ```

### Modul 3: Sinkronisasi Mode Bersama (`FR-SYNC-01` s/d `FR-SYNC-04`)

1. **Langganan Real-Time Supabase (`FR-SYNC-03` & `TC-SYNC-01`)**: Gunakan [Supabase Flutter Stream](https://supabase.com/docs/reference/dart/stream) dengan kunci primer `['id']` dan filter `.eq('wallet_id', activeWalletId)` agar setiap penambahan, perubahan, atau penghapusan transaksi pada Perangkat A langsung memperbarui state UI pada Perangkat B dalam waktu kurang dari `1.5 detik`.

2. **Antrean Offline & Deduplikasi (`FR-SYNC-04` & `TC-SYNC-03`)**:
   * Setiap transaksi yang dibuat di perangkat wajib menghasilkan UUID v4 pada kolom `client_tx_id` sebelum disimpan ke SQLite lokal.
   * Saat koneksi internet kembali aktif, layanan *Offline Sync* melakukan `upsert(..., onConflict: 'client_tx_id')` ke Supabase PostgreSQL dan membandingkan kolom `updated_at` (*Last-Write-Wins*) sehingga tidak terjadi duplikasi entri maupun data yang hilang saat input simultan (`TC-SYNC-02`).

3. **Penegakan Hak Akses Peran (`FR-SYNC-02` & `TC-SYNC-04`)**: Pada sisi UI, sembunyikan atau nonaktifkan tombol *Edit* dan *Hapus* jika peran pengguna aktif adalah `viewer`. Pada sisi backend, pastikan kebijakan RLS menolak keras mutasi dari peran `viewer` dengan respons `Permission denied`.

### Modul 4: Visualisasi Grafik Anggaran Bulanan (`FR-VIS-01` s/d `FR-VIS-03`)

1. **Akurasi Agregasi Matematis (`TC-VIS-01`)**: Persentase setiap segmen *Donut Chart* wajib dihitung dengan rumus `(Total Kategori / Total Pengeluaran Bulan Ini) * 100%` secara *reactive* setiap kali ada transaksi baru dari OCR, FinGPT, maupun Mode Bersama.

2. **Kode Warna Ambang Batas Anggaran (`FR-VIS-02` & `TC-VIS-02`)**:
   * Rasio pemakaian kurang dari `75%` dari `limit_amount`: **Hijau** (`#16A34A`)
   * Rasio pemakaian `75%` hingga `90%` dari `limit_amount`: **Kuning / Amber** (`#D97706`)
   * Rasio pemakaian lebih dari `90%` atau *overbudget*: **Merah / Alert** (`#DC2626`)

3. **Ketahanan UI & Performa (`TC-VIS-03` & `TC-VIS-04`)**:
   * Gunakan `RepaintBoundary` pada komponen `fl_chart` dan hitung agregasi data di dalam `compute()` / provider ter-memoisasi agar pergantian filter pada `500+` transaksi tetap berjalan stabil di `60 FPS` (render kurang dari `500 ms`).
   * Sediakan tampilan *Empty State* yang rapi saat jumlah transaksi adalah `0`, dan tetapkan sudut minimum (*minimum sweep angle*) pada segmen *Donut Chart* agar perbandingan angka ekstrem (misalnya `Rp10.000.000` dengan `Rp1.000`) tidak menyebabkan *UI overlap* atau `LayoutOverflow`.

### Modul Pendukung: Autentikasi & Pengaturan Ringkas (`Auth & Settings`)

1. **Alur Login & Sign Up (`lib/features/auth/`)**: Gunakan [Supabase Auth](https://supabase.com/docs/guides/auth) berbasis Email & Password. Khusus mode *debug/testing* (`kDebugMode`), sediakan tombol cepat **Demo Login (Owner)** dan **Demo Login (Viewer)** agar skrip pengujian **Maestro** dan **Ruby** dapat langsung berpindah akun untuk menguji `TC-SYNC-01` s/d `TC-SYNC-04` tanpa terhambat verifikasi OTP email.
2. **Halaman Settings Ringkas (`lib/features/settings/`)**: Sediakan halaman pengaturan minimalis yang mencakup:
   * **Info Akun & Tombol Logout**: Menampilkan email pengguna aktif dan tombol keluar untuk berganti peran akun.
   * **Atur Batas Anggaran Bulanan (`TC-VIS-02`)**: Formulir untuk mengubah `limit_amount` per kategori ke tabel `budgets` Supabase (misalnya menetapkan batas `Rp1.000.000` sebelum menguji transisi warna Hijau -> Kuning -> Merah).
   * **Toggle Keamanan (Opsional)**: Kunci PIN/Biometrik harus dalam kondisi **nonaktif secara default** agar tidak memblokir `launchApp` pada pengujian otomatis Maestro.

## 6. Standar Identifier UI untuk Pengujian Maestro Studio, scrcpy, dan Ruby

Agar skrip pengujian otomatis di [Maestro Studio](https://docs.maestro.dev/maestro-studio/run-tests-with-maestro-studio) dapat mengenali elemen UI secara konsisten, agen AI wajib menyematkan `Semantics(identifier: ...)` atau `Key(...)` berikut pada komponen Flutter:

| Modul | Komponen UI | Identifier Wajib (`testId` / `Semantics`) |
| ----- | ----- | ----- |
| **Auth** | Input email & password login | `input_login_email`, `input_login_password` |
| **Auth** | Tombol masuk, Google Sign-In, daftar, & quick demo login | `btn_login`, `btn_google_login`, `btn_go_register`, `btn_demo_owner`, `btn_demo_viewer` |
| **OCR Scan** | Tombol buka kamera/galeri struk | `btn_scan_receipt` |
| **OCR Scan** | Kolom pratinjau merchant & total nominal | `input_ocr_merchant`, `input_ocr_total` |
| **OCR Scan** | Tombol simpan hasil ekstraksi OCR | `btn_save_ocr_tx` |
| **FinGPT AI** | Kolom input pesan chat & tombol kirim | `input_fingpt_chat`, `btn_send_fingpt` |
| **FinGPT AI** | Kartu konfirmasi transaksi AI & tombol simpan | `card_ai_confirmation`, `btn_confirm_ai_tx` |
| **Shared Sync** | Pengalih Mode/Dompet, status sinkronisasi, & peran anggota | `btn_wallet_switcher`, `badge_sync_status`, `badge_member_role` |
| **Shared Sync** | Kelola anggota & dropdown izin peran (`owner` / `editor` / `viewer`) | `btn_manage_members`, `dropdown_member_role` |
| **Shared Sync** | Tombol edit & hapus pada item transaksi | `btn_edit_tx`, `btn_delete_tx` |
| **Grafik Vis** | Komponen Donut Chart & Progress Bar anggaran | `chart_monthly_donut`, `progress_budget_bar` |
| **Grafik Vis** | Filter bulan & filter jenis dompet | `filter_month_selector`, `filter_wallet_type` |
| **Settings** | Tombol buka pengaturan, ganti foto profil, & tombol logout | `btn_open_settings`, `btn_change_avatar`, `btn_logout` |
| **Settings** | Input batas budget bulanan & tombol simpan | `input_budget_limit`, `btn_save_budget` |

## 7. Daftar Periksa Verifikasi Agen (Definition of Done)

Sebelum agen menyatakan sebuah tugas selesai di [Antigravity IDE](https://antigravity.google/docs/agent/), agen wajib memastikan:

* Tidak ada ketergantungan atau kode Firebase yang tersisa; seluruh koneksi mengarah ke [Supabase](https://supabase.com/docs).
* Skema migrasi SQL dan kebijakan RLS di `supabase/migrations/` bebas dari galat sintaks.
* Alur Login/Logout dan pengaturan batas anggaran berfungsi tanpa menghambat skrip pengujian otomatis.
* Seluruh 16 skenario uji pada PRD (`TC-OCR-01` s/d `TC-OCR-04`, `TC-AI-01` s/d `TC-AI-04`, `TC-SYNC-01` s/d `TC-SYNC-04`, dan `TC-VIS-01` s/d `TC-VIS-04`) memiliki padanan skrip `.yaml` di `maestro/flows/` dan dapat dieksekusi melalui `ruby qa/run_tests.rb`.