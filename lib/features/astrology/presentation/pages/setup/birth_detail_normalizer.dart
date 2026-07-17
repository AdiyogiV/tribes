/// Normalisers that make Baba's voice-filled values robust.
///
/// WHY THIS EXISTS: Baba speaks Hindi, so his tool calls arrive with natural
/// words like `पुरुष` for gender or a Devanagari city. The strict setters used
/// to reject these (enum mismatch / geocoder can't find Devanagari) yet Baba
/// still announced success — the exact bug seen in the field. Centralise the
/// tolerance here so BOTH the form UI and the voice tool handlers agree.
class BirthDetailNormalizer {
  BirthDetailNormalizer._();

  /// Map anything the user/Baba might say to the canonical MALE/FEMALE/OTHER,
  /// or null if we truly can't tell. Handles English + common Hindi terms.
  static String? gender(String? raw) {
    if (raw == null) return null;
    final g = raw.trim().toLowerCase();
    if (g.isEmpty) return null;
    const male = {
      'male', 'm', 'man', 'boy', 'पुरुष', 'पुरूष', 'आदमी', 'मर्द', 'लड़का',
    };
    const female = {
      'female', 'f', 'woman', 'girl', 'महिला', 'स्त्री', 'औरत', 'लड़की', 'नारी',
    };
    const other = {
      'other', 'non-binary', 'nonbinary', 'nb', 'अन्य', 'अन्य लिंग',
    };
    if (male.contains(g)) return 'MALE';
    if (female.contains(g)) return 'FEMALE';
    if (other.contains(g)) return 'OTHER';
    // Direct enum passthrough (already canonical).
    final up = g.toUpperCase();
    if (up == 'MALE' || up == 'FEMALE' || up == 'OTHER') return up;
    return null;
  }

  /// Human label for a canonical gender code.
  static String genderLabel(String code) => switch (code) {
        'MALE' => 'Male',
        'FEMALE' => 'Female',
        _ => 'Other',
      };
}
