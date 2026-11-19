/// Konfigurasi koneksi Supabase dan akun demo QA sesuai GEMINI.md.
class SupabaseConfig {
  SupabaseConfig._();

  static const String supabaseUrl = 'https://iooikaujumrwupsfcire.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imlvb2lrYXVqdW1yd3Vwc2ZjaXJlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTQ5ODgyNzYsImV4cCI6MjExMDU2NDI3Nn0.1M-gUyidVm_fI_8Z25xJxGt2F9ta4xA-gKxd-SmuEWQ';

  /// Opsional: kirim via `--dart-define=GEMINI_API_KEY=...` untuk Gemini API live.
  static const String geminiApiKey = String.fromEnvironment('GEMINI_API_KEY');

  /// Konfigurasi Google OAuth Client ID (opsional via `--dart-define`).
  /// Jika diisi, Android/iOS memakai native `google_sign_in` + `signInWithIdToken`.
  /// Jika kosong, fallback otomatis ke Supabase OAuth flow (`signInWithOAuth`).
  static const String googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
  );
  static const String googleIosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
  );
  static const String oauthRedirectUrl = 'com.finku.app://login-callback';

  /// ID dompet deterministik dari seed database Supabase.
  static const String personalWalletId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
  static const String sharedWalletId = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';

  /// Kredensial demo QA untuk pengujian cepat Maestro & Ruby (kDebugMode).
  static const String demoOwnerId = '11111111-1111-4111-8111-111111111111';
  static const String demoOwnerEmail = 'budi.santoso@email.com';
  static const String demoOwnerName = 'Budi Santoso';

  static const String demoEditorId = '22222222-2222-4222-8222-222222222222';
  static const String demoEditorEmail = 'sinta.dewi@email.com';
  static const String demoEditorName = 'Sinta Dewi';

  static const String demoViewerId = '33333333-3333-4333-8333-333333333333';
  static const String demoViewerEmail = 'raka.pratama@email.com';
  static const String demoViewerName = 'Raka Pratama';

  static const String demoPassword = 'rahasia123';
}
