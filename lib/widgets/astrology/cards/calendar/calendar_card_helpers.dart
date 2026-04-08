import 'package:flutter/material.dart';
import 'package:aurogram/utils/theme/app_theme.dart';

/// Extract tithi number from samvat data (normalized to 1-15)
int? extractTithiNumber(Map<String, dynamic>? samvat) {
  if (samvat == null) return null;

  final directNumber =
      samvat['number'] ?? samvat['tithi_number'] ?? samvat['tithiNumber'];
  if (directNumber != null) {
    int? rawNumber;
    if (directNumber is int) {
      rawNumber = directNumber;
    } else {
      rawNumber = int.tryParse(directNumber.toString());
    }

    if (rawNumber != null) {
      if (rawNumber > 15 && rawNumber <= 30) {
        return rawNumber - 15;
      }
      return rawNumber;
    }
  }
  return null;
}

/// Extract paksha from samvat data
String? extractPaksha(Map<String, dynamic>? samvat) {
  if (samvat == null) return null;

  final paksha = (samvat['paksha'] ?? samvat['tithiPaksha'] ?? '')
      .toString()
      .toLowerCase();

  if (paksha.contains('shukla') || paksha.contains('sukla')) {
    return 'shukla';
  }
  if (paksha.contains('krishna') ||
      paksha.contains('krsna') ||
      paksha.contains('krishan')) {
    return 'krishna';
  }

  final rawNumber =
      samvat['number'] ?? samvat['tithi_number'] ?? samvat['tithiNumber'];
  if (rawNumber != null) {
    int? num;
    if (rawNumber is int) {
      num = rawNumber;
    } else {
      num = int.tryParse(rawNumber.toString());
    }
    if (num != null && num > 15 && num <= 30) {
      return 'krishna';
    }
    if (num != null && num >= 1 && num <= 15) {
      return 'shukla';
    }
  }

  return paksha.isNotEmpty ? paksha : null;
}

/// Helper widget to build date component rows
Widget buildDateComponent(String label, String value) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 100,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.primaryColor.withValues(alpha: 0.6),
            height: 1.3,
          ),
        ),
      ),
      Expanded(
        child: Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppTheme.primaryColor,
            height: 1.3,
          ),
        ),
      ),
    ],
  );
}
