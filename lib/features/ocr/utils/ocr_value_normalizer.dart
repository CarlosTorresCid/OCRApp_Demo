import 'package:flutter/foundation.dart';

class OcrValueNormalizer {
  const OcrValueNormalizer._();

  static double? parseNum(String? value) {
    if (value == null || value.trim().isEmpty) return null;

    final original = value;
    final withoutKnownText = _removeKnownText(value.trim());
    final numericCandidate = _extractNumericCandidate(withoutKnownText);

    if (numericCandidate == null || numericCandidate.isEmpty) {
      debugPrint('[NUM_PARSE] No interpretable: "$original"');
      return null;
    }

    final normalized = _normalizeSeparators(numericCandidate);
    final parsed = double.tryParse(normalized);

    if (parsed == null) {
      debugPrint(
        '[NUM_PARSE] No interpretable: "$original" '
        '-> cleaned="$numericCandidate" normalized="$normalized"',
      );
      return null;
    }

    return parsed;
  }

  static String _removeKnownText(String value) {
    return value
        .replaceAll(
          RegExp(
            r'\b(eur|euro|euros|unidades|unidad|uds|ud|un|caja|kg|kgs|l|lt|pza|box|m2|ml)\b',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(RegExp(r'[€%]'), '')
        .trim();
  }

  static String? _extractNumericCandidate(String value) {
    final normalized = value.replaceAll(RegExp(r'\s+'), '');
    final match = RegExp(r'-?\d[\d.,]*').firstMatch(normalized);
    return match?.group(0);
  }

  static String _normalizeSeparators(String value) {
    var result = value;

    final hasDot = result.contains('.');
    final hasComma = result.contains(',');

    if (hasDot && hasComma) {
      final lastDot = result.lastIndexOf('.');
      final lastComma = result.lastIndexOf(',');

      if (lastComma > lastDot) {
        // Formato europeo: 1.200,50 -> 1200.50
        result = result.replaceAll('.', '');
        result = result.replaceAll(',', '.');
      } else {
        // Formato inglés: 1,200.50 -> 1200.50
        result = result.replaceAll(',', '');
      }

      return result;
    }

    if (hasComma && !hasDot) {
      // En albaranes españoles, una coma aislada se interpreta como decimal:
      // 49,670  -> 49.670
      // 215,330 -> 215.330
      // 10,50   -> 10.50
      return result.replaceAll(',', '.');
    }

    if (hasDot && !hasComma) {
      final parts = result.split('.');

      if (parts.length == 2 && parts[1].length == 3 && parts[0].length <= 3) {
        // Formato español de miles: 1.200 -> 1200
        return result.replaceAll('.', '');
      }

      if (parts.length > 2) {
        final lastPart = parts.last;

        if (lastPart.length == 1 || lastPart.length == 2) {
          // Ejemplo defensivo: 1.200.50 -> 1200.50
          final integerPart = parts.sublist(0, parts.length - 1).join();
          return '$integerPart.$lastPart';
        }

        // Ejemplo: 1.200.000 -> 1200000
        return result.replaceAll('.', '');
      }

      return result;
    }

    return result;
  }
}