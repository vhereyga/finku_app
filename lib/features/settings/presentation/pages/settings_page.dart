import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/category_taxonomy.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_normalizer.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../shared_wallet/presentation/providers/wallet_provider.dart';

/// Halaman Settings Lengkap: Profil & Avatar Supabase Storage, Batas Anggaran, & Logout.
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final _picker = ImagePicker();
  final _nameController = TextEditingController();
  final _budgetLimitController = TextEditingController(text: '1000000');
  String _selectedCategory = CategoryTaxonomy.makananMinuman;
  bool _nameInitialized = false;

  /// Wajib NONAKTIF secara default sesuai aturan GEMINI.md 5.5.2.
  bool _biometricLockEnabled = false;
  bool _isSavingBudget = false;
  bool _isSavingProfile = false;
  bool _isUploadingAvatar = false;

  @override
  void dispose() {
    _nameController.dispose();
    _budgetLimitController.dispose();
    super.dispose();
  }

  void _adjustBudget(int delta) {
    final current = CurrencyNormalizer.parseRupiah(_budgetLimitController.text);
    final next = (current + delta).clamp(100000, 100000000);
    setState(() {
      _budgetLimitController.text = next.toString();
    });
  }

  Future<void> _showAvatarSourceSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: FinkuColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: FinkuColors.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(9999),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text('Ganti Foto Profil', style: FinkuTypography.titleMd()),
                const SizedBox(height: 4),
                Text(
                  'Pilih sumber foto untuk diunggah ke profil Finku Anda.',
                  style: FinkuTypography.bodySm(),
                ),
                const SizedBox(height: 14),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: FinkuColors.surfaceContainerLow,
                    child: Icon(
                      Icons.photo_library_rounded,
                      color: FinkuColors.primary,
                    ),
                  ),
                  title: Text(
                    'Pilih dari Galeri',
                    style: FinkuTypography.labelLg(),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickAndUploadAvatar(ImageSource.gallery);
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: FinkuColors.surfaceContainerLow,
                    child: Icon(
                      Icons.camera_alt_rounded,
                      color: FinkuColors.secondaryBrand,
                    ),
                  ),
                  title: Text(
                    'Ambil dari Kamera',
                    style: FinkuTypography.labelLg(),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickAndUploadAvatar(ImageSource.camera);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickAndUploadAvatar(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (picked == null) return;

      setState(() => _isUploadingAvatar = true);
      final bytes = await picked.readAsBytes();
      final parts = picked.name.split('.');
      final ext = parts.length > 1 ? parts.last : 'jpg';

      await ref
          .read(authProvider.notifier)
          .uploadAvatar(
            bytes: bytes,
            fileExtension: ext,
            mimeType: picked.mimeType,
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Foto profil berhasil diperbarui!'),
          backgroundColor: FinkuColors.primary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mengunggah foto profil: $e'),
          backgroundColor: FinkuColors.dangerAlert,
        ),
      );
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nama lengkap tidak boleh kosong'),
          backgroundColor: FinkuColors.dangerAlert,
        ),
      );
      return;
    }

    setState(() => _isSavingProfile = true);
    try {
      await ref.read(authProvider.notifier).updateProfile(fullName: name);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profil berhasil disimpan'),
          backgroundColor: FinkuColors.primary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menyimpan profil: $e'),
          backgroundColor: FinkuColors.dangerAlert,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSavingProfile = false);
    }
  }

  Future<void> _saveBudgetLimit() async {
    final limit = CurrencyNormalizer.parseRupiah(_budgetLimitController.text);
    if (limit <= 0) return;

    setState(() => _isSavingBudget = true);
    try {
      await ref
          .read(walletProvider.notifier)
          .saveBudgetLimit(category: _selectedCategory, limitAmount: limit);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Batas anggaran disimpan: $_selectedCategory (${CurrencyNormalizer.formatRupiah(limit)})',
          ),
          backgroundColor: FinkuColors.primary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: FinkuColors.dangerAlert,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSavingBudget = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final walletState = ref.watch(walletProvider);
    final user = authState.user;
    if (!_nameInitialized && user != null) {
      _nameController.text = user.fullName;
      _nameInitialized = true;
    }

    // Hak edit anggaran mengikuti peran pada DOMPET AKTIF (Mode Biasa selalu Owner)
    final canEditActiveWallet = walletState.canEdit;
    final activeRoleLabel = walletState.activeRole == 'owner'
        ? 'Owner'
        : (walletState.activeRole == 'editor' ? 'Editor' : 'Viewer');

    return Scaffold(
      backgroundColor: FinkuColors.surface,
      appBar: AppBar(
        title: const Text('Pengaturan & Profil'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          // User Profile Summary & Avatar Upload Card (`btn_change_avatar`)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: FinkuColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: FinkuColors.borderSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: FinkuColors.primaryContainer,
                          backgroundImage:
                              (user?.avatarUrl != null &&
                                  user!.avatarUrl!.isNotEmpty)
                              ? NetworkImage(user.avatarUrl!)
                              : null,
                          child:
                              (user?.avatarUrl == null ||
                                  user!.avatarUrl!.isEmpty)
                              ? Text(
                                  user?.avatarInitials ?? 'BS',
                                  style: FinkuTypography.headlineSm(
                                    color: Colors.white,
                                  ),
                                )
                              : null,
                        ),
                        if (_isUploadingAvatar)
                          const Positioned.fill(
                            child: CircleAvatar(
                              backgroundColor: Colors.black45,
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.fullName ?? 'Pengguna Finku',
                            style: FinkuTypography.titleMd(),
                          ),
                          Text(
                            user?.email ?? 'budi.santoso@email.com',
                            style: FinkuTypography.bodySm(),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: canEditActiveWallet
                                      ? FinkuColors.primaryFixed
                                      : FinkuColors.tertiaryFixed,
                                  borderRadius: BorderRadius.circular(9999),
                                ),
                                child: Text(
                                  '${walletState.isSharedWallet ? 'Bersama' : 'Pribadi'} • $activeRoleLabel',
                                  style: FinkuTypography.labelSm(
                                    color: canEditActiveWallet
                                        ? FinkuColors.onPrimaryFixed
                                        : FinkuColors.onTertiaryFixed,
                                  ).copyWith(fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Semantics(
                  identifier: 'btn_change_avatar',
                  button: true,
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      key: const Key('btn_change_avatar'),
                      onPressed: _isUploadingAvatar
                          ? null
                          : _showAvatarSourceSheet,
                      icon: const Icon(Icons.camera_alt_outlined, size: 18),
                      label: Text(
                        _isUploadingAvatar
                            ? 'Mengunggah Foto...'
                            : 'Ganti Foto Profil',
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text('Nama Lengkap', style: FinkuTypography.labelMd()),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(
                            Icons.person_outline_rounded,
                            color: FinkuColors.tertiary,
                          ),
                          hintText: 'Masukkan nama lengkap',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isSavingProfile ? null : _saveProfile,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(92, 48),
                        ),
                        child: Text(_isSavingProfile ? '...' : 'Simpan'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Atur Batas Anggaran Bulanan Card (`input_budget_limit`, `btn_save_budget`)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: FinkuColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: FinkuColors.borderSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: FinkuColors.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.tune_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Atur Batas Anggaran',
                          style: FinkuTypography.titleMd(),
                        ),
                      ],
                    ),
                    Text(
                      walletState.selectedMonth,
                      style: FinkuTypography.labelSm(
                        color: FinkuColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Dompet aktif: ${walletState.walletTitle} ($activeRoleLabel)',
                  style: FinkuTypography.bodySm(),
                ),
                const SizedBox(height: 14),
                Text('Kategori Terpilih', style: FinkuTypography.labelMd()),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  isExpanded: true,
                  items: CategoryTaxonomy.validCategories
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedCategory = val);
                  },
                ),
                const SizedBox(height: 14),
                Text('Target Batas (IDR)', style: FinkuTypography.labelMd()),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        identifier: 'input_budget_limit',
                        textField: true,
                        child: TextField(
                          key: const Key('input_budget_limit'),
                          controller: _budgetLimitController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(prefixText: 'Rp '),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: canEditActiveWallet
                          ? () => _adjustBudget(-100000)
                          : null,
                      icon: const Icon(Icons.remove_rounded),
                      style: IconButton.styleFrom(
                        backgroundColor: FinkuColors.surfaceContainerHigh,
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      onPressed: canEditActiveWallet
                          ? () => _adjustBudget(100000)
                          : null,
                      icon: const Icon(Icons.add_rounded),
                      style: IconButton.styleFrom(
                        backgroundColor: FinkuColors.surfaceContainerHigh,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Semantics(
                  identifier: 'btn_save_budget',
                  button: true,
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      key: const Key('btn_save_budget'),
                      onPressed: (!canEditActiveWallet || _isSavingBudget)
                          ? null
                          : _saveBudgetLimit,
                      icon: const Icon(Icons.save_rounded, size: 18),
                      label: Text(
                        !canEditActiveWallet
                            ? 'Read-Only (Viewer di Dompet Ini)'
                            : (_isSavingBudget
                                  ? 'Menyimpan...'
                                  : 'Simpan Batas Anggaran'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Toggle Keamanan PIN / Biometrik (Nonaktif secara default per GEMINI.md 5.5.2)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: FinkuColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: FinkuColors.borderSubtle),
            ),
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: FinkuColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.fingerprint_rounded,
                  color: FinkuColors.tertiary,
                ),
              ),
              title: Text(
                'Kunci PIN / Biometrik FaceID',
                style: FinkuTypography.labelLg(),
              ),
              subtitle: Text(
                _biometricLockEnabled
                    ? 'Keamanan ekstra diaktifkan'
                    : 'Keamanan ekstra dinonaktifkan',
                style: FinkuTypography.bodySm(),
              ),
              value: _biometricLockEnabled,
              activeColor: FinkuColors.primaryBrand,
              onChanged: (val) => setState(() => _biometricLockEnabled = val),
            ),
          ),
          const SizedBox(height: 16),

          // Logout Button (`btn_logout`)
          Semantics(
            identifier: 'btn_logout',
            button: true,
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                key: const Key('btn_logout'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: FinkuColors.errorContainer,
                  foregroundColor: FinkuColors.error,
                ),
                onPressed: () async {
                  await ref.read(authProvider.notifier).signOut();
                  if (!context.mounted) return;
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                icon: const Icon(Icons.logout_rounded, size: 20),
                label: const Text('Keluar (Logout)'),
              ),
            ),
          ),
          ],
        ),
      ),
    );
  }
}
