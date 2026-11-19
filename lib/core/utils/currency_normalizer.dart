/// Utilitas normalisasi & pemformatan Rupiah multi-format (`TC-OCR-04` & `DESIGN.md`).
class CurrencyNormalizer {
  CurrencyNormalizer._();

  /// Menormalisasi string nominal multi-format ke integer Rupiah murni:
  /// - Format Indonesia bertitik: `'15.000'`, `'Rp 15.000,-'`, `'Rp25.604'` -> `15000`, `25604`
  /// - Format internasional berkoma + desimal: `'15,000.00'`, `'1,250,500.00'` -> `15000`, `1250500`
  /// - Format desimal koma Indonesia: `'15.000,00'` -> `15000`
  /// - Slang Indonesia: `'50rb'`, `'2ribu'`, `'18k'`, `'1.5jt'`, `'1,5 juta'` -> `50000`, `2000`, `18000`, `1500000`
  static int parseRupiah(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return 0;

    final isNegative = trimmed.startsWith('-');
    var cleaned = trimmed
        .toLowerCase()
        .replaceAll('rp', '')
        .replaceAll('idr', '')
        .replaceAll(',-', '')
        .replaceAll('.-', '')
        .replaceAll(' ', '')
        .replaceAll('\u00A0', '');

    if (cleaned.startsWith('-') || cleaned.startsWith('+')) {
      cleaned = cleaned.substring(1);
    }

    if (cleaned.isEmpty) return 0;

    // Cek akhiran slang: jt / juta, rb / ribu, k
    final multiplierMatch = RegExp(r'^([0-9.,]+)(juta|jt|ribu|rb|k)$').firstMatch(cleaned);
    if (multiplierMatch != null) {
      final numPart = multiplierMatch.group(1)!;
      final suffix = multiplierMatch.group(2)!;
      final multiplier = (suffix == 'jt' || suffix == 'juta') ? 1000000 : 1000;
      final parsedDouble = _parseDecimalOrInteger(numPart);
      final value = (parsedDouble * multiplier).round();
      return isNegative ? -value : value;
    }

    // Cek angka dengan desimal 2 digit di akhir (e.g. 15,000.00 atau 15.000,00)
    final commaThousandDotDecimal = RegExp(r'^\d{1,3}(,\d{3})+\.\d{1,2}$');
    final dotThousandCommaDecimal = RegExp(r'^\d{1,3}(\.\d{3})+,\d{1,2}$');
    final simpleDotDecimal = RegExp(r'^\d+\.\d{1,2}$');
    final simpleCommaDecimal = RegExp(r'^\d+,\d{1,2}$');

    int result;
    if (commaThousandDotDecimal.hasMatch(cleaned)) {
      final intPart = cleaned.split('.').first.replaceAll(',', '');
      result = int.tryParse(intPart) ?? 0;
    } else if (dotThousandCommaDecimal.hasMatch(cleaned)) {
      final intPart = cleaned.split(',').first.replaceAll('.', '');
      result = int.tryParse(intPart) ?? 0;
    } else if (simpleDotDecimal.hasMatch(cleaned)) {
      // Pada konteks Rupiah tanpa pemisah ribuan, e.g. 15000.00 vs 15.000
      final parts = cleaned.split('.');
      if (parts[1].length == 2) {
        result = int.tryParse(parts[0]) ?? 0;
      } else {
        result = int.tryParse(cleaned.replaceAll('.', '')) ?? 0;
      }
    } else if (simpleCommaDecimal.hasMatch(cleaned)) {
      final parts = cleaned.split(',');
      result = int.tryParse(parts[0]) ?? 0;
    } else {
      // Hapus seluruh pemisah ribuan (. dan ,) dan karakter non-digit
      final digitsOnly = cleaned.replaceAll(RegExp(r'[^0-9]'), '');
      result = int.tryParse(digitsOnly) ?? 0;
    }

    return isNegative ? -result : result;
  }

  static double _parseDecimalOrInteger(String rawNum) {
    // Contoh: "1.5" atau "1,5" -> 1.5; "1.500" -> 1500
    if (RegExp(r'^\d+[.,]\d{1,2}$').hasMatch(rawNum)) {
      return double.tryParse(rawNum.replaceAll(',', '.')) ?? 0.0;
    }
    final digits = rawNum.replaceAll(RegExp(r'[^0-9]'), '');
    return double.tryParse(digits) ?? 0.0;
  }

  /// Memformat integer ke standar `DESIGN.md`: `Rp 1.500.000` atau `-Rp 250.000`.
  static String formatRupiah(int amount, {bool withPrefix = true}) {
    final isNeg = amount < 0;
    final absStr = amount.abs().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < absStr.length; i++) {
      final reverseIdx = absStr.length - i;
      if (i > 0 && reverseIdx % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(absStr[i]);
    }
    final formattedNumber = buffer.toString();
    if (!withPrefix) {
      return isNeg ? '-$formattedNumber' : formattedNumber;
    }
    return isNeg ? '-Rp $formattedNumber' : 'Rp $formattedNumber';
  }

  /// Format ringkas untuk tengah Donut Chart & Sparkline (mis. `3.45M`, `600rb`).
  static String formatCompact(int amount) {
    final abs = amount.abs();
    if (abs >= 1000000) {
      final val = abs / 1000000;
      final str = val == val.roundToDouble()
          ? val.toInt().toString()
          : val.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
      return '${str}M';
    }
    if (abs >= 1000) {
      final val = abs / 1000;
      final str = val == val.roundToDouble()
          ? val.toInt().toString()
          : val.toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '');
      return '${str}k';
    }
    return abs.toString();
  }
}
