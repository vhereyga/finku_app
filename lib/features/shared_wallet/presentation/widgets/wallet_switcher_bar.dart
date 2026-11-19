import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/models/wallet_models.dart';
import '../providers/wallet_provider.dart';

/// Pengalih Mode Dompet (Mode Biasa / Dompet Pribadi <-> Mode Bersama / Shared Wallet).
class WalletSwitcherBar extends ConsumerWidget {
  const WalletSwitcherBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletState = ref.watch(walletProvider);
    final isShared = walletState.isSharedWallet;
    final role = walletState.activeRole;

    return Semantics(
      identifier: 'btn_wallet_switcher',
      button: true,
      child: Material(
        key: const Key('btn_wallet_switcher'),
        color: FinkuColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => showWalletSwitcherSheet(context, ref),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: FinkuColors.borderSubtle),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: isShared
                        ? FinkuColors.secondaryFixed
                        : FinkuColors.primaryFixed.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isShared ? Icons.group_rounded : Icons.person_rounded,
                    size: 18,
                    color: isShared
                        ? FinkuColors.secondaryBrand
                        : FinkuColors.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            isShared ? 'Mode Bersama' : 'Mode Biasa',
                            style: FinkuTypography.labelSm(
                              color: isShared
                                  ? FinkuColors.secondaryBrand
                                  : FinkuColors.primary,
                            ).copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: walletState.isOfflineMode
                                  ? FinkuColors.warning
                                  : FinkuColors.primaryBrand,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            walletState.isOfflineMode ? 'Offline' : 'Realtime',
                            style: FinkuTypography.labelSm(
                              color: walletState.isOfflineMode
                                  ? FinkuColors.warning
                                  : FinkuColors.tertiary,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        walletState.walletTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: FinkuTypography.labelLg(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _RoleBadge(role: role),
                const SizedBox(width: 4),
                const Icon(
                  Icons.unfold_more_rounded,
                  size: 18,
                  color: FinkuColors.tertiary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    final isOwner = role == 'owner';
    final isEditor = role == 'editor';
    final label = isOwner ? 'Owner' : (isEditor ? 'Editor' : 'Viewer');
    final bg = isOwner
        ? FinkuColors.primaryFixed.withValues(alpha: 0.45)
        : (isEditor ? FinkuColors.roleTagBg : FinkuColors.surfaceContainerHigh);
    final fg = isOwner
        ? FinkuColors.onPrimaryFixedVariant
        : (isEditor ? FinkuColors.secondaryBrand : FinkuColors.tertiary);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(9999),
      ),
      child: Text(
        label,
        style: FinkuTypography.labelSm(color: fg).copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

Future<void> showWalletSwitcherSheet(
  BuildContext context,
  WidgetRef ref,
) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: FinkuColors.surfaceContainerLowest,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      return Consumer(
        builder: (ctx, sheetRef, _) {
          final walletState = sheetRef.watch(walletProvider);
          final personal = walletState.personalWallets;
          final shared = walletState.sharedWallets;

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
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
                  Text('Pilih Mode & Dompet', style: FinkuTypography.titleMd()),
                  Text(
                    'Bebas beralih antara Dompet Pribadi (Mode Biasa) dan Dompet Bersama.',
                    style: FinkuTypography.bodySm(),
                  ),
                  const SizedBox(height: 14),

                  Text(
                    'MODE BIASA (DOMPET PRIBADI)',
                    style: FinkuTypography.labelSm(
                      color: FinkuColors.primary,
                    ).copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  if (personal.isEmpty)
                    _WalletListTile(
                      wallet: WalletInfo(
                        id: walletState.activeWalletId,
                        name: 'Dompet Pribadi',
                        isShared: false,
                        role: 'owner',
                      ),
                      isSelected: !walletState.isSharedWallet,
                      isOffline: walletState.isOfflineMode,
                      onTap: () {
                        Navigator.pop(ctx);
                        sheetRef
                            .read(walletProvider.notifier)
                            .switchWalletType(shared: false);
                      },
                    )
                  else
                    ...personal.map(
                      (w) => _WalletListTile(
                        wallet: w,
                        isSelected: w.id == walletState.activeWalletId,
                        isOffline: walletState.isOfflineMode,
                        onTap: () {
                          Navigator.pop(ctx);
                          sheetRef
                              .read(walletProvider.notifier)
                              .selectWallet(w.id);
                        },
                      ),
                    ),
                  const SizedBox(height: 12),

                  Text(
                    'MODE BERSAMA (SHARED WALLET)',
                    style: FinkuTypography.labelSm(
                      color: FinkuColors.secondaryBrand,
                    ).copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  if (shared.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: FinkuColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Belum ada Dompet Bersama. Buat baru atau gabung lewat kode undangan.',
                        style: FinkuTypography.bodySm(),
                      ),
                    )
                  else
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 210),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: shared.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 6),
                        itemBuilder: (_, idx) {
                          final w = shared[idx];
                          return _WalletListTile(
                            wallet: w,
                            isSelected: w.id == walletState.activeWalletId,
                            isOffline: walletState.isOfflineMode,
                            onTap: () {
                              Navigator.pop(ctx);
                              sheetRef
                                  .read(walletProvider.notifier)
                                  .selectWallet(w.id);
                            },
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (context.mounted) {
                                _showJoinWalletDialog(context, ref);
                              }
                            });
                          },
                          icon: const Icon(Icons.vpn_key_rounded, size: 17),
                          label: const Text('Gabung Kode'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (context.mounted) {
                                _showCreateSharedWalletDialog(context, ref);
                              }
                            });
                          },
                          icon: const Icon(Icons.group_add_rounded, size: 17),
                          label: const Text('Buat Bersama'),
                        ),
                      ),
                    ],
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

