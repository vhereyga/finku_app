import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:finku_app/core/constants/category_taxonomy.dart';
import 'package:finku_app/core/theme/app_theme.dart';
import 'package:finku_app/features/shared_wallet/domain/models/wallet_models.dart';

/// Status ambang batas anggaran sesuai Bab 5.4.2 GEMINI.md (`TC-VIS-02`).
enum BudgetThresholdStatus {
  safe, // < 75% -> #16A34A (Hijau)
  warning, // 75%..90% -> #D97706 (Kuning/Amber)
  overbudget, // > 90% -> #DC2626 (Merah/Alert)
}

class CategoryShare {
  const CategoryShare({
    required this.category,
    required this.totalAmount,
    required this.truePercentage,
    required this.visualPercentage,
    required this.color,
  });

  final String category;
  final int totalAmount;
  final double truePercentage;
  final double visualPercentage;
  final Color color;
}

class CategoryBudgetProgress {
  const CategoryBudgetProgress({
    required this.category,
    required this.spentAmount,
    required this.limitAmount,
    required this.ratio,
    required this.status,
  });

  final String category;
  final int spentAmount;
  final int limitAmount;
  final double ratio;
  final BudgetThresholdStatus status;

  double get percentage => ratio * 100;
  int get overbudgetDelta => math.max(0, spentAmount - limitAmount);

  Color get statusColor {
    switch (status) {
      case BudgetThresholdStatus.safe:
        return FinkuColors.primaryBrand; // #16A34A
      case BudgetThresholdStatus.warning:
        return FinkuColors.warning; // #D97706
      case BudgetThresholdStatus.overbudget:
        return FinkuColors.dangerAlert; // #DC2626
    }
  }

  Color get badgeBgColor {
    switch (status) {
      case BudgetThresholdStatus.safe:
        return FinkuColors.safeBg; // #DCFCE7
      case BudgetThresholdStatus.warning:
        return FinkuColors.warningBg; // #FEF3C7
      case BudgetThresholdStatus.overbudget:
        return FinkuColors.dangerBg; // #FEE2E2
    }
  }

  String get statusLabel {
    final pct = percentage.round();
    switch (status) {
      case BudgetThresholdStatus.safe:
        return 'Aman ($pct%)';
      case BudgetThresholdStatus.warning:
        return 'Waspada ($pct%)';
      case BudgetThresholdStatus.overbudget:
        return overbudgetDelta > 0 ? 'Overbudget' : 'Kritis ($pct%)';
    }
  }
}

/// Hasil agregasi grafik & anggaran bulanan (`FR-VIS-01` s/d `FR-VIS-03`).
class BudgetSummary {
  const BudgetSummary({
    required this.monthPeriod,
    required this.totalSpend,
    required this.totalLimit,
    required this.remainingBudget,
    required this.overallRatio,
    required this.categoryShares,
    required this.budgetProgresses,
    required this.weeklyTotals,
    required this.transactionCount,
  });

  final String monthPeriod;
  final int totalSpend;
  final int totalLimit;
  final int remainingBudget;
  final double overallRatio;
  final List<CategoryShare> categoryShares;
  final List<CategoryBudgetProgress> budgetProgresses;
  final List<int> weeklyTotals; // 4 minggu (M1..M4)
  final int transactionCount;

  bool get isEmpty => transactionCount == 0 || totalSpend == 0;

  /// Menghitung status ambang batas anggaran sesuai `GEMINI.md` 5.4.2:
  /// `< 75%` Hijau, `75% - 90%` Kuning, `> 90%` Merah.
  static BudgetThresholdStatus thresholdForRatio(double ratio) {
    if (ratio < 0.75) return BudgetThresholdStatus.safe;
    if (ratio <= 0.90) return BudgetThresholdStatus.warning;
    return BudgetThresholdStatus.overbudget;
  }

