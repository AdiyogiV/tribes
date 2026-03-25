import 'package:flutter/material.dart';
import 'package:aurogram/utils/theme/app_theme.dart';

/// Utility class for planet-related helpers
/// Centralizes all planet symbol, icon, and color mappings
class PlanetUtils {
  PlanetUtils._();

  /// Get Unicode astrological symbol for a planet
  static String getSymbol(String? planetName) {
    switch (planetName?.toLowerCase()) {
      case 'lagna':
      case 'ascendant':
        return '↑';
      case 'sun':
        return '☉';
      case 'moon':
        return '☽';
      case 'mars':
        return '♂';
      case 'mercury':
        return '☿';
      case 'jupiter':
        return '♃';
      case 'venus':
        return '♀';
      case 'saturn':
        return '♄';
      case 'rahu':
        return '☊';
      case 'ketu':
        return '☋';
      case 'uranus':
        return '♅';
      case 'neptune':
        return '♆';
      case 'pluto':
        return '♇';
      default:
        return '★';
    }
  }

  /// Get Material icon for a planet
  static IconData getIcon(String? planetName) {
    switch (planetName?.toLowerCase()) {
      case 'lagna':
      case 'ascendant':
        return Icons.navigation_rounded;
      case 'sun':
        return Icons.wb_sunny_rounded;
      case 'moon':
        return Icons.nightlight_round;
      case 'mars':
        return Icons.local_fire_department_rounded;
      case 'mercury':
        return Icons.air_rounded;
      case 'jupiter':
        return Icons.auto_awesome_rounded;
      case 'venus':
        return Icons.favorite_rounded;
      case 'saturn':
        return Icons.dark_mode_rounded;
      case 'rahu':
        return Icons.change_circle_rounded;
      case 'ketu':
        return Icons.blur_circular_rounded;
      case 'uranus':
        return Icons.waves_rounded;
      case 'neptune':
        return Icons.water_rounded;
      case 'pluto':
        return Icons.brightness_3_rounded;
      default:
        return Icons.star_rounded;
    }
  }

  /// Get theme color for a planet based on dark/light mode
  static Color getColor(String? planetName, bool isDark) {
    switch (planetName?.toLowerCase()) {
      case 'lagna':
      case 'ascendant':
        return isDark ? const Color(0xFF90CAF9) : const Color(0xFF1976D2); // Blue
      case 'sun':
        return isDark ? const Color(0xFFFFD54F) : const Color(0xFFFF8F00); // Golden Orange
      case 'moon':
        return isDark ? const Color(0xFFE0E0E0) : const Color(0xFF607D8B); // Silver/Gray
      case 'mars':
        return isDark ? const Color(0xFFEF5350) : const Color(0xFFD32F2F); // Red
      case 'mercury':
        return isDark ? const Color(0xFF81C784) : const Color(0xFF388E3C); // Green
      case 'jupiter':
        return isDark ? const Color(0xFFFFB74D) : const Color(0xFFF57C00); // Orange/Yellow
      case 'venus':
        return isDark ? const Color(0xFFF48FB1) : const Color(0xFFE91E63); // Pink
      case 'saturn':
        return isDark ? const Color(0xFF7986CB) : const Color(0xFF3F51B5); // Indigo
      case 'rahu':
        return isDark ? const Color(0xFF90A4AE) : const Color(0xFF455A64); // Blue Gray
      case 'ketu':
        return isDark ? const Color(0xFFBCAAA4) : const Color(0xFF795548); // Brown
      case 'uranus':
        return isDark ? const Color(0xFF4DD0E1) : const Color(0xFF0097A7); // Cyan
      case 'neptune':
        return isDark ? const Color(0xFF80DEEA) : const Color(0xFF00838F); // Teal
      case 'pluto':
        return isDark ? const Color(0xFFCE93D8) : const Color(0xFF7B1FA2); // Purple
      default:
        return AppTheme.primaryColor;
    }
  }

  /// Planet order for display in charts
  static const List<Map<String, dynamic>> planetOrder = [
    {'name': 'Ascendant', 'label': 'Lagna', 'legacy': '0'},
    {'name': 'Sun', 'label': 'Sun', 'legacy': '1'},
    {'name': 'Moon', 'label': 'Moon', 'legacy': '2'},
    {'name': 'Mars', 'label': 'Mars', 'legacy': '3'},
    {'name': 'Mercury', 'label': 'Mercury', 'legacy': '4'},
    {'name': 'Jupiter', 'label': 'Jupiter', 'legacy': '5'},
    {'name': 'Venus', 'label': 'Venus', 'legacy': '6'},
    {'name': 'Saturn', 'label': 'Saturn', 'legacy': '7'},
    {'name': 'Rahu', 'label': 'Rahu', 'legacy': '8'},
    {'name': 'Ketu', 'label': 'Ketu', 'legacy': '9'},
    {'name': 'Uranus', 'label': 'Uranus'},
    {'name': 'Neptune', 'label': 'Neptune'},
    {'name': 'Pluto', 'label': 'Pluto'},
  ];

  /// Vedic zodiac signs in order
  static const List<String> vedicSigns = [
    'Aries', 'Taurus', 'Gemini', 'Cancer', 'Leo', 'Virgo',
    'Libra', 'Scorpio', 'Sagittarius', 'Capricorn', 'Aquarius', 'Pisces',
  ];

  /// 27 Nakshatras in order
  static const List<String> nakshatras = [
    'Ashwini', 'Bharani', 'Krittika', 'Rohini', 'Mrigashira', 'Ardra',
    'Punarvasu', 'Pushya', 'Ashlesha', 'Magha', 'Purva Phalguni',
    'Uttara Phalguni', 'Hasta', 'Chitra', 'Swati', 'Vishakha', 'Anuradha',
    'Jyeshtha', 'Mula', 'Purva Ashadha', 'Uttara Ashadha', 'Shravana',
    'Dhanishta', 'Shatabhisha', 'Purva Bhadrapada', 'Uttara Bhadrapada', 'Revati',
  ];

  /// Derive zodiac sign from degree
  static String? deriveSign(num? degree) {
    if (degree == null) return null;
    return vedicSigns[(degree ~/ 30) % 12];
  }

  /// Derive nakshatra from degree
  static String? deriveNakshatra(num? degree) {
    if (degree == null) return null;
    final index = (degree / (360 / 27)).floor() % 27;
    return nakshatras[index];
  }
}




