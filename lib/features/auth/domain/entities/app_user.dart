/// Entitas pengguna terautentikasi di Finku.
/// Setiap akun adalah pengguna normal yang memiliki penuh Dompet Pribadi (Mode Biasa).
/// Hak akses kolaborasi (`owner`, `editor`, `viewer`) ditentukan per-dompet di `wallet_members`.
class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.fullName,
    required this.avatarInitials,
    this.avatarUrl,
    this.isDemoMode = false,
  });

  final String id;
  final String email;
  final String fullName;
  final String avatarInitials;
  final String? avatarUrl;
  final bool isDemoMode;

  static String computeInitials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'FK';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    final lettersOnly = trimmed.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    if (lettersOnly.length >= 2) {
      return lettersOnly.substring(0, 2).toUpperCase();
    }
    if (lettersOnly.length == 1) {
      return lettersOnly.toUpperCase();
    }
    return 'FK';
  }

  AppUser copyWith({
    String? id,
    String? email,
    String? fullName,
    String? avatarInitials,
    String? avatarUrl,
    bool clearAvatarUrl = false,
    bool? isDemoMode,
  }) {
    return AppUser(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      avatarInitials: avatarInitials ?? this.avatarInitials,
      avatarUrl: clearAvatarUrl ? null : (avatarUrl ?? this.avatarUrl),
      isDemoMode: isDemoMode ?? this.isDemoMode,
    );
  }
}
