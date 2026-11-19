# Finku: Budget & Money Manager (`finku_app`)

Aplikasi mobile & web manajemen keuangan pribadi dan kolaboratif berbasis **Flutter + Riverpod** dengan backend eksklusif **Supabase** (PostgreSQL 17, Auth, Realtime, dan Storage).

> Dokumen terkait proyek:
> - Product Requirements Document: [`prd.md`](prd.md)
> - Aturan Arsitektur & Invarian: [`GEMINI.md`](GEMINI.md)
> - Token Sistem Desain: [`DESIGN.md`](DESIGN.md)

---

## Daftar Isi

1. [Fitur Utama](#1-fitur-utama)
2. [Tech Stack & Struktur Proyek](#2-tech-stack--struktur-proyek)
3. [Tutorial Instalasi & Menjalankan Aplikasi](#3-tutorial-instalasi--menjalankan-aplikasi)
4. [Tutorial Konfigurasi Supabase & Google OAuth](#4-tutorial-konfigurasi-supabase--google-oauth)
5. [Data Referensi Proyek (Akun QA, Dompet, Kategori & Preset)](#5-data-referensi-proyek)
6. [Tutorial Pengujian & QA Automation](#6-tutorial-pengujian--qa-automation)

---

## 1. Fitur Utama

* **Autentikasi & Onboarding Otomatis (`lib/features/auth/`)**
  * Login & Daftar Akun Baru (Email + Password) dengan pesan error `AuthException` berbahasa Indonesia.
  * **Masuk dengan Google** menggunakan native `google_sign_in` + `signInWithIdToken` (jika `GOOGLE_WEB_CLIENT_ID` dikonfigurasi) atau fallback otomatis ke `signInWithOAuth` Supabase.
  * Trigger PostgreSQL `on_auth_user_created` otomatis membuat baris profil di `public.profiles` dan **1 Dompet Pribadi (`"Dompet Pribadi"`)** sebagai `owner` untuk setiap pendaftar baru.
* **Modul 1 — OCR Scan Struk (`lib/features/ocr_scan/`)**
  * Mendukung kamera, galeri (`image_picker`), dan 4 preset sampel uji (`TC-OCR-01` s/d `TC-OCR-04`).
  * Pra-pemrosesan citra (*auto-crop*, *deskew* hingga `30°`, *contrast stretching*) berjalan di isolate (`compute()`) sebelum ekstraksi `Google ML Kit Text Recognition`.
  * Normalisasi angka multi-format (`15.000`, `Rp 25.604,-`, `15,000.00`) via `CurrencyNormalizer.parseRupiah` dan formulir pratinjau (*Review Form*) sebelum simpan.
* **Modul 2 — FinGPT AI Chat (`lib/features/fingpt_chat/`)**
  * Terhubung ke **Gemini 2.5 Flash** (*Structured JSON Mode*) bila `GEMINI_API_KEY` disertakan, serta memiliki **parser NLP lokal berkecepatan tinggi** sebagai fallback otomatis (`< 2.0 detik`).
  * Memecah kalimat majemuk bahasa sehari-hari/slang (`rb`, `ribu`, `k`, `jt`) beserta sumber dompet (`OVO`, `GoPay`, `DANA`, dll.), menolak kalimat ambigu tanpa nominal (anti transaksi `Rp0`), memetakan ke 8 kategori baku, dan menjawab pertanyaan analitik anggaran.
* **Modul 3 — Mode Biasa, Mode Bersama & Offline Sync (`lib/features/shared_wallet/`)**
  * Setiap pengguna memiliki penuh **Mode Biasa (Dompet Pribadi)** sebagai `Owner`, sekaligus dapat membuat atau bergabung ke **Mode Bersama (Shared Wallet)** via `WalletSwitcherBar` (`btn_wallet_switcher`).
  * **RBAC per-Dompet** (`owner`, `editor`, `viewer` di `public.wallet_members`): Owner dapat membuka modal **Kelola Anggota & Izin** untuk mengubah peran anggota (`Editor` ↔ `Viewer`) atau mengeluarkan anggota. Peran `Viewer` dibatasi *read-only* di UI dan ditolak oleh Supabase RLS.
  * Sinkronisasi *real-time* lintas perangkat (`< 1.5 detik`) via Supabase Realtime `stream()`, serta antrean lokal SQLite (`OfflineSyncEngine`) dengan UUID v4 `client_tx_id` dan resolusi *Last-Write-Wins*.
* **Modul 4 — Dashboard Visualisasi Anggaran (`lib/features/budget_analytics/`)**
  * *Summary Card* + *Bar Chart* tren mingguan (`M1`–`M4`), *Donut Chart* proporsi kategori (`fl_chart` dengan `RepaintBoundary`), dan *Progress Bar* ambang batas anggaran (Hijau `< 75%`, Kuning `75%–90%`, Merah `> 90%` / *overbudget*).
  * Mendukung filter bulan (termasuk *Empty State* bulan kosong) dan pengalih dompet pribadi/bersama.
* **Settings & Profil (`lib/features/settings/`)**
  * **Ganti Foto Profil** (`image_picker` Galeri/Kamera → upload ke Supabase Storage bucket `avatars` → simpan URL ke `public.profiles.avatar_url`).
  * Edit **Nama Lengkap**, atur **Batas Anggaran Bulanan** sesuai hak akses dompet aktif, toggle keamanan PIN/Biometrik (default nonaktif), dan **Logout**.

---

## 2. Tech Stack & Struktur Proyek

| Lapisan | Teknologi / Paket |
| :--- | :--- |
| **Framework & State** | Flutter (`Dart ^3.7.0`), `flutter_riverpod: ^2.6.1`, `google_fonts: ^6.2.1` |
| **Backend & Database** | `supabase_flutter: ^2.8.0` (PostgreSQL 17, Auth, Realtime, Storage) |
| **Google Sign-In & Media** | `google_sign_in: ^6.2.2`, `image_picker: ^1.1.2` |
| **OCR & Image Processing** | `google_mlkit_text_recognition: ^0.14.0`, `image: ^4.3.0` |
| **AI & HTTP** | Gemini API (`gemini-2.5-flash`), `http: ^1.2.2` |
| **Offline & Utilitas** | `sqflite: ^2.4.1`, `path: ^1.9.0`, `uuid: ^4.5.1`, `intl: ^0.19.0`, `shared_preferences: ^2.3.3` |
| **Visualisasi Grafik** | `fl_chart: ^0.69.0` |
| **QA & Automation** | `flutter_test`, Maestro (`maestro/flows/*.yaml`), `scrcpy`, Ruby (`qa/run_tests.rb`) |

```text
finku_app/
├── GEMINI.md                                        # Aturan arsitektur & invarian proyek
├── prd.md                                           # Product Requirements Document lengkap
├── DESIGN.md                                        # Token desain Stitch (warna & tipografi)
├── pubspec.yaml                                     # Daftar dependensi Flutter
├── lib/
│   ├── main.dart                                    # Entry point, Supabase.initialize & FinkuHomeShell
│   ├── core/
│   │   ├── config/supabase_config.dart              # Konfigurasi Supabase, OAuth & akun demo QA
│   │   ├── constants/category_taxonomy.dart         # 8 kategori resmi + normalisasi keyword
│   │   ├── sync/offline_sync_engine.dart            # Antrean SQLite offline & upsert LWW
│   │   ├── theme/app_theme.dart                     # Palet FinkuColors & tipografi FinkuTypography
│   │   ├── utils/currency_normalizer.dart           # Parser & formatter Rupiah multi-format
│   │   └── widgets/finku_app_bar.dart               # Header global dengan foto avatar & Settings
│   └── features/
│       ├── auth/                                    # Login, Sign Up, Google Sign-In & AuthNotifier
│       ├── budget_analytics/                        # Dashboard grafik, Donut Chart & thresholds
│       ├── fingpt_chat/                             # Layanan FinGPT (Gemini + lokal) & UI Chat
│       ├── ocr_scan/                                # ImagePreprocessor, OcrService & Review Form
│       ├── settings/                                # Upload avatar, edit nama, budget & logout
│       └── shared_wallet/                           # WalletSwitcherBar, Kelola Anggota & Realtime
├── supabase/migrations/
│   ├── 001_initial_schema_and_rls.sql               # Skema inti, RLS, trigger awal & Realtime
│   └── 002_profiles_avatar_and_shared_wallet_rbac.sql # avatar_url, bucket avatars & hardening RPC
├── maestro/
│   ├── flows/                                       # tc_ocr_scan, tc_ai_fingpt, tc_sync_shared_wallet, tc_vis_budget_chart
│   └── test_assets/receipt_samples.json             # 4 sampel data uji OCR
├── qa/
│   ├── run_tests.rb                                 # Verifikasi zero-Firebase, 31 Semantics & laporan KPI
│   └── reports/latest_qa_report.json
└── test/finku_app_test.dart                         # Unit & Widget tests
```

---

## 3. Tutorial Instalasi & Menjalankan Aplikasi

### Langkah 1: Siapkan Flutter & Developer Mode Windows
1. Pastikan **Developer Mode** aktif di Windows agar Flutter dapat membuat *symlink* plugin (`google_sign_in`, `image_picker`, dll.):
   ```powershell
   start ms-settings:developers
   ```
   Aktifkan toggle **Developer Mode**, lalu tutup Pengaturan.
2. Jika perintah `flutter` belum ada di `PATH` PowerShell, tambahkan sementara (atau gunakan path lengkap `D:\flutter\bin\flutter.bat`):
   ```powershell
   $env:Path += ";D:\flutter\bin"
   ```

### Langkah 2: Unduh Dependensi & Cek Kode
```powershell
flutter pub get
flutter analyze
flutter test
```

### Langkah 3: Jalankan Aplikasi

#### A. Menjalankan di Browser (Chrome / Web)
Disarankan memakai port tetap `3000` agar callback **Google OAuth** langsung kembali ke aplikasi tanpa error port:
```powershell
flutter run -d chrome --web-port=3000
```

#### B. Menjalankan di Android / iOS Emulator atau Perangkat Fisik
```powershell
flutter run
```

#### C. Menjalankan dengan Gemini AI Live & Native Google Sign-In (Opsional)
Kirim kunci melalui `--dart-define`:
```powershell
flutter run -d chrome --web-port=3000 `
  --dart-define=GEMINI_API_KEY=AIzaSy_API_KEY_ANDA `
  --dart-define=GOOGLE_WEB_CLIENT_ID=CLIENT_ID_WEB.apps.googleusercontent.com
```
* Jika `GEMINI_API_KEY` tidak diisi, **FinGPT** otomatis menggunakan parser NLP lokal deterministik.
* Jika `GOOGLE_WEB_CLIENT_ID` tidak diisi pada mobile, tombol **Masuk dengan Google** otomatis menggunakan alur browser `signInWithOAuth`.

---

## 4. Tutorial Konfigurasi Supabase & Google OAuth

### 4.1 Detail Proyek & Skema Database
* **Supabase URL**: `https://iooikaujumrwupsfcire.supabase.co`
* **File Migrasi** (sudah diterapkan ke proyek live):
  1. [`supabase/migrations/001_initial_schema_and_rls.sql`](supabase/migrations/001_initial_schema_and_rls.sql) — Membuat enum (`wallet_role`, `tx_source`), tabel (`profiles`, `wallets`, `wallet_members`, `budgets`, `transactions`), fungsi helper `SECURITY DEFINER`, RLS, dan publikasi Realtime (`transactions`, `budgets`).
  2. [`supabase/migrations/002_profiles_avatar_and_shared_wallet_rbac.sql`](supabase/migrations/002_profiles_avatar_and_shared_wallet_rbac.sql) — Menambah kolom `profiles.avatar_url`, memperbarui trigger `on_auth_user_created`, menambah RPC `create_shared_wallet` & `join_wallet_by_invite`, membuat bucket Storage **`avatars`** (publik, maks 5 MB, MIME `image/jpeg`/`image/png`/`image/webp`) beserta 4 kebijakan RLS `storage.objects`, publikasi Realtime `wallet_members`, serta indeks FK.

Jika suatu saat Anda memindahkan ke proyek Supabase baru, jalankan kedua file SQL di atas secara berurutan di **Supabase Dashboard → SQL Editor**.

### 4.2 Konfigurasi Email Sign Up (Mengatasi `429 Rate Limit`)
* Layanan SMTP bawaan Supabase membatasi pengiriman email konfirmasi (~2 email/jam).
* Untuk pengembangan/pengujian lokal agar pendaftar baru langsung masuk tanpa kena `429 (email rate limit exceeded)`:
  1. Buka **Authentication → Sign In / Providers → User Signups** (atau **Authentication → Settings**).
  2. Matikan (**OFF**) opsi **Confirm email**, lalu klik **Save**.
  3. Gunakan alamat email dengan domain valid (hindari domain dummy seperti `@email.com` yang sering ditolak filter `email_address_invalid` Supabase).
* Untuk produksi, pasang **Custom SMTP** (Resend / Brevo / SendGrid) di **Project Settings → Authentication → SMTP Settings**.

### 4.3 Konfigurasi Google OAuth
1. Di **Google Cloud Console** (*APIs & Services → Credentials*):
   * Buat OAuth Client ID bertipe **Web application**.
   * Tambahkan ke **Authorized redirect URIs**:
     ```text
     https://iooikaujumrwupsfcire.supabase.co/auth/v1/callback
     ```
2. Di **Supabase Dashboard → Authentication → Sign In / Providers → Google**:
   * Aktifkan **Enable Sign in with Google**, lalu masukkan **Client ID** dan **Client Secret** dari Google Cloud Console.
3. Di **Supabase Dashboard → Authentication → URL Configuration → Redirect URLs**:
   * Tambahkan URL berikut (perhatikan skema mobile **tanpa underscore** sesuai standar RFC 3986):
     ```text
     com.finku.app://login-callback
     http://localhost:**
     ```
4. Deep link sudah dikonfigurasi di aplikasi pada:
   * [`lib/core/config/supabase_config.dart`](lib/core/config/supabase_config.dart) (`oauthRedirectUrl = 'com.finku.app://login-callback'`)
   * [`android/app/src/main/AndroidManifest.xml`](android/app/src/main/AndroidManifest.xml)
   * [`ios/Runner/Info.plist`](ios/Runner/Info.plist)

---

## 5. Data Referensi Proyek

### 5.1 Akun Demo QA & Seed Database
*(Tersedia juga tombol cepat **Demo Owner** & **Demo Anggota** di layar Login)*

| Nama | Email | Password | User UUID | Peran di Mode Biasa (`Dompet Pribadi`) | Peran di Dompet Bersama (`Anggaran Rumah Tangga & Kos`) |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Budi Santoso** | `budi.santoso@email.com` | `rahasia123` | `11111111-1111-4111-8111-111111111111` | `owner` | `owner` |
| **Sinta Dewi** | `sinta.dewi@email.com` | `rahasia123` | `22222222-2222-4222-8222-222222222222` | `owner` | `editor` |
| **Raka Pratama** | `raka.pratama@email.com` | `rahasia123` | `33333333-3333-4333-8333-333333333333` | `owner` | `viewer` (*Read-Only*) |

* **ID Dompet Seed Pribadi Budi**: `aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa`
* **ID Dompet Seed Bersama**: `bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb`
* **Kode Undangan Dompet Bersama Seed**: `KOS-2026-FNK`

### 5.2 Taksonomi 8 Kategori Resmi & Warna Ambang Batas
Didefinisikan di [`lib/core/constants/category_taxonomy.dart`](lib/core/constants/category_taxonomy.dart) dan [`lib/features/budget_analytics/domain/models/budget_summary.dart`](lib/features/budget_analytics/domain/models/budget_summary.dart):

1. `Makanan & Minuman` (`#006B2C`)
2. `Transportasi` (`#0051D5`)
3. `Belanja Harian` (`#F59E0B`)
4. `Tagihan & Utilitas` (`#8B5CF6`)
5. `Hiburan & Gaya Hidup` (`#EC4899`)
6. `Kesehatan` (`#0D9488`)
7. `Pendidikan` (`#6366F1`)
8. `Lainnya` (`#64748B`)

**Kode Warna Ambang Batas Anggaran**:
* `< 75%` dari `limit_amount` → **Hijau / Aman** (`#16A34A`)
* `75% – 90%` dari `limit_amount` → **Kuning / Waspada** (`#D97706`)
* `> 90%` / *overbudget* → **Merah / Kritis** (`#DC2626`)

### 5.3 Sampel Uji OCR (`maestro/test_assets/receipt_samples.json`)

| Preset ID | Kondisi Uji | Merchant | Total Nominal | Kategori |
| :--- | :--- | :--- | :--- | :--- |
| `TC-OCR-01` | Struk cetak jelas (`0°`) | Indomaret Sudirman | `Rp 25.604` | `Belanja Harian` |
| `TC-OCR-02` | Struk kusut/pudar (*contrast stretch*, `4.5°`) | Alfamart Kemang | `Rp 35.000` | `Belanja Harian` |
| `TC-OCR-03` | Struk miring (`30°`, *auto-deskew*) | Superindo Dago | `Rp 84.000` | `Belanja Harian` |
| `TC-OCR-04` | Multi-format (`45,000.00`, `88,000.00`) | Starbucks Reserve | `Rp 88.000` | `Makanan & Minuman` |

---

## 6. Tutorial Pengujian & QA Automation

### 6.1 Unit & Widget Tests
Menjalankan pengujian parser `CurrencyNormalizer`, `OcrService`, `FinGptService`, `OfflineSyncEngine`, guard RBAC, kalkulasi `BudgetSummary`, dan audit *Semantics identifier*:
```powershell
flutter test
```

### 6.2 Audit QA Runner (`qa/run_tests.rb`)
Memeriksa bebas dependensi Firebase, kelengkapan **31 *Semantics identifier*** di `lib/`, dan menyusun laporan ke `qa/reports/latest_qa_report.json`:
```powershell
ruby qa/run_tests.rb
```
Untuk menjalankan skrip **Maestro** langsung pada perangkat/emulator Android yang terhubung (pantau layar via `scrcpy`):
```powershell
$env:RUN_MAESTRO_LIVE="1"
ruby qa/run_tests.rb
```

### 6.3 Menjalankan Alur Maestro per Modul (16 Skenario TC)
```powershell
maestro test maestro/flows/tc_ocr_scan.yaml           # TC-OCR-01 s/d TC-OCR-04
maestro test maestro/flows/tc_ai_fingpt.yaml          # TC-AI-01 s/d TC-AI-04
maestro test maestro/flows/tc_sync_shared_wallet.yaml # TC-SYNC-01 s/d TC-SYNC-04
maestro test maestro/flows/tc_vis_budget_chart.yaml   # TC-VIS-01 s/d TC-VIS-04
```

**Daftar 31 *Semantics Identifier* UI Wajib**:
* **Auth**: `input_login_email`, `input_login_password`, `btn_login`, `btn_google_login`, `btn_go_register`, `btn_demo_owner`, `btn_demo_viewer`
* **OCR Scan**: `btn_scan_receipt`, `input_ocr_merchant`, `input_ocr_total`, `btn_save_ocr_tx`
* **FinGPT AI**: `input_fingpt_chat`, `btn_send_fingpt`, `card_ai_confirmation`, `btn_confirm_ai_tx`
* **Shared Sync**: `btn_wallet_switcher`, `badge_sync_status`, `badge_member_role`, `btn_manage_members`, `dropdown_member_role`, `btn_edit_tx`, `btn_delete_tx`
* **Grafik Vis**: `chart_monthly_donut`, `progress_budget_bar`, `filter_month_selector`, `filter_wallet_type`
* **Settings**: `btn_open_settings`, `btn_change_avatar`, `input_budget_limit`, `btn_save_budget`, `btn_logout`
