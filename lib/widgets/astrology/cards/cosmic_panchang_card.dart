import 'package:flutter/material.dart';
import 'package:aurogram/utils/theme/app_theme.dart';

/// Card to display Panchang information (Nakshatra, Yoga, Karana)
/// Matches astrology details page card styling
class CosmicPanchangCard extends StatelessWidget {
  final Map<String, dynamic> panchang;
  final Color brown;

  const CosmicPanchangCard({
    super.key,
    required this.panchang,
    required this.brown,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color cardColor =
        isDark ? Theme.of(context).colorScheme.surface : Colors.white;
    final c = AppTheme.primaryColor;

    final nakshatra = _extractValue(panchang['nakshatra']);
    final yoga = _extractValue(panchang['yoga']);
    final karana = _extractValue(panchang['karana']);

    final items = <MapEntry<String, String>>[];
    if (nakshatra.isNotEmpty) items.add(MapEntry('Nakshatra', nakshatra));
    if (yoga.isNotEmpty) items.add(MapEntry('Yoga', yoga));
    if (karana.isNotEmpty) items.add(MapEntry('Karana', karana));

    if (items.isEmpty) return const SizedBox.shrink();

    return Material(
      color: cardColor,
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header - Title Case, matches astrology details page
            Text(
              'Panchang',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: c,
              ),
            ),
            const SizedBox(height: 12),
            // Items in row
            Row(
              children: items.map((item) {
                return Expanded(
                  child: Column(
                    children: [
                      Text(
                        item.key,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: c.withValues(alpha: 0.5),
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.value,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: c,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  String _extractValue(dynamic value) {
    if (value == null) return '';
    if (value is Map) {
      return value['name']?.toString() ??
          value['tithi']?.toString() ??
          value['nakshatra']?.toString() ??
          value['yoga']?.toString() ??
          value.values.first?.toString() ??
          '';
    }
    return value.toString();
  }
}
