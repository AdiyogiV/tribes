/// Centralized API endpoint configuration.
///
/// All external URLs and API endpoints should be defined here
/// to make them easy to find, update, and swap per environment.
class ApiEndpoints {
  ApiEndpoints._(); // prevent instantiation

  // ── App Deep Links ──────────────────────────────────────────
  /// Base URL for deep links and sharing (also in ShareLinks)
  static const String appBaseUrl = 'https://aurogram.in';

  // ── AI Chat ─────────────────────────────────────────────────
  /// Cloud Run AI chat endpoint
  static const String aiChat =
      'https://aichat-7p5vte54jq-et.a.run.app';

  // ── Geocoding ───────────────────────────────────────────────
  /// Open-Meteo geocoding search API
  static const String geocodingSearch =
      'https://geocoding-api.open-meteo.com/v1/search';

  // ── Logo / Favicon ──────────────────────────────────────────
  /// Clearbit logo API (append /{domain})
  static const String clearbitLogo = 'https://logo.clearbit.com';
}
