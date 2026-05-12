import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class ParsedReceipt {
  final double? expense;
  final double? quantity;
  final String? currency;
  final String? unit;
  final String rawText;

  const ParsedReceipt({
    this.expense,
    this.quantity,
    this.currency,
    this.unit,
    required this.rawText,
  });
}

class ReceiptOcrParser {
  static final _textRecognizer = TextRecognizer();

  static Future<ParsedReceipt> parse(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final recognizedText = await _textRecognizer.processImage(inputImage);
    final rawText = recognizedText.text;

    double? expense;
    double? quantity;
    String? currency;
    String? unit;

    final fullTextLower = rawText.toLowerCase();

    // ── Expense / Total amount ──────────────────────────────────
    // Try to find the largest dollar/number near keywords like TOTAL, AMOUNT, SUBTOTAL
    final amountPatterns = [
      RegExp(
          r'(?:total|amount|subtotal|charge|sale)\s*[:\-\$]?\s*([\d,]+\.\d{2})',
          caseSensitive: false),
      RegExp(r'\$\s*([\d,]+\.\d{2})'),
      RegExp(r'usd\s*([\d,]+\.\d{2})', caseSensitive: false),
      RegExp(r'pkr\s*([\d,]+\.\d{2})', caseSensitive: false),
      RegExp(r'(?:rs\.?|rupees?)\s*([\d,]+\.?\d{0,2})', caseSensitive: false),
      RegExp(r'([\d,]+\.\d{2})\s*(?:usd|pkr|rs)'),
    ];

    for (final pattern in amountPatterns) {
      final matches = pattern.allMatches(rawText);
      for (final match in matches) {
        final valueStr = match.group(1)?.replaceAll(',', '');
        final value = double.tryParse(valueStr ?? '');
        if (value != null && value > 0) {
          if (expense == null || value > expense) {
            expense = value;
          }
        }
      }
    }

    // Detect currency
    if (fullTextLower.contains('pkr') ||
        fullTextLower.contains('rs.') ||
        fullTextLower.contains('rupee')) {
      currency = 'PKR';
    } else if (fullTextLower.contains('usd') || rawText.contains('\$')) {
      currency = 'USD';
    }

    // ── Quantity (fuel volume) ──────────────────────────────────
    final qtyPatterns = [
      RegExp(r'(\d+\.?\d*)\s*(gal|gallon|gallons)\b', caseSensitive: false),
      RegExp(r'(\d+\.?\d*)\s*(l|litre|litres|liter|liters|ltr)\b',
          caseSensitive: false),
      RegExp(r'(\d+\.?\d*)\s*(gall?)\b', caseSensitive: false),
    ];

    for (final pattern in qtyPatterns) {
      final matches = pattern.allMatches(rawText);
      for (final match in matches) {
        final valueStr = match.group(1);
        final unitStr = match.group(2)?.toLowerCase() ?? '';
        final value = double.tryParse(valueStr ?? '');
        if (value != null && value > 0) {
          quantity = value;
          if (unitStr.startsWith('gal')) {
            unit = 'gallons';
          } else if (unitStr.startsWith('l')) {
            unit = 'litres';
          }
          break;
        }
      }
      if (quantity != null) break;
    }

    // Fallback: if no unit found but quantity is still null,
    // look for a number near "fuel", "gas", "diesel", "petrol"
    if (quantity == null) {
      final fuelQtyPattern = RegExp(
        r'(?:fuel|gas|diesel|petrol)\s*[:\-]?\s*(\d+\.?\d*)',
        caseSensitive: false,
      );
      final match = fuelQtyPattern.firstMatch(rawText);
      if (match != null) {
        quantity = double.tryParse(match.group(1) ?? '');
      }
    }

    return ParsedReceipt(
      expense: expense,
      quantity: quantity,
      currency: currency,
      unit: unit,
      rawText: rawText,
    );
  }

  static void dispose() {
    _textRecognizer.close();
  }
}
