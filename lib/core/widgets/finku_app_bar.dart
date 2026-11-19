import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Header aplikasi Finku sesuai Stitch (`Finku ID • Budget & Money`, tombol Settings, Avatar).
class FinkuTopAppBar extends StatelessWidget implements PreferredSizeWidget {
  const FinkuTopAppBar({
    super.key,
    required this.avatarInitials,
    required this.onOpenSettings,
    this.avatarUrl,
    this.title,
    this.showBackButton = false,
    this.onBack,
  });

  final String avatarInitials;
  final String? avatarUrl;
  final VoidCallback onOpenSettings;
  final String? title;
  final bool showBackButton;
  final VoidCallback? onBack;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: FinkuColors.surface.withValues(alpha: 0.94),
        boxShadow: [
          BoxShadow(
            color: FinkuColors.onSurface.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 64,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    if (showBackButton)
                      IconButton(
                        onPressed: onBack ?? () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.arrow_back_rounded),
                        color: FinkuColors.onSurface,
                      ),
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            FinkuColors.primaryBrand,
                            FinkuColors.primary,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    if (title != null)
                      Text(
                        title!,
                        style: FinkuTypography.headlineSm(),
                      )
                    else
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Finku',
                                style: FinkuTypography.headlineSm(),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: FinkuColors.primaryFixed.withValues(alpha: 0.45),
                                  borderRadius: BorderRadius.circular(9999),
                                ),
                                child: Text(
                                  'ID',
                                  style: FinkuTypography.labelSm(
                                    color: FinkuColors.primary,
                                  ).copyWith(fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            'Budget & Money',
                            style: FinkuTypography.labelSm(
                              color: FinkuColors.tertiary,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                Row(
                  children: [
                    Semantics(
                      identifier: 'btn_open_settings',
                      button: true,
                      label: 'Pengaturan',
                      child: IconButton(
                        key: const Key('btn_open_settings'),
                        tooltip: 'Pengaturan',
                        onPressed: onOpenSettings,
                        icon: const Icon(
                          Icons.settings_outlined,
                          color: FinkuColors.onSurfaceVariant,
                          size: 22,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: FinkuColors.primaryBrand,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: FinkuColors.primary.withValues(alpha: 0.2),
                              width: 2,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: (avatarUrl != null && avatarUrl!.isNotEmpty)
                              ? ClipOval(
                                  child: Image.network(
                                    avatarUrl!,
                                    width: 34,
                                    height: 34,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Text(
                                      avatarInitials,
                                      style: FinkuTypography.labelMd(
                                        color: FinkuColors.onPrimary,
                                      ),
                                    ),
                                  ),
                                )
                              : Text(
                                  avatarInitials,
                                  style: FinkuTypography.labelMd(
                                    color: FinkuColors.onPrimary,
                                  ),
                                ),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: FinkuColors.primaryBrand,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: FinkuColors.surface,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