class _WalletListTile extends StatelessWidget {
  const _WalletListTile({
    required this.wallet,
    required this.isSelected,
    required this.isOffline,
    required this.onTap,
  });

  final WalletInfo wallet;
  final bool isSelected;
  final bool isOffline;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected
          ? FinkuColors.surfaceContainerLow
          : FinkuColors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? FinkuColors.primaryBrand
                  : FinkuColors.borderSubtle,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                wallet.isShared ? Icons.group_rounded : Icons.person_rounded,
                size: 20,
                color: wallet.isShared
                    ? FinkuColors.secondaryBrand
                    : FinkuColors.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      wallet.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: FinkuTypography.labelLg(),
                    ),
                    Text(
                      wallet.isShared
                          ? (isOffline
                                ? 'Sinkronisasi tertunda (Offline)'
                                : 'Sinkronisasi Realtime${wallet.inviteCode != null ? ' • ${wallet.inviteCode}' : ''}')
                          : 'Keuangan pribadi penuh (Mode Biasa)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: FinkuTypography.labelSm(),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _RoleBadge(role: wallet.role),
              if (isSelected) ...[
                const SizedBox(width: 6),
                const Icon(
                  Icons.check_circle_rounded,
                  size: 18,
                  color: FinkuColors.primaryBrand,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _showCreateSharedWalletDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final name = await showDialog<String>(
    context: context,
    builder: (_) => const _SingleInputDialog(
      title: 'Buat Dompet Bersama',
      labelText: 'Nama Dompet Bersama',
      hintText: 'Mis. Keuangan Keluarga / Kos',
      confirmLabel: 'Buat',
    ),
  );
  if (name == null || name.isEmpty) return;

  try {
    final created = await ref
        .read(walletProvider.notifier)
        .createSharedWallet(name);
    messenger?.showSnackBar(
      SnackBar(
        content: Text(
          'Dompet "${created.name}" dibuat! Kode undangan: ${created.inviteCode ?? '-'}',
        ),
        backgroundColor: FinkuColors.primary,
      ),
    );
  } catch (e) {
    messenger?.showSnackBar(
      SnackBar(
        content: Text(e.toString()),
        backgroundColor: FinkuColors.dangerAlert,
      ),
    );
  }
}

Future<void> _showJoinWalletDialog(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final code = await showDialog<String>(
    context: context,
    builder: (_) => const _SingleInputDialog(
      title: 'Gabung Dompet Bersama',
      labelText: 'Kode Undangan',
      hintText: 'Mis. KOS-2026-FNK',
      confirmLabel: 'Gabung',
      uppercase: true,
    ),
  );
  if (code == null || code.isEmpty) return;

  try {
    await ref.read(walletProvider.notifier).joinSharedWallet(code);
    messenger?.showSnackBar(
      const SnackBar(
        content: Text('Berhasil bergabung ke Dompet Bersama!'),
        backgroundColor: FinkuColors.primary,
      ),
    );
  } catch (e) {
    messenger?.showSnackBar(
      SnackBar(
        content: Text(e.toString()),
        backgroundColor: FinkuColors.dangerAlert,
      ),
    );
  }
}

class _SingleInputDialog extends StatefulWidget {
  const _SingleInputDialog({
    required this.title,
    required this.labelText,
    required this.hintText,
    required this.confirmLabel,
    this.uppercase = false,
  });

  final String title;
  final String labelText;
  final String hintText;
  final String confirmLabel;
  final bool uppercase;

  @override
  State<_SingleInputDialog> createState() => _SingleInputDialogState();
}

class _SingleInputDialogState extends State<_SingleInputDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        textCapitalization: widget.uppercase
            ? TextCapitalization.characters
            : TextCapitalization.words,
        decoration: InputDecoration(
          labelText: widget.labelText,
          hintText: widget.hintText,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: () {
            final value = _ctrl.text.trim();
            if (value.isEmpty) return;
            Navigator.pop(context, value);
          },
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
