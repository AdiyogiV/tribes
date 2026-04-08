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
      // Some APIs return continuous 1-30 numbering
      // Normalize to 1-15 for both pakshas
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

  // Check if tithi number is 16-30 (continuous numbering = Krishna paksha)
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
      return 'shukla'; // Default for 1-15 range
    }
  }

  return paksha.isNotEmpty ? paksha : null;
}
