/// String manipulation utilities used across the app.
///
/// Extracted from [SearchService] to allow reuse in other features.
class StringUtils {
  StringUtils._();

  /// Normalize a string: lowercase, collapse whitespace, trim.
  static String normalize(String str) {
    return str
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Split a string into non-empty word tokens.
  static List<String> tokenize(String str) {
    return str.split(' ').where((word) => word.isNotEmpty).toList();
  }

  /// Capitalize the first character of a string.
  static String capitalizeFirst(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1);
  }

  /// Fuzzy word similarity using character-overlap (Jaccard ≥ 0.7) and prefix matching.
  static bool areWordsSimilar(String word1, String word2) {
    if (word1.isEmpty || word2.isEmpty) return false;

    // If words are very close in length and share most characters
    final lengthDiff = (word1.length - word2.length).abs();
    if (lengthDiff > 2) return false;

    // Check character overlap
    final chars1 = word1.split('').toSet();
    final chars2 = word2.split('').toSet();
    final intersection = chars1.intersection(chars2);
    final union = chars1.union(chars2);

    // If more than 70% of characters match, consider them similar
    if (union.isEmpty) return false;
    final similarity = intersection.length / union.length;
    if (similarity >= 0.7) return true;

    // Check if one word starts with the other (for partial matches)
    if (word1.length >= 3 && word2.length >= 3) {
      if (word1.startsWith(word2) || word2.startsWith(word1)) {
        return true;
      }
    }

    return false;
  }
}
