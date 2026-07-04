/// Chart utilities for Vedic astrology chart rendering
/// Extracted from cosmic_dashboard.dart for reusability and cleaner code
library;

import 'package:aurogram/core/logging/app_logger.dart';

/// Constants for zodiac signs and their mappings
class ChartConstants {
  ChartConstants._();

  /// Sign name to sign index mapping (0=Aries, 1=Taurus, etc.)
  static const Map<String, int> signToIndex = {
    'aries': 0,
    'mesha': 0,
    'ar': 0,
    'taurus': 1,
    'vrishabha': 1,
    'ta': 1,
    'gemini': 2,
    'mithuna': 2,
    'ge': 2,
    'cancer': 3,
    'karka': 3,
    'ca': 3,
    'leo': 4,
    'simha': 4,
    'le': 4,
    'virgo': 5,
    'kanya': 5,
    'vi': 5,
    'libra': 6,
    'tula': 6,
    'li': 6,
    'scorpio': 7,
    'vrishchika': 7,
    'sc': 7,
    'sagittarius': 8,
    'dhanu': 8,
    'sa': 8,
    'capricorn': 9,
    'makara': 9,
    'cp': 9,
    'aquarius': 10,
    'kumbha': 10,
    'aq': 10,
    'pisces': 11,
    'meena': 11,
    'pi': 11,
  };

  /// Zodiac sign abbreviations in order (Aries first)
  static const List<String> zodiacAbbrs = [
    'Ari',
    'Tau',
    'Gem',
    'Can',
    'Leo',
    'Vir',
    'Lib',
    'Sco',
    'Sag',
    'Cap',
    'Aqu',
    'Pis',
  ];

  /// Planet symbols for chart display
  static const Map<String, String> planetSymbols = {
    'sun': '❂',
    'surya': '❂',
    'moon': '☾',
    'chandra': '☾',
    'mars': '✦',
    'mangal': '✦',
    'mercury': '☿',
    'budh': '☿',
    'jupiter': '♃',
    'guru': '♃',
    'venus': '♀',
    'shukra': '♀',
    'saturn': '♄',
    'shani': '♄',
    'rahu': '☊',
    'ketu': '☋',
    'uranus': '♅',
    'neptune': '♆',
    'pluto': '♇',
  };

  /// Planet initials for chart display
  static const Map<String, String> planetInitials = {
    'sun': 'Su',
    'surya': 'Su',
    'moon': 'Mo',
    'chandra': 'Mo',
    'mars': 'Ma',
    'mangal': 'Ma',
    'mercury': 'Me',
    'budh': 'Me',
    'jupiter': 'Ju',
    'guru': 'Ju',
    'venus': 'Ve',
    'shukra': 'Ve',
    'saturn': 'Sa',
    'shani': 'Sa',
    'rahu': 'Ra',
    'ketu': 'Ke',
    'uranus': 'Ur',
    'neptune': 'Ne',
    'pluto': 'Pl',
  };
}

/// Utility class for chart-related operations
class ChartUtils {
  ChartUtils._();

  /// Get planet symbol from planet name
  static String getPlanetSymbol(String name) {
    final lower = name.toLowerCase();
    for (final entry in ChartConstants.planetSymbols.entries) {
      if (lower.contains(entry.key)) {
        return entry.value;
      }
    }
    return '•';
  }

  /// Get planet initials from planet name
  static String getPlanetInitials(String name) {
    final lower = name.toLowerCase();
    for (final entry in ChartConstants.planetInitials.entries) {
      if (lower.contains(entry.key)) {
        return entry.value;
      }
    }
    return name.length >= 2 ? name.substring(0, 2) : name;
  }

  /// Get sign index from longitude (0-11, where 0=Aries)
  static int? getSignIndexFromLongitude(num? longitude) {
    if (longitude == null) return null;
    return (longitude / 30).floor() % 12;
  }

