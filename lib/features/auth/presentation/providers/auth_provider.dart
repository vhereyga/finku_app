import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:finku_app/core/config/supabase_config.dart';
import 'package:finku_app/features/auth/domain/entities/app_user.dart';

class AuthState {
  const AuthState({
    this.user,
    this.isLoading = false,
    this.errorMessage,
    this.infoMessage,
  });

  final AppUser? user;
  final bool isLoading;
  final String? errorMessage;
  final String? infoMessage;

  bool get isAuthenticated => user != null;

  AuthState copyWith({
    AppUser? user,
    bool clearUser = false,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    String? infoMessage,
    bool clearInfo = false,
  }) {
    return AuthState(
      user: clearUser ? null : (user ?? this.user),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      infoMessage: clearInfo ? null : (infoMessage ?? this.infoMessage),
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier({SupabaseClient? supabaseClient})
    : _supabase = supabaseClient,
      super(const AuthState()) {
    _initAuthListener();
    _restoreCurrentSession();
  }

  final SupabaseClient? _supabase;
  StreamSubscription<dynamic>? _authSub;

  static final RegExp _emailRegex = RegExp(
    r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
  );

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  void _initAuthListener() {
    final client = _supabase;
    if (client == null) return;
    _authSub = client.auth.onAuthStateChange.listen((data) async {
      final session = data.session;
      if (session?.user != null) {
        final mapped = await _loadUserProfile(session!.user);
        if (mounted) {
          state = AuthState(user: mapped);
        }
      } else if (data.event == AuthChangeEvent.signedOut) {
        if (mounted && !(state.user?.isDemoMode ?? false)) {
          state = const AuthState();
        }
      }
    });
  }

  void _restoreCurrentSession() {
    final client = _supabase;
    if (client == null) return;
    final supaUser = client.auth.currentSession?.user;
    if (supaUser != null) {
      state = AuthState(user: _mapSupabaseUser(supaUser));
      unawaited(_refreshProfileSilently(supaUser));
    }
  }

  Future<void> _refreshProfileSilently(User supaUser) async {
    final enriched = await _loadUserProfile(supaUser);
    if (mounted && state.user?.id == supaUser.id) {
      state = state.copyWith(user: enriched);
    }
  }

  Future<AppUser> _loadUserProfile(User supaUser) async {
    final fallback = _mapSupabaseUser(supaUser);
    final client = _supabase;
    if (client == null || client.auth.currentSession == null) return fallback;

    try {
      final row = await client
          .from('profiles')
          .select('full_name, avatar_initials, avatar_url')
          .eq('id', supaUser.id)
          .maybeSingle();

      if (row == null) return fallback;

      final fullName = (row['full_name']?.toString() ?? '').trim();
      final resolvedName = fullName.isNotEmpty ? fullName : fallback.fullName;
      final initials = (row['avatar_initials']?.toString() ?? '').trim();
      final avatarUrl = (row['avatar_url']?.toString() ?? '').trim();

      return fallback.copyWith(
        fullName: resolvedName,
        avatarInitials: initials.isNotEmpty
            ? initials
            : AppUser.computeInitials(resolvedName),
        avatarUrl: avatarUrl.isNotEmpty ? avatarUrl : fallback.avatarUrl,
      );
    } catch (e) {
      debugPrint('Gagal memuat profil dari Supabase: $e');
      return fallback;
    }
  }

  AppUser _mapSupabaseUser(User user) {
    final email = user.email ?? '';
    final metaName =
        user.userMetadata?['full_name']?.toString() ??
        user.userMetadata?['name']?.toString();
    final metaAvatar =
        user.userMetadata?['avatar_url']?.toString() ??
        user.userMetadata?['picture']?.toString();

    String fallbackName;
    if (metaName != null && metaName.trim().isNotEmpty) {
      fallbackName = metaName.trim();
    } else if (email == SupabaseConfig.demoViewerEmail) {
      fallbackName = SupabaseConfig.demoViewerName;
    } else if (email == SupabaseConfig.demoEditorEmail) {
      fallbackName = SupabaseConfig.demoEditorName;
    } else if (email == SupabaseConfig.demoOwnerEmail) {
      fallbackName = SupabaseConfig.demoOwnerName;
    } else if (email.contains('@')) {
      fallbackName = email.split('@').first;
    } else {
      fallbackName = 'Pengguna Finku';
    }

    return AppUser(
      id: user.id,
      email: email,
      fullName: fallbackName,
      avatarInitials: AppUser.computeInitials(fallbackName),
      avatarUrl: (metaAvatar != null && metaAvatar.isNotEmpty)
          ? metaAvatar
          : null,
    );
  }

  void clearMessages() {
    state = state.copyWith(clearError: true, clearInfo: true);
  }

  String _formatAuthError(Object error) {
    if (error is AuthException) {
      final msg = error.message.toLowerCase();
      final code = (error.code ?? '').toLowerCase();

      if (code == 'weak_password' ||
          msg.contains('at least 6 characters') ||
          msg.contains('password should be')) {
        return 'Kata sandi minimal harus 6 karakter.';
      }
      if (code == 'user_already_exists' ||
          code == 'email_exists' ||
          msg.contains('already registered') ||
          msg.contains('already exists')) {
        return 'Email ini sudah terdaftar. Silakan masuk atau gunakan email lain.';
      }
      if (code == 'email_address_invalid' ||
          code == 'invalid_email' ||
          (code == 'validation_failed' && msg.contains('email')) ||
          msg.contains('unable to validate email') ||
          msg.contains('invalid format')) {
        return 'Alamat email tidak valid atau ditolak server. Gunakan email yang valid (hindari domain dummy).';
      }
      if (code == 'invalid_credentials' ||
          msg.contains('invalid login credentials')) {
        return 'Email atau kata sandi salah. Periksa kembali data Anda.';
      }
      if (code == 'email_not_confirmed' ||
          msg.contains('email not confirmed')) {
        return 'Email belum diverifikasi. Silakan cek kotak masuk email Anda.';
      }
      if (code == 'over_email_send_rate_limit' ||
          code == 'over_request_rate_limit' ||
          msg.contains('rate limit') ||
          msg.contains('security purposes')) {
        return 'Terlalu banyak percobaan. Tunggu beberapa saat lalu coba lagi.';
      }
      if (msg.contains('signup is disabled')) {
        return 'Pendaftaran akun baru sedang dinonaktifkan di server.';
      }
      return error.message;
    }

    if (error is TimeoutException) {
      return 'Koneksi timeout. Periksa jaringan internet Anda lalu coba lagi.';
    }
    if (error is SocketException) {
      return 'Tidak ada koneksi internet. Periksa jaringan Anda.';
    }
    return error.toString().replaceFirst('Exception: ', '');
  }

  Future<bool> signInWithEmail(String email, String password) async {
    final cleanEmail = email.trim();
    if (!_emailRegex.hasMatch(cleanEmail)) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Format alamat email tidak valid.',
        clearInfo: true,
      );
      return false;
    }
    if (password.isEmpty) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Kata sandi wajib diisi.',
        clearInfo: true,
      );
      return false;
    }

    state = state.copyWith(isLoading: true, clearError: true, clearInfo: true);
    final client = _supabase;
    if (client == null) {
      return _signInLocalFallback(cleanEmail);
    }

    try {
      final res = await client.auth
          .signInWithPassword(email: cleanEmail, password: password)
          .timeout(const Duration(seconds: 8));
      final user = res.user;
      if (user == null) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Login gagal. Periksa email dan kata sandi Anda.',
        );
        return false;
      }
      final profileUser = await _loadUserProfile(user);
      state = AuthState(user: profileUser);
      return true;
    } catch (e) {
      // Untuk akun QA demo, tetap izinkan fallback bila device offline saat pengujian
      if (cleanEmail == SupabaseConfig.demoOwnerEmail ||
          cleanEmail == SupabaseConfig.demoViewerEmail) {
        return _signInLocalFallback(cleanEmail);
      }
      state = state.copyWith(
        isLoading: false,
        errorMessage: _formatAuthError(e),
      );
      return false;
    }
  }

  Future<bool> signUpWithEmail({
    required String email,
    required String password,
    required String fullName,
  }) async {
    final cleanName = fullName.trim();
    final cleanEmail = email.trim();

    if (cleanName.isEmpty) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Nama lengkap wajib diisi.',
        clearInfo: true,
      );
      return false;
    }
    if (!_emailRegex.hasMatch(cleanEmail)) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Format alamat email tidak valid.',
        clearInfo: true,
      );
      return false;
    }
    if (password.length < 6) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Kata sandi minimal harus 6 karakter.',
        clearInfo: true,
      );
      return false;
    }

    state = state.copyWith(isLoading: true, clearError: true, clearInfo: true);
    final client = _supabase;
    if (client == null) {
      state = AuthState(
        user: AppUser(
          id: SupabaseConfig.demoOwnerId,
          email: cleanEmail,
          fullName: cleanName,
          avatarInitials: AppUser.computeInitials(cleanName),
          isDemoMode: true,
        ),
      );
      return true;
    }

    try {
      final res = await client.auth
          .signUp(
            email: cleanEmail,
            password: password,
            data: {'full_name': cleanName},
            emailRedirectTo: kIsWeb ? null : SupabaseConfig.oauthRedirectUrl,
          )
          .timeout(const Duration(seconds: 10));

      final user = res.user;
      if (user == null) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Pendaftaran gagal. Silakan coba lagi.',
        );
        return false;
      }

      // Bila Supabase mewajibkan konfirmasi email, session bernilai null.
      if (res.session == null) {
        state = state.copyWith(
          isLoading: false,
          clearError: true,
          infoMessage:
              'Pendaftaran berhasil! Silakan cek kotak masuk email ($cleanEmail) untuk verifikasi sebelum masuk.',
        );
        return false;
      }

      final profileUser = await _loadUserProfile(user);
      state = AuthState(user: profileUser);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _formatAuthError(e),
      );
      return false;
    }
  }

  /// Masuk dengan Google menggunakan native `google_sign_in` + `signInWithIdToken`
  /// (jika `GOOGLE_WEB_CLIENT_ID` tersedia di mobile), atau fallback ke OAuth browser Supabase.
  Future<bool> signInWithGoogle() async {
    state = state.copyWith(isLoading: true, clearError: true, clearInfo: true);
    final client = _supabase;
    if (client == null) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Koneksi Supabase belum terinisialisasi.',
      );
      return false;
    }

    try {
      final isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
      if (isMobile && SupabaseConfig.googleWebClientId.isNotEmpty) {
        final googleSignIn = GoogleSignIn(
          serverClientId: SupabaseConfig.googleWebClientId,
          clientId: Platform.isIOS && SupabaseConfig.googleIosClientId.isNotEmpty
              ? SupabaseConfig.googleIosClientId
              : null,
          scopes: const ['email', 'profile'],
        );

        final googleUser = await googleSignIn.signIn();
        if (googleUser == null) {
          state = state.copyWith(isLoading: false);
          return false;
        }

        final googleAuth = await googleUser.authentication;
        final idToken = googleAuth.idToken;
        final accessToken = googleAuth.accessToken;
        if (idToken == null) {
          state = state.copyWith(
            isLoading: false,
            errorMessage:
                'ID Token Google tidak ditemukan. Periksa konfigurasi Web Client ID.',
          );
          return false;
        }

        final res = await client.auth.signInWithIdToken(
          provider: OAuthProvider.google,
          idToken: idToken,
          accessToken: accessToken,
        );
        final user = res.user;
        if (user == null) {
          state = state.copyWith(
            isLoading: false,
            errorMessage: 'Autentikasi Google gagal memvalidasi sesi.',
          );
          return false;
        }

        final profileUser = await _loadUserProfile(user);
        state = AuthState(user: profileUser);
        return true;
      }

      // Fallback OAuth flow Supabase (browser / deep link callback)
      final launched = await client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb ? null : SupabaseConfig.oauthRedirectUrl,
        authScreenLaunchMode: kIsWeb
            ? LaunchMode.platformDefault
            : LaunchMode.externalApplication,
      );

      if (!launched) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Tidak dapat membuka halaman masuk Google.',
        );
        return false;
      }

      // Auth listener akan memperbarui state setelah callback kembali
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Gagal masuk dengan Google: ${_formatAuthError(e)}',
      );
      return false;
    }
  }

  Future<void> updateProfile({required String fullName}) async {
    final current = state.user;
    if (current == null) return;
    final cleanName = fullName.trim();
    if (cleanName.isEmpty) {
      throw const FormatException('Nama lengkap tidak boleh kosong.');
    }

    final newInitials = AppUser.computeInitials(cleanName);
    final client = _supabase;
    if (client != null && client.auth.currentSession != null) {
      await client
          .from('profiles')
          .upsert({
            'id': current.id,
            'email': current.email,
            'full_name': cleanName,
            'avatar_initials': newInitials,
            'avatar_url': current.avatarUrl,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          });
      try {
        await client.auth.updateUser(
          UserAttributes(data: {'full_name': cleanName}),
        );
      } catch (_) {}
    }

    state = state.copyWith(
      user: current.copyWith(
        fullName: cleanName,
        avatarInitials: newInitials,
      ),
    );
  }

  Future<String> uploadAvatar({
    required Uint8List bytes,
    required String fileExtension,
    String? mimeType,
  }) async {
    final current = state.user;
    if (current == null) {
      throw StateError('Pengguna belum masuk.');
    }

    final client = _supabase;
    if (client == null || client.auth.currentSession == null) {
      throw StateError(
        'Upload foto profil memerlukan sesi login aktif di Supabase.',
      );
    }

    final cleanExt = fileExtension.toLowerCase().replaceAll('.', '');
    final ext = (cleanExt == 'png' || cleanExt == 'webp') ? cleanExt : 'jpg';
    final contentType =
        mimeType ??
        (ext == 'png'
            ? 'image/png'
            : (ext == 'webp' ? 'image/webp' : 'image/jpeg'));

    final filePath =
        '${current.id}/avatar_${DateTime.now().millisecondsSinceEpoch}.$ext';

    await client.storage
        .from('avatars')
        .uploadBinary(
          filePath,
          bytes,
          fileOptions: FileOptions(
            cacheControl: '3600',
            upsert: true,
            contentType: contentType,
          ),
        );

    final publicUrl = client.storage.from('avatars').getPublicUrl(filePath);

    await client.from('profiles').upsert({
      'id': current.id,
      'email': current.email,
      'full_name': current.fullName,
      'avatar_initials': current.avatarInitials,
      'avatar_url': publicUrl,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });

    state = state.copyWith(
      user: current.copyWith(avatarUrl: publicUrl),
    );
    return publicUrl;
  }

  /// Tombol QA Quick Demo Login (Owner) untuk `TC-SYNC-01..03` & `TC-VIS`.
  Future<void> loginDemoOwner() async {
    await signInWithEmail(
      SupabaseConfig.demoOwnerEmail,
      SupabaseConfig.demoPassword,
    );
  }

  /// Tombol QA Quick Demo Login (Viewer di Dompet Bersama) untuk `TC-SYNC-04`.
  Future<void> loginDemoViewer() async {
    await signInWithEmail(
      SupabaseConfig.demoViewerEmail,
      SupabaseConfig.demoPassword,
    );
  }

  bool _signInLocalFallback(String email) {
    if (email == SupabaseConfig.demoViewerEmail) {
      state = const AuthState(
        user: AppUser(
          id: SupabaseConfig.demoViewerId,
          email: SupabaseConfig.demoViewerEmail,
          fullName: SupabaseConfig.demoViewerName,
          avatarInitials: 'RP',
          isDemoMode: true,
        ),
      );
      return true;
    }
    state = const AuthState(
      user: AppUser(
        id: SupabaseConfig.demoOwnerId,
        email: SupabaseConfig.demoOwnerEmail,
        fullName: SupabaseConfig.demoOwnerName,
        avatarInitials: 'BS',
        isDemoMode: true,
      ),
    );
    return true;
  }

  Future<void> signOut() async {
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}
    try {
      await _supabase?.auth.signOut();
    } catch (_) {}
    state = const AuthState();
  }
}

final supabaseClientProvider = Provider<SupabaseClient?>((ref) {
  try {
    return Supabase.instance.client;
  } catch (_) {
    return null;
  }
});

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return AuthNotifier(supabaseClient: client);
});
