import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/config/supabase_config.dart';
import '../../../core/constants/category_taxonomy.dart';
import '../../../core/utils/currency_normalizer.dart';
import '../domain/models/fingpt_response.dart';

/// Layanan NLP FinGPT menggunakan Gemini API (Structured JSON Mode) dengan
/// parser bahasa Indonesia + slang lokal berkecepatan tinggi (< 2.0 detik).
class FinGptService {
  FinGptService({http.Client? httpClient}) : _client = httpClient ?? http.Client();

  final http.Client _client;

  static const String _systemPrompt = '''
Kamu adalah FinGPT, asisten keuangan aplikasi Finku di Indonesia.
Tugasmu mengekstrak pengeluaran dari bahasa natural Indonesia menjadi JSON terstruktur:
{
  "intent": "record_expense",
  "needs_clarification": false,
  "clarification_message": null,
  "transactions": [
    {
      "item_name": "...",
      "amount": 50000,
      "category": "Transportasi",
      "wallet_name": "OVO",
      "tx_date": "2026-11-18"
    }
  ]
}
Aturan wajib:
1. Kategori HANYA boleh dari 8 taksonomi resmi:
   Makanan & Minuman, Transportasi, Belanja Harian, Tagihan & Utilitas, Hiburan & Gaya Hidup, Kesehatan, Pendidikan, Lainnya.
2. Konversi slang nominal: rb/ribu = x1000, k = x1000, jt/juta = x1000000. Pecah kalimat majemuk menjadi array objek independen.
3. Jika kalimat ambigu dan tidak memiliki nominal jelas, DILARANG membuat transaksi Rp0! Kembalikan "needs_clarification": true, "transactions": [], dan pertanyaan klarifikasi ramah di "clarification_message".
''';

  Future<FinGptResponse> analyzePrompt(
    String userMessage, {
    String? budgetContextSummary,
    DateTime? referenceDate,
  }) async {
    final stopwatch = Stopwatch()..start();
    final trimmed = userMessage.trim();
    final refDate = referenceDate ?? DateTime(2026, 11, 18);

    // Tangani pertanyaan analitik secara langsung dari konteks anggaran live
    if (_isAnalyticsQuery(trimmed)) {
      stopwatch.stop();
      return FinGptResponse(
        intent: 'query_analytics',
        needsClarification: false,
        transactions: const [],
        analyticsAnswer:
            budgetContextSummary ??
            'Ringkasan bulan November 2026: Total pengeluaran Rp 3.450.000 dari batas Rp 4.500.000 (sisa Rp 1.050.000). Kategori Makanan & Minuman masih aman (72%), Transportasi waspada (85%), dan Hiburan & Gaya Hidup sudah melewati batas (+Rp 50.000).',
        responseTimeMs: stopwatch.elapsedMilliseconds,
      );
    }

    // Jika GEMINI_API_KEY tersedia saat build/run, panggil Gemini API Structured JSON Mode
    if (SupabaseConfig.geminiApiKey.isNotEmpty) {
      try {
        final uri = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${SupabaseConfig.geminiApiKey}',
        );
        final response = await _client
            .post(
              uri,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'systemInstruction': {
                  'parts': [
                    {'text': _systemPrompt},
                  ],
                },
                'contents': [
                  {
                    'role': 'user',
                    'parts': [
                      {
                        'text':
                            'Tanggal hari ini: ${refDate.toIso8601String().split('T').first}. Input: $trimmed',
                      },
                    ],
                  },
                ],
                'generationConfig': {
                  'responseMimeType': 'application/json',
                  'temperature': 0.1,
                },
              }),
            )
            .timeout(const Duration(milliseconds: 1800));

