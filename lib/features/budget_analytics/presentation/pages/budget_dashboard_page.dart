import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/category_taxonomy.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/currency_normalizer.dart';
import '../../../../core/widgets/finku_app_bar.dart';
import '../../../shared_wallet/presentation/providers/wallet_provider.dart';
import '../../../shared_wallet/presentation/widgets/wallet_switcher_bar.dart';
import '../../domain/models/budget_summary.dart';

/// Beranda Grafik Anggaran Bulanan sesuai Stitch `Dashboard Anggaran Bulanan` (`FR-VIS-01..03`).
class BudgetDashboardPage extends ConsumerWidget {
  const BudgetDashboardPage({
    super.key,
    required this.avatarInitials,
    required this.onOpenSettings,
    this.avatarUrl,
  });

  final String avatarInitials;
  final String? avatarUrl;
  final VoidCallback onOpenSettings;

  static const Map<String, String> _monthLabels = {
    '2026-11': 'November 2026',
    '2026-10': 'Oktober 2026',
    '2026-12': 'Desember 2026 (Kosong)',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletState = ref.watch(walletProvider);
    final summary = walletState.summary;

    return Scaffold(
      backgroundColor: FinkuColors.surface,
      appBar: FinkuTopAppBar(
        avatarInitials: avatarInitials,
        avatarUrl: avatarUrl,
        onOpenSettings: onOpenSettings,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          // Pengalih Mode Dompet (`btn_wallet_switcher`)
          const WalletSwitcherBar(),
          const SizedBox(height: 10),

          // Top Controls: Month Selector Pill (`filter_month_selector`)
          Row(
            children: [
              Semantics(
                identifier: 'filter_month_selector',
                button: true,
                child: PopupMenuButton<String>(
                  key: const Key('filter_month_selector'),
                  initialValue: walletState.selectedMonth,
                  onSelected: (period) {
                    ref.read(walletProvider.notifier).selectMonth(period);
                  },
                  itemBuilder: (ctx) => _monthLabels.entries
                      .map(
                        (e) => PopupMenuItem<String>(
                          value: e.key,
                          child: Text(e.value),
                        ),
                      )
                      .toList(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: FinkuColors.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(9999),
                      border: Border.all(color: FinkuColors.borderSubtle),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.calendar_month_rounded,
                          color: FinkuColors.primary,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _monthLabels[walletState.selectedMonth] ??
                              walletState.selectedMonth,
                          style: FinkuTypography.labelLg(),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.expand_more_rounded,
                          color: FinkuColors.tertiary,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: FinkuColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(9999),
                ),
                child: Text(
                  '${summary.transactionCount} transaksi',
                  style: FinkuTypography.labelSm(
                    color: FinkuColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Segmented Wallet Type Toggle (`filter_wallet_type`)
          Semantics(
            identifier: 'filter_wallet_type',
            container: true,
            child: Container(
              key: const Key('filter_wallet_type'),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: FinkuColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _WalletToggleTab(
                      label: 'Dompet Pribadi',
                      icon: Icons.person_rounded,
                      selected: !walletState.isSharedWallet,
                      onTap: () => ref
                          .read(walletProvider.notifier)
                          .switchWalletType(shared: false),
                    ),
                  ),
                  Expanded(
                    child: _WalletToggleTab(
                      label: 'Dompet Bersama',
                      icon: Icons.group_rounded,
                      selected: walletState.isSharedWallet,
                      onTap: () => ref
                          .read(walletProvider.notifier)
                          .switchWalletType(shared: true),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Section 1: Summary Card (`FR-VIS-01`)
          _SummaryCard(summary: summary),
          const SizedBox(height: 14),

          // Section 2: Donut Chart Proporsi Kategori (`FR-VIS-02`, `TC-VIS-01`, `TC-VIS-03`, `TC-VIS-04`)
          _DonutChartCard(summary: summary),
          const SizedBox(height: 14),

          // Section 3: Progress Bar Ambang Batas Anggaran (`FR-VIS-03`, `TC-VIS-02`)
          _BudgetThresholdsCard(
            summary: summary,
            onOpenSettings: onOpenSettings,
          ),
          ],
        ),
      ),
    );
  }
}

class _WalletToggleTab extends StatelessWidget {
  const _WalletToggleTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? FinkuColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? FinkuColors.onPrimary : FinkuColors.tertiary,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: FinkuTypography.labelLg(
                  color: selected ? FinkuColors.onPrimary : FinkuColors.tertiary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});

  final BudgetSummary summary;

  @override
  Widget build(BuildContext context) {
    final usedPct = (summary.overallRatio * 100).clamp(0, 999);
    final leftPct = math.max(0, 100 - usedPct.round());
    final maxWeekly = summary.weeklyTotals.fold<int>(1, math.max);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FinkuColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: FinkuColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TOTAL PENGELUARAN BULAN INI',
                      style: FinkuTypography.labelSm(
                        color: FinkuColors.tertiary,
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      CurrencyNormalizer.formatRupiah(summary.totalSpend),
                      style: FinkuTypography.headlineLg(),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'dari batas anggaran ${CurrencyNormalizer.formatRupiah(summary.totalLimit)}',
                      style: FinkuTypography.bodySm(),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: summary.remainingBudget >= 0
                      ? FinkuColors.primaryFixed.withValues(alpha: 0.45)
                      : FinkuColors.dangerBg,
                  borderRadius: BorderRadius.circular(9999),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      summary.remainingBudget >= 0
                          ? 'Sisa ${CurrencyNormalizer.formatRupiah(summary.remainingBudget)}'
                          : 'Defisit ${CurrencyNormalizer.formatRupiah(summary.remainingBudget)}',
                      style: FinkuTypography.labelSm(
                        color: summary.remainingBudget >= 0
                            ? FinkuColors.onPrimaryFixedVariant
                            : FinkuColors.dangerAlert,
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      '$leftPct% tersisa',
                      style: FinkuTypography.labelSm(
                        color: summary.remainingBudget >= 0
                            ? FinkuColors.primary
                            : FinkuColors.dangerAlert,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(9999),
            child: LinearProgressIndicator(
              value: summary.overallRatio.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: FinkuColors.surfaceContainer,
              color: BudgetSummary.thresholdForRatio(summary.overallRatio) ==
                      BudgetThresholdStatus.overbudget
                  ? FinkuColors.dangerAlert
                  : FinkuColors.primary,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Terpakai: ${usedPct.toStringAsFixed(1)}%',
                style: FinkuTypography.labelSm(),
              ),
              Text(
                'Batas Aman: 75%',
                style: FinkuTypography.labelSm(),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.bar_chart_rounded,
                    size: 16,
                    color: FinkuColors.tertiary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Tren Mingguan',
                    style: FinkuTypography.labelMd(color: FinkuColors.tertiary),
                  ),
                ],
              ),
              Text(
                'Minggu Ini: ${CurrencyNormalizer.formatCompact(summary.weeklyTotals[3])}',
                style: FinkuTypography.labelSm(
                  color: FinkuColors.primary,
                ).copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 112,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            decoration: BoxDecoration(
              color: FinkuColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(14),
            ),
            child: RepaintBoundary(
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxWeekly.toDouble() * 1.25,
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (val, meta) {
                          final idx = val.toInt();
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'M${idx + 1}',
                              style: FinkuTypography.labelSm(
                                color: idx == 3
                                    ? FinkuColors.primary
                                    : FinkuColors.tertiary,
                              ).copyWith(
                                fontWeight: idx == 3
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: List.generate(4, (i) {
                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: math.max(
                            summary.weeklyTotals[i].toDouble(),
                            maxWeekly * 0.08,
                          ),
                          width: 24,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(6),
                          ),
                          color: i == 3
                              ? FinkuColors.primary
                              : FinkuColors.primary.withValues(
                                  alpha: 0.3 + i * 0.15,
                                ),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DonutChartCard extends StatelessWidget {
  const _DonutChartCard({required this.summary});

  final BudgetSummary summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FinkuColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
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
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: FinkuColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('Proporsi Kategori', style: FinkuTypography.titleMd()),
                ],
              ),
              Text(
                '${summary.categoryShares.length} Kategori Aktif',
                style: FinkuTypography.labelSm(),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (summary.isEmpty)
            Semantics(
              identifier: 'chart_monthly_donut',
              container: true,
              child: Container(
                key: const Key('chart_monthly_donut'),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
                decoration: BoxDecoration(
                  color: FinkuColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.pie_chart_outline_rounded,
                      size: 42,
                      color: FinkuColors.neutralSlate,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Belum ada transaksi',
                      style: FinkuTypography.titleMd(),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Catat lewat Scan Struk atau FinGPT untuk melihat grafik pengeluaran bulan ini.',
                      textAlign: TextAlign.center,
                      style: FinkuTypography.bodySm(),
                    ),
                  ],
                ),
              ),
            )
          else
            Row(
              children: [
                // Donut Chart dengan RepaintBoundary untuk 60 FPS & sudut minimum (TC-VIS-03)
                Semantics(
                  identifier: 'chart_monthly_donut',
                  container: true,
                  child: RepaintBoundary(
                    key: const Key('chart_monthly_donut'),
                    child: SizedBox(
                      width: 146,
                      height: 146,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          PieChart(
                            PieChartData(
                              sectionsSpace: 2,
                              centerSpaceRadius: 42,
                              startDegreeOffset: -90,
                              sections: summary.categoryShares.map((share) {
                                return PieChartSectionData(
                                  value: share.visualPercentage,
                                  color: share.color,
                                  radius: 22,
                                  showTitle: false,
                                );
                              }).toList(),
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'TOTAL',
                                style: FinkuTypography.labelSm().copyWith(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                CurrencyNormalizer.formatCompact(
                                  summary.totalSpend,
                                ),
                                style: FinkuTypography.headlineSm(),
                              ),
                              Text(
                                'IDR',
                                style: FinkuTypography.labelSm(
                                  color: FinkuColors.primary,
                                ).copyWith(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    children: summary.categoryShares.map((share) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: share.color,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                share.category,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: FinkuTypography.labelSm(
                                  color: FinkuColors.onSurface,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${share.truePercentage.toStringAsFixed(0)}%',
                              style: FinkuTypography.labelMd(
                                color: FinkuColors.onSurface,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _BudgetThresholdsCard extends StatelessWidget {
  const _BudgetThresholdsCard({
    required this.summary,
    required this.onOpenSettings,
  });

  final BudgetSummary summary;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'progress_budget_bar',
      container: true,
      child: Container(
        key: const Key('progress_budget_bar'),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: FinkuColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(24),
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
                    const Icon(
                      Icons.data_thresholding_outlined,
                      color: FinkuColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Batas Anggaran Kategori',
                      style: FinkuTypography.titleMd(),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: onOpenSettings,
                  style: TextButton.styleFrom(
                    backgroundColor: FinkuColors.surfaceContainer,
                    foregroundColor: FinkuColors.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                  ),
                  icon: const Icon(Icons.edit_rounded, size: 14),
                  label: Text(
                    'Atur Batas',
                    style: FinkuTypography.labelMd(color: FinkuColors.primary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...summary.budgetProgresses.map((item) {
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: item.status == BudgetThresholdStatus.overbudget
                      ? FinkuColors.dangerBg.withValues(alpha: 0.45)
                      : FinkuColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: CategoryTaxonomy.colorFor(
                              item.category,
                            ).withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            CategoryTaxonomy.iconFor(item.category),
                            size: 18,
                            color: CategoryTaxonomy.colorFor(item.category),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.category,
                                style: FinkuTypography.labelLg(),
                              ),
                              Text(
                                '${CurrencyNormalizer.formatRupiah(item.spentAmount)} / ${CurrencyNormalizer.formatRupiah(item.limitAmount)}',
                                style: FinkuTypography.bodySm(),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: item.badgeBgColor,
                            borderRadius: BorderRadius.circular(9999),
                          ),
                          child: Text(
                            item.overbudgetDelta > 0
                                ? 'Overbudget +${CurrencyNormalizer.formatRupiah(item.overbudgetDelta)}'
                                : item.statusLabel,
                            style: FinkuTypography.labelSm(
                              color: item.statusColor,
                            ).copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(9999),
                      child: LinearProgressIndicator(
                        value: item.ratio.clamp(0.0, 1.0),
                        minHeight: 6,
                        backgroundColor: FinkuColors.progressTrack,
                        color: item.statusColor,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