  /// Menghitung agregasi reaktif atas daftar transaksi & anggaran pada bulan terpilih.
  /// Dirancang O(N) tanpa alokasi berat agar 500+ transaksi tetap render < 500ms at 60 FPS.
  factory BudgetSummary.compute({
    required List<TransactionItem> transactions,
    required List<BudgetItem> budgets,
    required String monthPeriod,
  }) {
    final monthlyTxs = transactions
        .where((tx) => tx.monthPeriod == monthPeriod)
        .toList();
    final monthlyBudgets = budgets
        .where((b) => b.monthPeriod == monthPeriod)
        .toList();

    final spendByCategory = <String, int>{};
    final weeklyTotals = <int>[0, 0, 0, 0];
    var totalSpend = 0;

    for (final tx in monthlyTxs) {
      final cat = CategoryTaxonomy.normalize(tx.category);
      spendByCategory[cat] = (spendByCategory[cat] ?? 0) + tx.amount;
      totalSpend += tx.amount;

      final weekIndex = ((tx.txDate.day - 1) ~/ 7).clamp(0, 3);
      weeklyTotals[weekIndex] += tx.amount;
    }

    // Hitung proporsi Donut Chart dengan rumus `(Total Kategori / Total Pengeluaran) * 100%`
    // Serta sudut minimum (minVisualPct = 3.5%) agar angka ekstrem tidak overlap (`TC-VIS-03`)
    final sortedCategories = spendByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final rawShares = sortedCategories.map((entry) {
      final truePct = totalSpend > 0 ? (entry.value / totalSpend) * 100.0 : 0.0;
      return (category: entry.key, amount: entry.value, truePct: truePct);
    }).toList();

    const minVisualPct = 3.5;
    final visualValues = rawShares
        .map((e) => math.max(e.truePct, minVisualPct))
        .toList();
    final visualSum = visualValues.fold<double>(0, (acc, v) => acc + v);

    final shares = <CategoryShare>[];
    for (var i = 0; i < rawShares.length; i++) {
      final item = rawShares[i];
      final normalizedVisual =
          visualSum > 0 ? (visualValues[i] / visualSum) * 100.0 : 0.0;
      shares.add(
        CategoryShare(
          category: item.category,
          totalAmount: item.amount,
          truePercentage: item.truePct,
          visualPercentage: normalizedVisual,
          color: CategoryTaxonomy.colorFor(item.category),
        ),
      );
    }

    // Bangun daftar progress bar batas anggaran kategori
    final budgetByCat = <String, int>{};
    var totalLimit = 0;
    for (final b in monthlyBudgets) {
      final cat = CategoryTaxonomy.normalize(b.category);
      budgetByCat[cat] = b.limitAmount;
      totalLimit += b.limitAmount;
    }

    final categoriesWithBudget = <String>{
      ...budgetByCat.keys,
      ...spendByCategory.keys,
    };

    final progresses = <CategoryBudgetProgress>[];
    for (final cat in categoriesWithBudget) {
      final spent = spendByCategory[cat] ?? 0;
      final limit = budgetByCat[cat] ?? 1000000;
      final ratio = limit > 0 ? spent / limit : 0.0;
      progresses.add(
        CategoryBudgetProgress(
          category: cat,
          spentAmount: spent,
          limitAmount: limit,
          ratio: ratio,
          status: thresholdForRatio(ratio),
        ),
      );
    }

    progresses.sort((a, b) => b.ratio.compareTo(a.ratio));

    if (totalLimit == 0) totalLimit = 4500000;
    final remaining = totalLimit - totalSpend;
    final overallRatio = totalLimit > 0 ? totalSpend / totalLimit : 0.0;

    return BudgetSummary(
      monthPeriod: monthPeriod,
      totalSpend: totalSpend,
      totalLimit: totalLimit,
      remainingBudget: remaining,
      overallRatio: overallRatio,
      categoryShares: shares,
      budgetProgresses: progresses,
      weeklyTotals: weeklyTotals,
      transactionCount: monthlyTxs.length,
    );
  }
}
