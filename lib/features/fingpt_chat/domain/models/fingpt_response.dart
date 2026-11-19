import 'package:finku_app/core/constants/category_taxonomy.dart';

/// Transaksi terstruktur hasil pemecahan natural language oleh FinGPT (`FR-AI-02`).
class FinGptExtractedTransaction {
  const FinGptExtractedTransaction({
    required this.itemName,
    required this.amount,
    required this.category,
    required this.walletName,
    required this.txDate,
  });

  final String itemName;
  final int amount;
  final String category;
  final String walletName;
  final String txDate;

  Map<String, dynamic> toJson() => {
    'item_name': itemName,
    'amount': amount,
    'category': CategoryTaxonomy.normalize(category),
    'wallet_name': walletName,
    'tx_date': txDate,
  };

  factory FinGptExtractedTransaction.fromJson(Map<String, dynamic> json) =>
      FinGptExtractedTransaction(
        itemName: json['item_name']?.toString() ?? 'Pengeluaran',
        amount: (json['amount'] as num?)?.toInt() ?? 0,
        category: CategoryTaxonomy.normalize(
          json['category']?.toString() ?? CategoryTaxonomy.lainnya,
        ),
        walletName: json['wallet_name']?.toString() ?? 'Dompet Utama',
        txDate: json['tx_date']?.toString() ?? '2026-11-18',
      );
}

/// Kontrak JSON respons FinGPT sesuai Bab 5.2.4 GEMINI.md.
class FinGptResponse {
  const FinGptResponse({
    required this.intent,
    required this.needsClarification,
    this.clarificationMessage,
    required this.transactions,
    this.analyticsAnswer,
    this.responseTimeMs = 0,
  });

  final String intent; // 'record_expense' | 'clarify_expense' | 'query_analytics'
  final bool needsClarification;
  final String? clarificationMessage;
  final List<FinGptExtractedTransaction> transactions;
  final String? analyticsAnswer;
  final int responseTimeMs;

  int get totalAmount => transactions.fold<int>(0, (acc, e) => acc + e.amount);

  Map<String, dynamic> toJson() => {
    'intent': intent,
    'needs_clarification': needsClarification,
    'clarification_message': clarificationMessage,
    'transactions': transactions.map((e) => e.toJson()).toList(),
  };

  factory FinGptResponse.fromJson(Map<String, dynamic> json) {
    final rawList = (json['transactions'] as List<dynamic>? ?? [])
        .map(
          (e) => FinGptExtractedTransaction.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .where((e) => e.amount > 0) // Guard TC-AI-03: dilarang transaksi Rp0
        .toList();

    final needsClarify =
        (json['needs_clarification'] as bool? ?? false) ||
        (json['intent'] == 'record_expense' && rawList.isEmpty);

    return FinGptResponse(
      intent: json['intent']?.toString() ?? 'record_expense',
      needsClarification: needsClarify,
      clarificationMessage: json['clarification_message']?.toString(),
      transactions: needsClarify ? [] : rawList,
    );
  }
}
