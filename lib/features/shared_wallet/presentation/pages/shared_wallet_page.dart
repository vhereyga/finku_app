import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/category_taxonomy.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_normalizer.dart';
import '../../../../core/widgets/finku_app_bar.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/models/wallet_models.dart';
import '../providers/wallet_provider.dart';
import '../widgets/wallet_switcher_bar.dart';

/// Halaman Mode Dompet Bersama & RBAC sesuai Stitch `Mode Dompet Bersama & RBAC` (`FR-SYNC-01..04`).
class SharedWalletPage extends ConsumerStatefulWidget {
  const SharedWalletPage({
    super.key,
    required this.avatarInitials,
    required this.onOpenSettings,
    this.avatarUrl,
  });

  final String avatarInitials;
  final String? avatarUrl;
  final VoidCallback onOpenSettings;

  @override
  ConsumerState<SharedWalletPage> createState() => _SharedWalletPageState();
}

class _SharedWalletPageState extends ConsumerState<SharedWalletPage> {
  void _showInviteBottomSheet(BuildContext context, String inviteCode) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: FinkuColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: FinkuColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(9999),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Undang ke Dompet Bersama',
                          style: FinkuTypography.titleMd(),
                        ),
                        Text(
                          'Bagikan kode atau link ke anggota keluarga/kos',
                          style: FinkuTypography.bodySm(),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: FinkuColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.qr_code_2_rounded,
                        size: 110,
                        color: FinkuColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Kode Dompet: $inviteCode',
                      style: FinkuTypography.labelLg(),
                    ),
                    Text(
                      'Role anggota dapat diatur Owner lewat Kelola Anggota',
                      textAlign: TextAlign.center,
                      style: FinkuTypography.labelSm(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: inviteCode));
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Kode undangan $inviteCode disalin'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.share_rounded, size: 18),
                  label: const Text('Salin Kode Undangan'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showManageMembersSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: FinkuColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return Consumer(
          builder: (ctx, sheetRef, _) {
            final walletState = sheetRef.watch(walletProvider);
            final currentUserId = sheetRef.watch(authProvider).user?.id;
            final members = walletState.members;

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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Kelola Anggota Dompet',
                                style: FinkuTypography.titleMd(),
                              ),
                              Text(
                                'Atur izin Editor (tulis) atau Viewer (lihat saja)',
                                style: FinkuTypography.bodySm(),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 340),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: members.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, idx) {
                          final m = members[idx];
                          final isSelfOrOwner =
                              m.userId == currentUserId || m.role == 'owner';

                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: FinkuColors.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: FinkuColors.borderSubtle,
                              ),
                            ),
                            child: Row(
                              children: [
                                _MemberAvatar(member: m, radius: 18),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        m.fullName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: FinkuTypography.labelLg(),
                                      ),
                                      if (m.email.isNotEmpty)
                                        Text(
                                          m.email,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: FinkuTypography.labelSm(),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (isSelfOrOwner)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: FinkuColors.primaryFixed.withValues(
                                        alpha: 0.45,
                                      ),
                                      borderRadius: BorderRadius.circular(9999),
                                    ),
                                    child: Text(
                                      'Owner',
                                      style: FinkuTypography.labelSm(
                                        color: FinkuColors.onPrimaryFixedVariant,
                                      ).copyWith(fontWeight: FontWeight.w700),
                                    ),
                                  )
                                else ...[
                                  Semantics(
                                    identifier: 'dropdown_member_role',
                                    container: true,
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        key: ValueKey(
                                          'dropdown_member_role_${m.userId}',
                                        ),
                                        value: m.role == 'viewer'
                                            ? 'viewer'
                                            : 'editor',
                                        borderRadius: BorderRadius.circular(12),
                                        items: const [
                                          DropdownMenuItem(
                                            value: 'editor',
                                            child: Text('Editor'),
                                          ),
                                          DropdownMenuItem(
                                            value: 'viewer',
                                            child: Text('Viewer'),
                                          ),
                                        ],
                                        onChanged: (newRole) async {
                                          if (newRole == null ||
                                              newRole == m.role) {
                                            return;
                                          }
                                          try {
                                            await sheetRef
                                                .read(walletProvider.notifier)
                                                .updateMemberRole(
                                                  targetUserId: m.userId,
                                                  newRole: newRole,
                                                );
                                            if (!context.mounted) return;
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Peran ${m.fullName} diubah menjadi ${newRole == 'editor' ? 'Editor' : 'Viewer'}',
                                                ),
                                                backgroundColor:
                                                    FinkuColors.primary,
                                              ),
                                            );
                                          } catch (e) {
                                            if (!context.mounted) return;
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(e.toString()),
                                                backgroundColor:
                                                    FinkuColors.dangerAlert,
                                              ),
                                            );
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Keluarkan anggota',
                                    icon: const Icon(
                                      Icons.person_remove_outlined,
                                      size: 18,
                                      color: FinkuColors.error,
                                    ),
                                    onPressed: () async {
                                      try {
                                        await sheetRef
                                            .read(walletProvider.notifier)
                                            .removeMember(m.userId);
                                      } catch (e) {
                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(e.toString()),
                                            backgroundColor:
                                                FinkuColors.dangerAlert,
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showTransactionDialog({TransactionItem? existing}) async {
    final result = await showDialog<({String name, int amount, String category})>(
      context: context,
      builder: (_) => _TransactionFormDialog(existing: existing),
    );
    if (result == null) return;

    try {
      final notifier = ref.read(walletProvider.notifier);
      if (existing == null) {
        await notifier.addTransaction(
          merchantName: result.name,
          category: result.category,
          amount: result.amount,
          source: 'manual',
        );
      } else {
        await notifier.updateTransaction(
          tx: existing,
          merchantName: result.name,
          category: result.category,
          amount: result.amount,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: FinkuColors.dangerAlert,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final walletState = ref.watch(walletProvider);
    final summary = walletState.summary;
    final canEdit = walletState.canEdit;
    final isOwner = walletState.isOwner;
    final inviteCode = walletState.activeInviteCode ?? 'KOS-2026-FNK';

    return Scaffold(
      backgroundColor: FinkuColors.surface,
      appBar: FinkuTopAppBar(
        avatarInitials: widget.avatarInitials,
        avatarUrl: widget.avatarUrl,
        onOpenSettings: widget.onOpenSettings,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          // Pengalih Mode & Daftar Dompet (`btn_wallet_switcher`)
          const WalletSwitcherBar(),
          const SizedBox(height: 10),

          // Top Live Sync Status Bar (`badge_sync_status`, TC-SYNC-01 & TC-SYNC-03)
          Semantics(
            identifier: 'badge_sync_status',
            button: true,
            child: InkWell(
              key: const Key('badge_sync_status'),
              borderRadius: BorderRadius.circular(14),
              onTap: () => ref.read(walletProvider.notifier).toggleOfflineMode(),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: walletState.isOfflineMode
                      ? FinkuColors.warningBg
                      : FinkuColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: FinkuColors.borderSubtle),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            color: walletState.isOfflineMode
                                ? FinkuColors.warning
                                : FinkuColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          walletState.isOfflineMode
                              ? 'Mode Offline (Simulasi)'
                              : 'Tersinkronisasi (Live)',
                          style: FinkuTypography.labelSm(
                            color: walletState.isOfflineMode
                                ? FinkuColors.warning
                                : FinkuColors.primary,
                          ).copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Icon(
                          walletState.isOfflineMode
                              ? Icons.cloud_off_rounded
                              : Icons.cloud_done_rounded,
                          size: 15,
                          color: walletState.isOfflineMode
                              ? FinkuColors.warning
                              : FinkuColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Offline queue: ${walletState.pendingSyncCount} tertunda',
                          style: FinkuTypography.labelSm(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Main Shared Wallet Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: FinkuColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: FinkuColors.borderSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: FinkuColors.surfaceContainer,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        walletState.isSharedWallet
                            ? Icons.cottage_rounded
                            : Icons.account_balance_wallet_rounded,
                        color: FinkuColors.primary,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            walletState.isSharedWallet
                                ? 'DOMPET KOLABORASI'
                                : 'DOMPET PRIBADI (MODE BIASA)',
                            style: FinkuTypography.labelSm(),
                          ),
                          Text(
                            walletState.walletTitle,
                            style: FinkuTypography.titleMd(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  walletState.isSharedWallet
                      ? 'Saldo Dompet Bersama'
                      : 'Saldo Dompet Pribadi',
                  style: FinkuTypography.labelMd(color: FinkuColors.tertiary),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text('Rp ', style: FinkuTypography.currencyPrefix()),
                    Text(
                      CurrencyNormalizer.formatRupiah(
                        walletState.sharedWalletBalance,
                        withPrefix: false,
                      ),
                      style: FinkuTypography.displayCurrency(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Pengeluaran Bulan Ini',
                      style: FinkuTypography.labelSm(),
                    ),
                    Text(
                      '${CurrencyNormalizer.formatRupiah(summary.totalSpend)} / ${CurrencyNormalizer.formatRupiah(summary.totalLimit)}',
                      style: FinkuTypography.labelSm(
                        color: FinkuColors.onSurface,
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(9999),
                  child: LinearProgressIndicator(
                    value: summary.overallRatio.clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: FinkuColors.surfaceContainerHigh,
                    color: FinkuColors.primary,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: canEdit ? () => _showTransactionDialog() : null,
                        icon: const Icon(Icons.add_circle_rounded, size: 18),
                        label: const Text('Top Up / Catat'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () =>
                            _showInviteBottomSheet(context, inviteCode),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: FinkuColors.secondaryContainer,
                        ),
                        icon: const Icon(Icons.person_add_rounded, size: 18),
                        label: const Text('Undang Anggota'),
                      ),
                    ),
                  ],
                ),
                if (isOwner) ...[
                  const SizedBox(height: 10),
                  Semantics(
                    identifier: 'btn_manage_members',
                    button: true,
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        key: const Key('btn_manage_members'),
                        onPressed: () => _showManageMembersSheet(context),
                        icon: const Icon(
                          Icons.manage_accounts_rounded,
                          size: 18,
                        ),
                        label: const Text('Kelola Anggota & Izin'),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // RBAC Members Section & Active Role Badge (`badge_member_role`)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Anggota & Hak Akses (${walletState.members.length} Orang)',
                style: FinkuTypography.labelLg(),
              ),
              Semantics(
                identifier: 'badge_member_role',
                container: true,
                child: Container(
                  key: const Key('badge_member_role'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: canEdit
                        ? FinkuColors.roleTagBg
                        : FinkuColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(9999),
                  ),
                  child: Text(
                    walletState.activeRole == 'owner'
                        ? 'Owner'
                        : walletState.activeRole == 'editor'
                        ? 'Editor'
                        : 'Viewer',
                    style: FinkuTypography.labelSm(
                      color: canEdit
                          ? FinkuColors.secondaryBrand
                          : FinkuColors.tertiary,
                    ).copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 112,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: walletState.members.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (ctx, idx) {
                final m = walletState.members[idx];
                return Container(
                  width: 224,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: FinkuColors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: FinkuColors.borderSubtle),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _MemberAvatar(member: m, radius: 18),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: m.role == 'owner'
                                  ? FinkuColors.primaryFixed.withValues(
                                      alpha: 0.4,
                                    )
                                  : (m.role == 'editor'
                                        ? FinkuColors.secondaryFixed
                                        : FinkuColors.surfaceContainerHigh),
                              borderRadius: BorderRadius.circular(9999),
                            ),
                            child: Text(
                              m.roleLabel,
                              style: FinkuTypography.labelSm(
                                color: m.role == 'owner'
                                    ? FinkuColors.onPrimaryFixedVariant
                                    : (m.role == 'editor'
                                          ? FinkuColors.onSecondaryFixedVariant
                                          : FinkuColors.tertiary),
                              ).copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            m.fullName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: FinkuTypography.labelLg(),
                          ),
                          Text(
                            m.role == 'owner'
                                ? 'Akses penuh kelola & undang'
                                : (m.role == 'editor'
                                      ? 'Dapat tambah & edit transaksi'
                                      : 'Read-only (Hanya pantau saldo)'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: FinkuTypography.labelSm(),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // Feed Aktivitas Transaksi Real-Time (`btn_edit_tx`, `btn_delete_tx`)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Aktivitas Transaksi Real-time',
                style: FinkuTypography.labelLg(),
              ),
              Text(
                'Latensi: ${walletState.lastSyncLatencyMs} ms',
                style: FinkuTypography.labelSm(color: FinkuColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (walletState.transactions.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: FinkuColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: FinkuColors.borderSubtle),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.receipt_long_outlined,
                    size: 36,
                    color: FinkuColors.neutralSlate,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Belum ada transaksi di dompet ini',
                    style: FinkuTypography.titleMd(),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    canEdit
                        ? 'Tekan "Top Up / Catat" atau gunakan Scan Struk / FinGPT untuk mulai mencatat.'
                        : 'Transaksi yang dicatat Owner atau Editor akan muncul otomatis secara real-time di sini.',
                    textAlign: TextAlign.center,
                    style: FinkuTypography.bodySm(),
                  ),
                ],
              ),
            )
          else
            ...walletState.transactions.map((tx) {
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: FinkuColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: FinkuColors.borderSubtle),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: CategoryTaxonomy.colorFor(
                          tx.category,
                        ).withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        CategoryTaxonomy.iconFor(tx.category),
                        color: CategoryTaxonomy.colorFor(tx.category),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tx.merchantName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: FinkuTypography.titleMd(),
                          ),
                          Text(
                            '${tx.category} • ${tx.isPendingSync ? "Menunggu Sync" : tx.source.toUpperCase()}',
                            style: FinkuTypography.bodySm(),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Dicatat oleh ${tx.authorName} (${tx.authorRole == 'owner' ? 'Owner' : 'Editor'})',
                            style: FinkuTypography.labelSm(
                              color: tx.authorRole == 'owner'
                                  ? FinkuColors.primary
                                  : FinkuColors.secondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '- ${CurrencyNormalizer.formatRupiah(tx.amount)}',
                          style: FinkuTypography.labelLg(
                            color: FinkuColors.error,
                          ),
                        ),
                        if (canEdit) ...[
                          const SizedBox(height: 6),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Semantics(
                                identifier: 'btn_edit_tx',
                                button: true,
                                child: InkWell(
                                  key: ValueKey('btn_edit_tx_${tx.clientTxId}'),
                                  onTap: () =>
                                      _showTransactionDialog(existing: tx),
                                  child: Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: FinkuColors.surfaceContainerLow,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.edit_rounded,
                                      size: 16,
                                      color: FinkuColors.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Semantics(
                                identifier: 'btn_delete_tx',
                                button: true,
                                child: InkWell(
                                  key: ValueKey(
                                    'btn_delete_tx_${tx.clientTxId}',
                                  ),
                                  onTap: () => ref
                                      .read(walletProvider.notifier)
                                      .deleteTransaction(tx),
                                  child: Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: FinkuColors.dangerBg,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.delete_outline_rounded,
                                      size: 16,
                                      color: FinkuColors.error,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              );
            }),

          // RBAC Security & Role Transparency Card
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: FinkuColors.surfaceContainer,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: FinkuColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Catatan Hak Akses Kolaborasi (RBAC)',
                        style: FinkuTypography.labelMd(
                          color: FinkuColors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        canEdit
                            ? 'Sebagai ${walletState.activeRole.toUpperCase()} di dompet ini, Anda dapat menambah, mengedit, dan menghapus transaksi.'
                            : 'Peran Anda di dompet bersama ini adalah Viewer (Read-only). Akses edit/hapus dinonaktifkan di UI dan ditolak oleh Supabase RLS. Anda tetap berkuasa penuh di Dompet Pribadi.',
                        style: FinkuTypography.bodySm(
                          color: FinkuColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          ],
        ),
      ),
    );
  }
}

class _MemberAvatar extends StatelessWidget {
  const _MemberAvatar({required this.member, required this.radius});

  final WalletMemberInfo member;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final bgColor = member.role == 'owner'
        ? FinkuColors.primaryBrand
        : (member.role == 'editor'
              ? FinkuColors.secondaryContainer
              : FinkuColors.tertiary);
    final url = member.avatarUrl;
    if (url != null && url.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: bgColor,
        backgroundImage: NetworkImage(url),
        onBackgroundImageError: (_, __) {},
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: bgColor,
      child: Text(
        member.avatarInitials,
        style: FinkuTypography.labelMd(color: Colors.white),
      ),
    );
  }
}

class _TransactionFormDialog extends StatefulWidget {
  const _TransactionFormDialog({this.existing});

  final TransactionItem? existing;

  @override
  State<_TransactionFormDialog> createState() => _TransactionFormDialogState();
}

class _TransactionFormDialogState extends State<_TransactionFormDialog> {
  late final TextEditingController _merchantCtrl;
  late final TextEditingController _amountCtrl;
  late String _selectedCategory;

  @override
  void initState() {
    super.initState();
    _merchantCtrl = TextEditingController(
      text: widget.existing?.merchantName ?? '',
    );
    _amountCtrl = TextEditingController(
      text: widget.existing != null ? widget.existing!.amount.toString() : '25000',
    );
    _selectedCategory =
        widget.existing?.category ?? CategoryTaxonomy.belanjaHarian;
  }

  @override
  void dispose() {
    _merchantCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.existing == null ? 'Catat Transaksi Bersama' : 'Edit Transaksi',
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _merchantCtrl,
            decoration: const InputDecoration(
              labelText: 'Keterangan / Merchant',
              hintText: 'Mis. Galon Kos Offline',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Nominal (Rp)',
              prefixText: 'Rp ',
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _selectedCategory,
            isExpanded: true,
            items: CategoryTaxonomy.validCategories
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => _selectedCategory = v);
            },
            decoration: const InputDecoration(labelText: 'Kategori'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: () {
            final name = _merchantCtrl.text.trim();
            final amt = CurrencyNormalizer.parseRupiah(_amountCtrl.text);
            if (name.isEmpty || amt <= 0) return;
            Navigator.pop(
              context,
              (name: name, amount: amt, category: _selectedCategory),
            );
          },
          child: const Text('Simpan Catatan'),
        ),
      ],
    );
  }
}