  /// Merge primary positions with fallback, preferring primary data
  /// This ensures no planets are missing if one source has incomplete data
  static Map<String, dynamic> mergePositions(
    Map<String, dynamic>? primary,
    Map<String, dynamic> fallback,
  ) {
    if (primary == null || primary.isEmpty) return fallback;
    if (fallback.isEmpty) return primary;

    // Start with fallback, then overlay primary (primary takes precedence)
    final merged = Map<String, dynamic>.from(fallback);
    for (final entry in primary.entries) {
      if (entry.value is Map<String, dynamic>) {
        merged[entry.key] = entry.value;
      }
    }
    return merged;
  }

  /// Get the lagna (ascendant) sign index from birth chart data
  /// Returns 0 (Aries) if no birth chart available
  static int getLagnaSignIndex(Map<String, dynamic>? birthChartData) {
    if (birthChartData == null) return 0; // Default to Aries for natural zodiac

    try {
      final planetsObj = extractPlanetsMap(birthChartData);
      if (planetsObj != null) {
        final ascendant = planetsObj['Ascendant'] ??
            planetsObj['ascendant'] ??
            planetsObj['0'];
        final degree = (ascendant?['fullDegree'] ?? ascendant?['full_degree']);
        if (degree is num) {
          return (degree / 30).floor() % 12;
        }
      }
    } catch (e) {
      // Ignore errors
    }
    return 0;
  }

  /// Extract planets map from birth chart data
  static Map<String, dynamic>? extractPlanetsMap(
      Map<String, dynamic> birthChartData) {
    final output = birthChartData['output'];
    if (output is Map<String, dynamic>) {
      return Map<String, dynamic>.from(output);
    }
    if (output is List && output.isNotEmpty) {
      final first = output.first;
      if (first is Map<String, dynamic>) {
        return Map<String, dynamic>.from(first);
      }
    }
    return null;
  }

  /// Build houses for current sky chart from planet positions
  /// Places planets by SIGN position (Aries=0, Taurus=1, etc.)
  /// This is South Indian style - signs are fixed positions
  static List<List<String>> buildCurrentSkyHouses(
      Map<String, dynamic> positions) {
    final Map<int, List<String>> tempSignPositions = {};

    // Log the input to debug
    AppLogger.d(
      'buildCurrentSkyHouses: Processing positions',
      category: LogCategory.general,
      data: {
        'positionsCount': positions.length,
        'planets': positions.keys.toList(),
        'samplePlanetData': positions.entries
            .take(3)
            .map((e) => {
                  'planet': e.key,
                  'dataType': e.value.runtimeType.toString(),
                  'dataKeys':
                      e.value is Map ? (e.value as Map).keys.toList() : null,
                  'sign': e.value is Map ? (e.value as Map)['sign'] : null,
                  'longitude':
                      e.value is Map ? (e.value as Map)['longitude'] : null,
                })
            .toList(),
      },
    );

    positions.forEach((planet, data) {
      // Handle Map<Object?, Object?> from backend by converting to Map<String, dynamic>
      Map<String, dynamic>? planetData;
      if (data is Map) {
        planetData = Map<String, dynamic>.from(
            data.map((key, value) => MapEntry(key.toString(), value)));
      } else {
        AppLogger.w(
          'buildCurrentSkyHouses: Planet data is not a Map',
          category: LogCategory.general,
          data: {
            'planet': planet,
            'dataType': data.runtimeType.toString(),
            'data': data.toString(),
          },
        );
        return;
      }

      // Try to get sign index from sign name first
      final sign = planetData['sign']?.toString().toLowerCase() ?? '';
      int? signIndex = ChartConstants.signToIndex[sign];

      // Fallback: calculate from longitude if sign mapping failed
      if (signIndex == null) {
        final longitude = planetData['longitude'] as num?;
        signIndex = getSignIndexFromLongitude(longitude);
      }

      if (signIndex != null) {
        // Place planet at its SIGN position (Aries=0, Taurus=1, etc.)
        tempSignPositions.putIfAbsent(signIndex, () => []);
        // Add retrograde marker if applicable
        final isRetro = planetData['isRetro'] == true;
        final planetName = isRetro ? '$planet(R)' : planet;
        tempSignPositions[signIndex]!.add(planetName);
      } else {
        AppLogger.w(
          'buildCurrentSkyHouses: Could not determine sign index',
          category: LogCategory.general,
          data: {
            'planet': planet,
            'sign': sign,
            'longitude': planetData['longitude'],
            'dataKeys': planetData.keys.toList(),
          },
        );
      }
    });

    final result = List.generate(12, (index) {
      final planetNames = tempSignPositions[index] ?? [];
      if (planetNames.isEmpty) return <String>[];

      final initials = planetNames.map((n) {
        final base = getPlanetInitials(n.replaceAll('(R)', ''));
        return n.contains('(R)') ? '$baseᴿ' : base;
      }).join(' ');

      return ['\n$initials'];
    });

    AppLogger.d(
      'buildCurrentSkyHouses: Result',
      category: LogCategory.general,
      data: {
        'totalPlanetsPlaced': tempSignPositions.values
            .fold<int>(0, (sum, list) => sum + list.length),
        'housesWithPlanets': result.where((h) => h.isNotEmpty).length,
        'planetsByHouse': result
            .asMap()
            .entries
            .where((e) => e.value.isNotEmpty)
            .map((e) => {
                  'house': e.key,
                  'planets': e.value,
                })
            .toList(),
      },
    );

    return result;
  }

