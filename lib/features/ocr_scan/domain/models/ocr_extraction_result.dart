import 'package:finku_app/core/constants/category_taxonomy.dart';

/// Item baris pada hasil ekstraksi struk OCR (`FR-OCR-03`).
class OcrReceiptLineItem {
  const OcrReceiptLineItem({
    required this.name,
    required this.qty,
    required this.price,
  });

  final String name;
  final int qty;
  final int price;

  int get subtotal => qty * price;

  Map<String, dynamic> toJson() => {
    'name': name,
    'qty': qty,
    'price': price,
  };

  factory OcrReceiptLineItem.fromJson(Map<String, dynamic> json) =>
      OcrReceiptLineItem(
        name: json['name']?.toString() ?? 'Item',
        qty: (json['qty'] as num?)?.toInt() ?? 1,
        price: (json['price'] as num?)?.toInt() ?? 0,
      );
}

/// Kontrak JSON hasil ekstraksi OCR sesuai Bab 5.1.3 GEMINI.md (`FR-OCR-03`).
class OcrExtractionResult {
  const OcrExtractionResult({
    required this.merchantName,
    required this.txDate,
    required this.items,
    required this.taxAmount,
    required this.discountAmount,
    required this.totalAmount,
    required this.suggestedCategory,
    required this.confidenceScore,
    this.processingMs = 0,
    this.rawText = '',
  });

  final String merchantName;
  final String txDate; // YYYY-MM-DD
  final List<OcrReceiptLineItem> items;
  final int taxAmount;
  final int discountAmount;
  final int totalAmount;
  final String suggestedCategory;
  final double confidenceScore;
  final int processingMs;
  final String rawText;

  Map<String, dynamic> toJson() => {
    'merchant_name': merchantName,
    'tx_date': txDate,
    'items': items.map((e) => e.toJson()).toList(),
    'tax_amount': taxAmount,
    'discount_amount': discountAmount,
    'total_amount': totalAmount,
    'suggested_category': CategoryTaxonomy.normalize(suggestedCategory),
    'confidence_score': confidenceScore,
  };

  factory OcrExtractionResult.fromJson(Map<String, dynamic> json) =>
      OcrExtractionResult(
        merchantName: json['merchant_name']?.toString() ?? 'Merchant',
        txDate: json['tx_date']?.toString() ?? '2026-11-18',
        items: (json['items'] as List<dynamic>? ?? [])
            .map((e) => OcrReceiptLineItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        taxAmount: (json['tax_amount'] as num?)?.toInt() ?? 0,
        discountAmount: (json['discount_amount'] as num?)?.toInt() ?? 0,
        totalAmount: (json['total_amount'] as num?)?.toInt() ?? 0,
        suggestedCategory: CategoryTaxonomy.normalize(
          json['suggested_category']?.toString() ?? CategoryTaxonomy.lainnya,
        ),
        confidenceScore: (json['confidence_score'] as num?)?.toDouble() ?? 0.9,
      );

  OcrExtractionResult copyWith({
    String? merchantName,
    String? txDate,
    List<OcrReceiptLineItem>? items,
    int? taxAmount,
    int? discountAmount,
    int? totalAmount,
    String? suggestedCategory,
    double? confidenceScore,
    int? processingMs,
    String? rawText,
  }) {
    return OcrExtractionResult(
      merchantName: merchantName ?? this.merchantName,
      txDate: txDate ?? this.txDate,
      items: items ?? this.items,
      taxAmount: taxAmount ?? this.taxAmount,
      discountAmount: discountAmount ?? this.discountAmount,
      totalAmount: totalAmount ?? this.totalAmount,
      suggestedCategory: suggestedCategory ?? this.suggestedCategory,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      processingMs: processingMs ?? this.processingMs,
      rawText: rawText ?? this.rawText,
    );
  }
}
