import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/supabase_config.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';

/// Halaman Login & Sign Up sesuai Stitch `Login QA & Pengaturan Anggaran` (Section A).
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _emailController = TextEditingController(
    text: SupabaseConfig.demoOwnerEmail,
  );
  final _passwordController = TextEditingController(
    text: SupabaseConfig.demoPassword,
  );
  final _nameController = TextEditingController();
  bool _obscurePassword = true;
  bool _isRegisterMode = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final notifier = ref.read(authProvider.notifier);
    if (_isRegisterMode) {
      await notifier.signUpWithEmail(
        email: _emailController.text,
        password: _passwordController.text,
        fullName: _nameController.text,
      );
    } else {
      await notifier.signInWithEmail(
        _emailController.text,
        _passwordController.text,
      );
    }
  }

  void _toggleRegisterMode() {
    ref.read(authProvider.notifier).clearMessages();
    setState(() {
      _isRegisterMode = !_isRegisterMode;
      if (_isRegisterMode &&
          _emailController.text == SupabaseConfig.demoOwnerEmail &&
          _passwordController.text == SupabaseConfig.demoPassword) {
        _emailController.clear();
        _passwordController.clear();
      } else if (!_isRegisterMode &&
          _emailController.text.isEmpty &&
          _passwordController.text.isEmpty) {
        _emailController.text = SupabaseConfig.demoOwnerEmail;
        _passwordController.text = SupabaseConfig.demoPassword;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: FinkuColors.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: FinkuColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: FinkuColors.borderSubtle),
                  boxShadow: [
                    BoxShadow(
                      color: FinkuColors.navyBase.withValues(alpha: 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Brand Header
                    Column(
                      children: [
                        Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            color: FinkuColors.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: FinkuColors.borderSubtle),
                          ),
                          child: const Icon(
                            Icons.account_balance_wallet_rounded,
                            color: FinkuColors.primaryBrand,
                            size: 30,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text('Finku', style: FinkuTypography.headlineLg()),
                        const SizedBox(height: 4),
                        Text(
                          _isRegisterMode
                              ? 'Buat Akun Baru & Mulai Kelola Anggaran'
                              : 'Kelola Anggaran & Catat Pengeluaran Cerdas',
                          textAlign: TextAlign.center,
                          style: FinkuTypography.bodySm(
                            color: FinkuColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    if (_isRegisterMode) ...[
                      Text('Nama Lengkap', style: FinkuTypography.labelMd()),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(
                            Icons.person_outline_rounded,
                            color: FinkuColors.tertiary,
                          ),
                          hintText: 'Mis. Andi Wijaya',
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Email Field (`input_login_email`)
                    Text('Alamat Email', style: FinkuTypography.labelMd()),
                    const SizedBox(height: 6),
                    Semantics(
                      identifier: 'input_login_email',
                      textField: true,
                      child: TextField(
                        key: const Key('input_login_email'),
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(
                            Icons.mail_outline_rounded,
                            color: FinkuColors.tertiary,
                          ),
                          hintText: 'nama@email.com',
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Password Field (`input_login_password`)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Kata Sandi', style: FinkuTypography.labelMd()),
                        Text(
                          _isRegisterMode ? 'Minimal 6 karakter' : 'Lupa sandi?',
                          style: FinkuTypography.labelSm(
                            color: FinkuColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Semantics(
                      identifier: 'input_login_password',
                      textField: true,
                      child: TextField(
                        key: const Key('input_login_password'),
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(
                            Icons.lock_outline_rounded,
                            color: FinkuColors.tertiary,
                          ),
                          hintText: '••••••••',
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: FinkuColors.tertiary,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (authState.errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: FinkuColors.dangerBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: FinkuColors.dangerAlert.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              size: 18,
                              color: FinkuColors.dangerAlert,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                authState.errorMessage!,
                                style: FinkuTypography.bodySm(
                                  color: FinkuColors.dangerAlert,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    if (authState.infoMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: FinkuColors.safeBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: FinkuColors.primaryBrand.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.mark_email_read_outlined,
                              size: 18,
                              color: FinkuColors.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                authState.infoMessage!,
                                style: FinkuTypography.bodySm(
                                  color: FinkuColors.onPrimaryFixedVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Primary Submit Button (`btn_login`)
                    Semantics(
                      identifier: 'btn_login',
                      button: true,
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          key: const Key('btn_login'),
                          onPressed: authState.isLoading ? null : _submit,
                          child: authState.isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      _isRegisterMode
                                          ? 'Daftar Akun Baru'
                                          : 'Masuk ke Akun',
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(
                                      Icons.arrow_forward_rounded,
                                      size: 18,
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Divider "atau"
                    Row(
                      children: [
                        const Expanded(
                          child: Divider(color: FinkuColors.borderSubtle),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            'atau',
                            style: FinkuTypography.labelSm(),
                          ),
                        ),
                        const Expanded(
                          child: Divider(color: FinkuColors.borderSubtle),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Google Sign-In Button (`btn_google_login`)
                    Semantics(
                      identifier: 'btn_google_login',
                      button: true,
                      child: SizedBox(
                        height: 48,
                        child: OutlinedButton.icon(
                          key: const Key('btn_google_login'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: FinkuColors.onSurface,
                            backgroundColor: FinkuColors.surfaceContainerLowest,
                            side: const BorderSide(
                              color: FinkuColors.borderInput,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: authState.isLoading
                              ? null
                              : () => ref
                                    .read(authProvider.notifier)
                                    .signInWithGoogle(),
                          icon: Container(
                            width: 20,
                            height: 20,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: FinkuColors.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'G',
                              style: FinkuTypography.labelMd(
                                color: FinkuColors.secondaryBrand,
                              ).copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                          label: const Text('Masuk dengan Google'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Register Toggle (`btn_go_register`)
                    Center(
                      child: Semantics(
                        identifier: 'btn_go_register',
                        button: true,
                        child: TextButton(
                          key: const Key('btn_go_register'),
                          onPressed: _toggleRegisterMode,
                          child: Text.rich(
                            TextSpan(
                              text: _isRegisterMode
                                  ? 'Sudah punya akun? '
                                  : 'Belum punya akun? ',
                              style: FinkuTypography.bodySm(
                                color: FinkuColors.onSurfaceVariant,
                              ),
                              children: [
                                TextSpan(
                                  text: _isRegisterMode
                                      ? 'Masuk Sekarang'
                                      : 'Daftar Sekarang',
                                  style: FinkuTypography.labelMd(
                                    color: FinkuColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // QA Quick Switcher Sandbox (GEMINI.md 5.5.1)
                    if (kDebugMode || true) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: FinkuColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 26,
                                  height: 26,
                                  decoration: const BoxDecoration(
                                    color: FinkuColors.secondaryContainer,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.science_rounded,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Akses Cepat Pengujian QA',
                                    style: FinkuTypography.labelMd(
                                      color: FinkuColors.onSurface,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: FinkuColors.tertiaryFixed,
                                    borderRadius: BorderRadius.circular(9999),
                                  ),
                                  child: Text(
                                    'Demo Mode',
                                    style: FinkuTypography.labelSm(
                                      color: FinkuColors.onTertiaryFixed,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            _QaDemoCard(
                              identifier: 'btn_demo_owner',
                              title: 'Demo Owner (Budi - Hak Akses Penuh)',
                              subtitle: 'Owner di Mode Biasa & Dompet Bersama',
                              dotColor: FinkuColors.primaryBrand,
                              titleColor: FinkuColors.primary,
                              icon: Icons.check_circle_rounded,
                              iconColor: FinkuColors.primary,
                              onTap: authState.isLoading
                                  ? null
                                  : () => ref
                                        .read(authProvider.notifier)
                                        .loginDemoOwner(),
                            ),
                            const SizedBox(height: 8),
                            _QaDemoCard(
                              identifier: 'btn_demo_viewer',
                              title: 'Demo Anggota (Raka - Viewer Bersama)',
                              subtitle:
                                  'Owner Dompet Pribadi • Viewer di Mode Bersama',
                              dotColor: FinkuColors.neutralSlate,
                              titleColor: FinkuColors.onSurface,
                              icon: Icons.visibility_rounded,
                              iconColor: FinkuColors.tertiary,
                              onTap: authState.isLoading
                                  ? null
                                  : () => ref
                                        .read(authProvider.notifier)
                                        .loginDemoViewer(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QaDemoCard extends StatelessWidget {
  const _QaDemoCard({
    required this.identifier,
    required this.title,
    required this.subtitle,
    required this.dotColor,
    required this.titleColor,
    required this.icon,
    required this.iconColor,
    required this.onTap,
  });

  final String identifier;
  final String title;
  final String subtitle;
  final Color dotColor;
  final Color titleColor;
  final IconData icon;
  final Color iconColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: identifier,
      button: true,
      child: Material(
        key: Key(identifier),
        color: FinkuColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: FinkuTypography.labelMd(color: titleColor),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        subtitle,
                        style: FinkuTypography.labelSm(
                          color: FinkuColors.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(icon, size: 18, color: iconColor),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