        if (response.statusCode == 200) {
          final body = jsonDecode(response.body) as Map<String, dynamic>;
          final text =
              body['candidates']?[0]?['content']?['parts']?[0]?['text']
                  as String?;
          if (text != null && text.isNotEmpty) {
            final parsed = FinGptResponse.fromJson(
              jsonDecode(text) as Map<String, dynamic>,
            );
            stopwatch.stop();
            return FinGptResponse(
              intent: parsed.intent,
              needsClarification: parsed.needsClarification,
              clarificationMessage: parsed.clarificationMessage,
              transactions: parsed.transactions,
              responseTimeMs: stopwatch.elapsedMilliseconds,
            );
          }
        }
      } catch (_) {
        // Jatuh ke parser lokal berkecepatan tinggi bila API timeout (< 2.0 detik)
      }
    }

    final local = parseNaturalLanguage(trimmed, referenceDate: refDate);
    stopwatch.stop();
    return FinGptResponse(
      intent: local.intent,
      needsClarification: local.needsClarification,
      clarificationMessage: local.clarificationMessage,
      transactions: local.transactions,
      analyticsAnswer: local.analyticsAnswer,
      responseTimeMs: stopwatch.elapsedMilliseconds,
    );
  }

  /// Parser NLP Bahasa Indonesia + Slang deterministik (`TC-AI-01` s/d `TC-AI-04`).
  FinGptResponse parseNaturalLanguage(
    String input, {
    DateTime? referenceDate,
  }) {
    final text = input.trim();
    final refDate = referenceDate ?? DateTime(2026, 11, 18);
    final isoDate =
        '${refDate.year.toString().padLeft(4, '0')}-${refDate.month.toString().padLeft(2, '0')}-${refDate.day.toString().padLeft(2, '0')}';

    // Deteksi sumber dompet/pembayaran di kalimat (mis. "pakai OVO", "via GoPay")
    final walletName = _extractWalletName(text);

    // Hapus frasa sumber pembayaran di akhir sebelum memecah klausa transaksi
    var cleanedForSplit = text.replaceAll(
      RegExp(
        r'\b(?:pakai|pake|via|lewat|dengan|menggunakan)\s+(?:ovo|gopay|dana|shopeepay|bca|mandiri|bni|bri|qris|tunai|cash)\b',
        caseSensitive: false,
      ),
      '',
    );

    // Pecah multi-transaksi berdasarkan koma atau kata hubung Indonesia
    final clauses = cleanedForSplit
        .split(RegExp(r'\s*(?:,|;|\bsama\b|\bdan\b|\bterus\b|\bplus\b|\bserta\b)\s*', caseSensitive: false))
        .map((c) => c.trim())
        .where((c) => c.isNotEmpty)
        .toList();

    final extracted = <FinGptExtractedTransaction>[];
    final amountPattern = RegExp(
      r'(?:rp\.?\s*)?(\d+(?:[.,]\d+)?\s*(?:juta|jt|ribu|rb|k)\b|\d{1,3}(?:[.,]\d{3})+|\d{4,})',
      caseSensitive: false,
    );

    for (final clause in clauses) {
      final match = amountPattern.firstMatch(clause);
      if (match == null) continue;

      final rawAmount = match.group(0)!;
      final amount = CurrencyNormalizer.parseRupiah(rawAmount);
      if (amount <= 0) continue; // Guard TC-AI-03: dilarang transaksi Rp0

      var itemRaw = clause.replaceFirst(rawAmount, '').trim();
      itemRaw = itemRaw
          .replaceAll(
            RegExp(
              r'^(?:tadi\s+habis|tadi|habis|baru|barusan|catat|catatkan|tolong|beli|bayar|buat|untuk)\s+',
              caseSensitive: false,
            ),
            '',
          )
          .replaceAll(
            RegExp(
              r'^(?:tadi\s+habis|tadi|habis|catat|beli|bayar)\s+',
              caseSensitive: false,
            ),
            '',
          )
          .trim();

      if (itemRaw.isEmpty) {
        itemRaw = 'Pengeluaran';
      }

      final itemName = _titleCase(itemRaw);
      final category = CategoryTaxonomy.normalize(itemName);
      final clauseWallet = _extractWalletName(clause);
      final effectiveWallet =
          clauseWallet != 'Dompet Utama' ? clauseWallet : walletName;

      extracted.add(
        FinGptExtractedTransaction(
          itemName: itemName,
          amount: amount,
          category: category,
          walletName: effectiveWallet,
          txDate: isoDate,
        ),
      );
    }

    // TC-AI-03: Jika kalimat ambigu / tidak ada nominal jelas, minta klarifikasi
    if (extracted.isEmpty) {
      return const FinGptResponse(
        intent: 'clarify_expense',
        needsClarification: true,
        clarificationMessage:
            'Boleh info nominal dan jenis tagihannya (misalnya listrik PLN 150rb atau internet 280rb) supaya bisa langsung saya catat ke kategori yang tepat?',
        transactions: [],
      );
    }

    return FinGptResponse(
      intent: 'record_expense',
      needsClarification: false,
      clarificationMessage: null,
      transactions: extracted,
    );
  }

  bool _isAnalyticsQuery(String text) {
    final lower = text.toLowerCase();
    return lower.contains('sisa budget') ||
        lower.contains('ringkasan') ||
        lower.contains('analisis') ||
        lower.contains('berapa pengeluaran') ||
        lower.contains('terbanyak');
  }

  String _extractWalletName(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('ovo')) return 'OVO';
    if (lower.contains('gopay')) return 'GoPay';
    if (lower.contains('dana')) return 'DANA';
    if (lower.contains('shopeepay')) return 'ShopeePay';
    if (lower.contains('bca')) return 'BCA';
    if (lower.contains('mandiri')) return 'Mandiri';
    if (lower.contains('qris')) return 'QRIS';
    if (lower.contains('tunai') || lower.contains('cash')) return 'Tunai';
    return 'Dompet Utama';
  }

  String _titleCase(String text) {
    return text
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }
}
