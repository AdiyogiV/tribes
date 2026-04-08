import 'package:flutter/material.dart';
import 'package:aurogram/shared/models/astrology_profile.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

/// Horizontal scrollable list of Dosha cards - minimal design
/// Sorted by strength (Strong > Moderate > Mild)
/// Extracts: Mangal, Kaal Sarp, Pitra, Shani, Grahan, Gandmool doshas
class DoshasWidget extends StatelessWidget {
  final AstrologyProfile profile;
  final void Function(
    BuildContext context,
    String name,
    String? description,
    String? severity,
    Color accentColor,
    bool isDark, {
    String? insight,
    String? guidance,
    int? house,
    String? type,
    Map<String, dynamic>? doshaData,
  })? onDoshaTap;

  const DoshasWidget({
    super.key,
    required this.profile,
    this.onDoshaTap,
  });

  /// Get strength priority for sorting (higher = more important)
  static int _getStrengthPriority(String? severity) {
    switch (severity?.toLowerCase()) {
      case 'strong':
      case 'high':
        return 3;
      case 'moderate':
      case 'medium':
        return 2;
      case 'mild':
      case 'weak':
      case 'low':
      case 'present':
        return 1;
      default:
        return 2;
    }
  }

  /// Get color based on strength
  static Color getStrengthColor(String? severity, bool isDark) {
    switch (severity?.toLowerCase()) {
      case 'strong':
      case 'high':
        return isDark ? Colors.amber.shade300 : Colors.amber.shade700;
      case 'moderate':
      case 'medium':
        return isDark ? Colors.orange.shade300 : Colors.orange.shade600;
      case 'mild':
      case 'weak':
      case 'low':
      case 'present':
        return isDark ? Colors.orange.shade200 : Colors.orange.shade400;
      default:
        return isDark ? Colors.orange.shade300 : Colors.orange.shade600;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final doshas = profile.doshas;
    if (doshas == null || doshas.isEmpty) return const SizedBox.shrink();

    var doshaList = _extractDoshas(doshas);
    if (doshaList.isEmpty) return const SizedBox.shrink();

    // Sort by strength (Strong first)
    doshaList.sort((a, b) {
      final aPriority = _getStrengthPriority(a['severity'] as String?);
      final bPriority = _getStrengthPriority(b['severity'] as String?);
      return bPriority.compareTo(aPriority);
    });

    final Color cardColor =
        isDark ? Theme.of(context).colorScheme.surface : Colors.white;
    final screenWidth = MediaQuery.of(context).size.width;
    // Cap card width for web - max 160px per card
    final cardWidth = (screenWidth * 2 / 5).clamp(100.0, 160.0);

    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        clipBehavior: Clip.none,
        itemCount: doshaList.length,
        separatorBuilder: (context, index) => const SizedBox(width: AppDimensions.spacingMd),
        itemBuilder: (context, index) {
          final dosha = doshaList[index];
          final doshaName = dosha['name'] as String;
          final description = dosha['description'] as String?;
          final severity = dosha['severity'] as String? ?? 'Moderate';
          final insight = dosha['insight'] as String?;
          final guidance = dosha['guidance'] as String?;
          final house = dosha['house'] as int?;
          final type = dosha['type'] as String?;
          final doshaColor = getStrengthColor(severity, isDark);

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: SizedBox(
              width: cardWidth,
              child: Material(
                color: cardColor,
                elevation: 2,
                shadowColor: Colors.black.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                child: InkWell(
                  onTap: onDoshaTap != null
                      ? () => onDoshaTap!(
                            context,
                            doshaName,
                            description,
                            severity,
                            doshaColor,
                            isDark,
                            insight: insight,
                            guidance: guidance,
                            house: house,
                            type: type,
                            doshaData: dosha,
                          )
                      : null,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Center(
                      child: Text(
                        doshaName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: doshaColor,
                          height: 1.3,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.visible,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  List<Map<String, dynamic>> _extractDoshas(Map<String, dynamic> doshas) {
    final doshaList = <Map<String, dynamic>>[];

    // 1. MANGAL DOSHA (Mars Dosha)
    if (doshas['mangal_dosha'] == true ||
        doshas['mangalDosha'] == true ||
        doshas['kuja_dosha'] == true) {
      final house = doshas['mangal_dosha_house'] ?? doshas['mangalDoshaHouse'];
      final isMitigated = doshas['mangal_dosha_mitigated'] == true;
      final mitigation = doshas['mangal_dosha_mitigation'];
      doshaList.add({
        'name': 'Mangal Dosha',
        'description': 'Mars holds a significant position in your chart, influencing relationships and partnerships.',
        'severity': doshas['mangal_dosha_severity'] ??
            doshas['mangalDoshaSeverity'] ?? 'Moderate',
        'insight': 'Strong willpower and passionate nature. Channel this energy into fitness, competitive fields, or leadership.',
        'guidance': 'Focus on open communication in relationships. Your direct nature is a strength for building honest connections.',
        'house': house is int ? house : int.tryParse(house?.toString() ?? ''),
        'mangal_dosha_house': house,
        'mangal_dosha_mitigated': isMitigated,
        'mangal_dosha_mitigation': mitigation,
      });
    }
    
    // 2. KAAL SARP DOSHA
    if (doshas['kaal_sarp_dosha'] == true || doshas['kaalSarpDosha'] == true) {
      doshaList.add({
        'name': 'Kaal Sarp Yoga',
        'description': 'All planets align between Rahu and Ketu, creating a focused karmic pattern.',
        'severity': doshas['kaal_sarp_severity'] ??
            doshas['kaalSarpSeverity'] ?? 'Present',
        'insight': 'Concentrated energy toward specific life goals. Many successful individuals have this pattern.',
        'guidance': 'Embrace patience. Success may come in waves. Meditation helps channel this focused energy.',
        'type': 'Karmic Pattern',
      });
    }
    
    // 3. PITRA DOSHA (Ancestral)
    if (doshas['pitra_dosha'] == true || doshas['pitraDosha'] == true) {
      final type = doshas['pitra_dosha_type'] ?? doshas['pitraDoshaType'];
      final afflicted9th = doshas['pitra_dosha_9th_afflicted'] == true;
      doshaList.add({
        'name': 'Pitra Dosha',
        'description': 'Connection to ancestral patterns. Often indicates someone meant to bring positive change to their lineage.',
        'severity': doshas['pitra_dosha_severity'] ??
            doshas['pitraDoshaSeverity'] ?? 'Moderate',
        'insight': 'Deep connection to family and heritage. You may feel called to honor traditions or heal family patterns.',
        'guidance': 'Stay connected with family. Acts of kindness toward elders align well with this energy.',
        'type': type,
        'pitra_dosha_type': type,
        'pitra_dosha_9th_afflicted': afflicted9th,
      });
    }
    
    // 4. SHANI DOSHA (Saturn)
    if (doshas['shani_dosha'] == true || doshas['shaniDosha'] == true) {
      final house = doshas['shani_dosha_house'] ?? doshas['shaniDoshaHouse'];
      final fromMoon = doshas['shani_from_moon'] ?? doshas['shaniFromMoon'];
      doshaList.add({
        'name': 'Shani Yoga',
        'description': 'Saturn\'s influence brings depth, discipline, and the gift of perseverance.',
        'severity': doshas['shani_dosha_severity'] ??
            doshas['shaniDoshaSeverity'] ?? 'Moderate',
        'insight': 'Saturn teaches through patience. Your achievements are built to last.',
        'guidance': 'Embrace gradual progress. Structure and routine support your growth. Time is your ally.',
        'house': house is int ? house : int.tryParse(house?.toString() ?? ''),
        'shani_dosha_house': house,
        'shani_from_moon': fromMoon,
      });
    }

    // 5. GRAHAN DOSHA (Eclipse affliction) - NEW
    if (doshas['grahan_dosha'] == true || doshas['grahanDosha'] == true) {
      final type = doshas['grahan_type'] ?? doshas['grahanType'];
      doshaList.add({
        'name': 'Grahan Dosha',
        'description': 'Eclipse influence on luminaries. Rahu or Ketu closely conjuncts Sun or Moon.',
        'severity': doshas['grahan_severity'] ??
            doshas['grahanSeverity'] ?? 'Moderate',
        'insight': 'Gives depth of perception and often psychic sensitivity. Many healers and researchers have this pattern.',
        'guidance': 'Regular meditation helps balance this energy. Chanting mantras for affected luminary is beneficial.',
        'type': type,
        'grahan_type': type,
      });
    }

    // 6. GANDMOOL DOSHA - NEW
    if (doshas['gandmool_dosha'] == true || doshas['gandmoolDosha'] == true) {
      final nakshatra = doshas['gandmool_nakshatra'] ?? doshas['gandmoolNakshatra'];
      doshaList.add({
        'name': 'Gandmool Dosha',
        'description': 'Birth in ${nakshatra ?? "junction"} nakshatra, a powerful transformative star.',
        'severity': doshas['gandmool_severity'] ??
            doshas['gandmoolSeverity'] ?? 'Present',
        'insight': 'Gandmool nakshatras are powerful but need conscious channeling. Many successful people have this.',
        'guidance': 'Traditional Gandmool Shanti puja is recommended. Nakshatra-specific mantras help balance energy.',
        'type': nakshatra,
        'gandmool_nakshatra': nakshatra,
      });
    }

    // 7. COMBUSTION (Asta) - planets too close to Sun
    if (doshas['has_combustion'] == true || doshas['hasCombustion'] == true) {
      final combustPlanets = doshas['combust_planets'] ?? doshas['combustPlanets'];
      final planetList = combustPlanets is List 
          ? combustPlanets.join(', ')
          : combustPlanets?.toString() ?? '';
      if (planetList.isNotEmpty) {
        doshaList.add({
          'name': 'Combustion',
          'description': '$planetList ${combustPlanets is List && combustPlanets.length > 1 ? "are" : "is"} close to the Sun, affecting their expression.',
          'severity': 'Moderate',
          'insight': 'Combust planets express more subtly, through inner growth rather than outer display.',
          'guidance': 'Strengthen the combust planet through its gemstone or mantra. Self-reflection enhances its gifts.',
          'type': planetList,
          'combust_planets': combustPlanets,
        });
      }
    }

    // Track added doshas to avoid duplicates
    final addedDoshaKeys = <String>{
      'mangal', 'kuja', 'kaal_sarp', 'kaalsarp', 'pitra', 'shani',
      'grahan', 'gandmool', 'combustion', 'combust'
    };

    // Handle any other doshas dynamically
    doshas.forEach((key, value) {
      if (key.toString().toLowerCase().contains('dosha') && value == true) {
        final keyLower = key.toString().toLowerCase();
        if (keyLower.contains('severity')) return;

        final isAlreadyAdded =
            addedDoshaKeys.any((added) => keyLower.contains(added));
        if (isAlreadyAdded) return;

        final cleanKey =
            keyLower.replaceAll('_dosha', '').replaceAll('dosha', '');
        addedDoshaKeys.add(cleanKey);

        String formattedName = key
            .toString()
            .replaceAll('_', ' ')
            .replaceAll(RegExp(r'([a-z])([A-Z])'), r'$1 $2')
            .split(' ')
            .map((w) =>
                w.isNotEmpty ? w[0].toUpperCase() + w.substring(1).toLowerCase() : '')
            .join(' ');

        doshaList.add({
          'name': formattedName,
          'description': 'A unique planetary pattern in your chart.',
          'severity': 'Moderate',
          'insight': 'This placement adds a distinctive quality to your chart.',
          'guidance': 'Understanding this pattern helps you work with its energy.',
        });
      }
    });

    return doshaList;
  }
}
