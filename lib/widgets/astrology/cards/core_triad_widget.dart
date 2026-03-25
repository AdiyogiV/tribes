import 'package:flutter/material.dart';
import 'package:aurogram/models/astrology_profile.dart';
import 'package:aurogram/utils/astrology/planet_utils.dart';
import 'package:aurogram/utils/logging/app_logger.dart';

/// Horizontal scrollable list of planet cards showing position in signs
class CoreTriadWidget extends StatelessWidget {
  final AstrologyProfile profile;
  final void Function(BuildContext context, Map<String, dynamic> planet, bool isDark)?
      onPlanetTap;

  const CoreTriadWidget({
    super.key,
    required this.profile,
    this.onPlanetTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color cardColor =
        isDark ? Theme.of(context).colorScheme.surface : Colors.white;
    
    // Use pre-processed planets from backend, fallback to extraction if needed
    final planets =
        profile.processedPlanets ?? _extractAllPlanets(profile.birthChartData);

    final screenWidth = MediaQuery.of(context).size.width;
    // Cap card width for web - max 150px per card
    final cardWidth = ((screenWidth - 32 - 24) / 3).clamp(80.0, 150.0);

    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        clipBehavior: Clip.none,
        itemCount: planets.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final planet = planets[index];
          final planetName = planet['name'] as String? ?? '—';
          final isRetrograde = planet['isRetrograde'] == true;
          final nakshatraLabel = planet['nakshatra'] as String? ?? '—';

          final planetColor = PlanetUtils.getColor(planetName, isDark);

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: SizedBox(
              width: cardWidth,
              child: Material(
                color: cardColor,
                elevation: 2,
                shadowColor: Colors.black.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  onTap: onPlanetTap != null
                      ? () => onPlanetTap!(context, planet, isDark)
                      : null,
                  borderRadius: BorderRadius.circular(16),
                  child: _PlanetCard(
                    planetName: planetName,
                    sign: planet['sign'] as String? ?? '—',
                    nakshatra: nakshatraLabel,
                    isRetrograde: isRetrograde,
                    planetColor: planetColor,
                    isDark: isDark,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  List<Map<String, dynamic>> _extractAllPlanets(
      Map<String, dynamic>? birthChartData) {
    final List<Map<String, dynamic>> planets = [];

    if (birthChartData == null) return planets;

    Map<String, dynamic>? planetsObj;
    try {
      final output = birthChartData['output'];
      if (output is Map<String, dynamic>) {
        planetsObj = Map<String, dynamic>.from(output);
      } else if (output is List && output.isNotEmpty) {
        final first = output.first;
        if (first is Map<String, dynamic>) {
          planetsObj = Map<String, dynamic>.from(first);
        }
      }
    } catch (e, stackTrace) {
      AppLogger.e(
        'Error reading planet data',
        category: LogCategory.general,
        error: e,
        stackTrace: stackTrace,
      );
    }

    if (planetsObj == null) return planets;

    bool? parseBool(dynamic value) {
      if (value == null) return null;
      if (value is bool) return value;
      if (value is num) return value != 0;
      if (value is String) {
        final lower = value.toLowerCase();
        if (lower == 'true') return true;
        if (lower == 'false') return false;
      }
      return null;
    }

    String? formatLine(List<String?> parts) {
      final filtered = parts
          .where((part) => part != null && part.trim().isNotEmpty)
          .toList();
      if (filtered.isEmpty) return null;
      return filtered.map((e) => e!.trim()).join(' • ');
    }

    Map<String, dynamic>? resolvePlanet(String name, {String? legacyKey}) {
      if (planetsObj!.containsKey(name)) {
        final value = planetsObj[name];
        if (value is Map<String, dynamic>) return value;
      }
      if (legacyKey != null && planetsObj.containsKey(legacyKey)) {
        final value = planetsObj[legacyKey];
        if (value is Map<String, dynamic>) return value;
      }
      final entry = planetsObj.entries.firstWhere(
        (element) =>
            element.key.toString().toLowerCase() == name.toLowerCase(),
        orElse: () => const MapEntry('', null),
      );
      if (entry.value is Map<String, dynamic>) {
        return entry.value as Map<String, dynamic>;
      }
      return null;
    }

    for (final planetInfo in PlanetUtils.planetOrder) {
      final planetData = resolvePlanet(
        planetInfo['name'] as String,
        legacyKey: planetInfo['legacy'] as String?,
      );
      if (planetData == null) continue;

      final fullDegree =
          (planetData['fullDegree'] ?? planetData['full_degree']) as num?;
      final degreesInSign = fullDegree != null ? fullDegree % 30 : null;
      final degrees =
          (planetData['degrees'] as num?) ?? degreesInSign?.floor();
      final minutes = planetData['minutes'] ??
          (degreesInSign != null
              ? ((degreesInSign - (degreesInSign.floor())) * 60).floor()
              : null);
      final seconds = planetData['seconds'] ??
          (degreesInSign != null
              ? ((((degreesInSign - degreesInSign.floor()) * 60) % 1) * 60)
                  .floor()
              : null);

      final sign =
          planetData['zodiac_sign_name'] ?? PlanetUtils.deriveSign(fullDegree);
      final nakshatraName = planetData['nakshatra_name'] ??
          PlanetUtils.deriveNakshatra(fullDegree);
      final nakshatraPada = planetData['nakshatra_pada'];

      final houseNumber =
          planetData['house_number'] ?? planetData['houseNumber'];

      final retrograde = parseBool(planetData['isRetro']) ??
          parseBool(planetData['retrograde']);

      final combust =
          parseBool(planetData['combust']) ?? parseBool(planetData['isCombust']);

      planets.add({
        'name': planetInfo['label'],
        'sign': sign ?? '—',
        'signLord': planetData['zodiac_sign_lord'],
        'nakshatra': nakshatraName ?? '—',
        'nakshatraLord': planetData['nakshatra_vimsottari_lord'],
        'nakshatraPada': nakshatraPada,
        'nakshatraNumber': planetData['nakshatra_number'],
        'houseNumber': houseNumber,
        'fullDegree': fullDegree,
        'degrees': degrees,
        'minutes': minutes,
        'seconds': seconds,
        'longitude': planetData['longitude'],
        'latitude': planetData['latitude'],
        'speed': planetData['speed'],
        'combust': combust,
        'isRetrograde': retrograde,
        'localizedName': planetData['localized_name'],
        'nakshatraDisplay': formatLine([
          nakshatraName,
          nakshatraPada != null ? 'Pada $nakshatraPada' : null,
        ]),
        'metaLine': formatLine([
          houseNumber != null ? 'House $houseNumber' : null,
          planetData['zodiac_sign_lord'] != null
              ? 'Lord ${planetData['zodiac_sign_lord']}'
              : null,
        ]),
        'rawData': planetData,
      });
    }

    return planets;
  }
}

class _PlanetCard extends StatelessWidget {
  final String planetName;
  final String sign;
  final String nakshatra;
  final bool isRetrograde;
  final Color planetColor;
  final bool isDark;

  const _PlanetCard({
    required this.planetName,
    required this.sign,
    required this.nakshatra,
    required this.isRetrograde,
    required this.planetColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final symbol = PlanetUtils.getSymbol(planetName);

    return Container(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: planetName.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: planetColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                      TextSpan(
                        text: '  $symbol',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: planetColor,
                        ),
                      ),
                    ],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isRetrograde)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'R',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color:
                          isDark ? Colors.red.shade300 : Colors.red.shade700,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            sign,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black87,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            nakshatra,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: planetColor.withValues(alpha: 0.75),
              height: 1.3,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}