  /// Get labels mapped dynamically so the Ascendant (Lagna) is always in House 1 (Top diamond).
  /// North Indian style: House 1 is fixed at top, Signs rotate.
  static List<String> getSignFixedLabels(int lagnaSignIndex) {
    return List.generate(12, (index) {
      // The sign index that occupies this physical house block.
      // House 1 (index 0) gets the lagna sign. House 2 (index 1) gets lagna + 1, etc.
      final signIndex = (lagnaSignIndex + index) % 12;
      final abbr = ChartConstants.zodiacAbbrs[signIndex];
      // House numbers removed per design — show sign abbreviation only.
      return abbr;
    });
  }

  /// Extract houses from birth chart data for chart display
  /// Maps planets into North Indian houses where Lagna is always House 1 (index 0).
  static List<List<String>> extractBirthChartHouses(
      Map<String, dynamic> birthChartData) {
    final lagnaSignIndex = getLagnaSignIndex(birthChartData);
    final Map<int, List<String>> tempHousePositions = {};

    try {
      final planetsObj = extractPlanetsMap(birthChartData);
      if (planetsObj != null) {
        planetsObj.forEach((key, value) {
          if (value is! Map<String, dynamic>) return;
          final name = (value['name'] ?? key)?.toString();

          // Get sign index from degree
          final degree = value['fullDegree'] ?? value['full_degree'];
          int? signIndex;

          if (degree is num) {
            signIndex = (degree / 30).floor() % 12; // 0-11 (Aries=0, etc.)
          }

          if (name != null &&
              name.toLowerCase() != 'ascendant' &&
              signIndex != null) {
            // Calculate which HOUSE this sign falls into given the lagna
            // If lagna is 3 (Cancer), and planet is in 4 (Leo): house is (4 - 3 + 12) % 12 = 1. (2nd house)
            final houseIndex = (signIndex - lagnaSignIndex + 12) % 12;

            tempHousePositions.putIfAbsent(houseIndex, () => []);
            tempHousePositions[houseIndex]!.add(name);
          }
        });
      }
    } catch (e) {
      // Ignore errors
    }

    return List.generate(12, (index) {
      final planetNames = tempHousePositions[index] ?? [];
      if (planetNames.isEmpty) return <String>[];

      final initials = planetNames.map((n) => getPlanetInitials(n)).join(' ');

      return ['\n$initials'];
    });
  }

  /// Get zodiac labels for birth chart (South Indian style)
  static List<String> getZodiacLabels(Map<String, dynamic> birthChartData) {
    final lagnaSignIndex = getLagnaSignIndex(birthChartData);
    return getSignFixedLabels(lagnaSignIndex);
  }
}
