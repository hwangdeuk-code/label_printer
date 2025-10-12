// Unified barcode types used across the app, decoupled from external packages.
enum BarcodeType {
  Code128,
  Code39,
  Code93,
  QrCode,
  MicroQrCode,
  PDF417,
  DataMatrix,
  CodeEAN13,
  CodeEAN8,
  UpcA,
  Itf,
}

/// Helpers for validating/normalizing barcode payloads before preview/print.
///
/// Notes
/// - For EAN-13/UPC-A/EAN-8: if input has no check digit (12/11/7 digits),
///   we compute and append it. If it already has a check digit but is wrong,
///   we fix it when [strict] is false (default). Set [strict]=true to throw.
/// - For ITF (Interleaved 2 of 5): requires an even number of digits; we
///   left-pad with '0' when odd. Non-digits are stripped.
/// - For other symbologies we return the original trimmed string.
class BarcodeDataHelper {
  /// High-level normalization for printing. Returns a safe payload string.
  static String normalizeForPrint(BarcodeType type, String raw,
      {bool strict = false}) {
    switch (type) {
      case BarcodeType.CodeEAN13:
        return ean13(raw, strict: strict);
      case BarcodeType.UpcA:
        return upcA(raw, strict: strict);
      case BarcodeType.CodeEAN8:
        return ean8(raw, strict: strict);
      case BarcodeType.Itf:
        return itf(raw);
      default:
        return raw.trim();
    }
  }

  /// Normalize to 13 digits with a valid EAN-13 check digit.
  static String ean13(String input, {bool strict = false}) {
    final digits = _digitsOnly(input);
    if (digits.length == 12) {
      final cd = _eanUpcMod10(digits);
      return digits + cd.toString();
    }
    if (digits.length == 13) {
      final base = digits.substring(0, 12);
      final expected = _eanUpcMod10(base);
      final provided = int.tryParse(digits[12]) ?? -1;
      if (expected == provided) return digits;
      if (strict) {
        throw FormatException('Invalid EAN-13 check digit');
      }
      return base + expected.toString();
    }
    if (strict) throw FormatException('EAN-13 requires 12 or 13 digits');
    // Best-effort: truncate/pad to 12 and compute
    final base = _padLeft(_truncate(digits, 12), 12, '0');
    final cd = _eanUpcMod10(base);
    return base + cd.toString();
  }

  /// Normalize to 12 digits with a valid UPC-A check digit.
  static String upcA(String input, {bool strict = false}) {
    final digits = _digitsOnly(input);
    if (digits.length == 11) {
      final cd = _upcAMod10(digits);
      return digits + cd.toString();
    }
    if (digits.length == 12) {
      final base = digits.substring(0, 11);
      final expected = _upcAMod10(base);
      final provided = int.tryParse(digits[11]) ?? -1;
      if (expected == provided) return digits;
      if (strict) {
        throw FormatException('Invalid UPC-A check digit');
      }
      return base + expected.toString();
    }
    if (strict) throw FormatException('UPC-A requires 11 or 12 digits');
    // Best-effort: truncate/pad to 11 and compute
    final base = _padLeft(_truncate(digits, 11), 11, '0');
    final cd = _upcAMod10(base);
    return base + cd.toString();
  }

  /// Normalize to 8 digits with a valid EAN-8 check digit.
  static String ean8(String input, {bool strict = false}) {
    final digits = _digitsOnly(input);
    if (digits.length == 7) {
      final cd = _ean8Mod10(digits);
      return digits + cd.toString();
    }
    if (digits.length == 8) {
      final base = digits.substring(0, 7);
      final expected = _ean8Mod10(base);
      final provided = int.tryParse(digits[7]) ?? -1;
      if (expected == provided) return digits;
      if (strict) {
        throw FormatException('Invalid EAN-8 check digit');
      }
      return base + expected.toString();
    }
    if (strict) throw FormatException('EAN-8 requires 7 or 8 digits');
    // Best-effort
    final base = _padLeft(_truncate(digits, 7), 7, '0');
    final cd = _ean8Mod10(base);
    return base + cd.toString();
  }

  /// Ensure ITF payload has digits only and even length (pad-left with '0' if odd).
  static String itf(String input) {
    String digits = _digitsOnly(input);
    if (digits.isEmpty) return '00';
    if (digits.length.isOdd) digits = '0$digits';
    return digits;
  }

  // --- internals ---

  // EAN-13/UPC-A mod10 for a 12- or 11-digit base respectively, using EAN weighting for 12-digit base.
  static int _eanUpcMod10(String base12) {
    // EAN-13 rule on 12 digits (positions 1..12): sum(odd) + 3*sum(even)
    int sumOdd = 0, sumEven = 0;
    for (int i = 0; i < base12.length; i++) {
      final d = base12.codeUnitAt(i) - 48;
      if ((i % 2) == 0) sumOdd += d; else sumEven += d; // i=0 => pos1 (odd)
    }
    final total = sumOdd + 3 * sumEven;
    return (10 - (total % 10)) % 10;
  }

  // UPC-A rule on 11 digits (positions 1..11): 3*sum(odd) + sum(even)
  static int _upcAMod10(String base11) {
    int sumOdd = 0, sumEven = 0;
    for (int i = 0; i < base11.length; i++) {
      final d = base11.codeUnitAt(i) - 48;
      if ((i % 2) == 0) sumOdd += d; else sumEven += d; // i=0 => pos1 (odd)
    }
    final total = 3 * sumOdd + sumEven;
    return (10 - (total % 10)) % 10;
  }

  // EAN-8 rule on 7 digits (positions 1..7): 3*sum(odd) + sum(even)
  static int _ean8Mod10(String base7) {
    int sumOdd = 0, sumEven = 0;
    for (int i = 0; i < base7.length; i++) {
      final d = base7.codeUnitAt(i) - 48;
      if ((i % 2) == 0) sumOdd += d; else sumEven += d;
    }
    final total = 3 * sumOdd + sumEven;
    return (10 - (total % 10)) % 10;
  }

  static String _digitsOnly(String s) => s.replaceAll(RegExp(r'\D'), '');
  static String _truncate(String s, int maxLen) =>
      (s.length <= maxLen) ? s : s.substring(s.length - maxLen);
  static String _padLeft(String s, int width, String ch) =>
      (s.length >= width) ? s : ch * (width - s.length) + s;
}
