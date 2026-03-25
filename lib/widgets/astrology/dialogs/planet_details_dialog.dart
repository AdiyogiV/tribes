import 'package:flutter/material.dart';
import 'package:aurogram/utils/astrology/planet_utils.dart';

/// Shows detailed information about a planet in a dialog
class PlanetDetailsDialog extends StatelessWidget {
  final Map<String, dynamic> planet;
  final bool isDark;

  const PlanetDetailsDialog({
    super.key,
    required this.planet,
    required this.isDark,
  });

  static void show(
      BuildContext context, Map<String, dynamic> planet, bool isDark) {
    showDialog(
      context: context,
      builder: (context) => PlanetDetailsDialog(planet: planet, isDark: isDark),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color cardColor =
        isDark ? Theme.of(context).colorScheme.surface : Colors.white;

    final planetName = planet['name'] as String? ?? '—';
    final planetIcon = PlanetUtils.getIcon(planetName);
    final planetColor = PlanetUtils.getColor(planetName, isDark);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Material(
        color: cardColor,
        elevation: 4,
        shadowColor: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: planetColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          planetIcon,
                          size: 32,
                          color: planetColor,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              planetName,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              planet['sign'] as String? ?? '—',
                              style: TextStyle(
                                fontSize: 16,
                                color: planetColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          color: isDark
                              ? Colors.white.withOpacity(0.7)
                              : Colors.black54,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Details
                  _buildDetailRow(
                    'Nakshatra',
                    planet['nakshatraDisplay'] as String? ??
                        planet['nakshatra'] as String? ??
                        '—',
                  ),

                  if (planet['signLord'] != null)
                    _buildDetailRow('Sign Lord', planet['signLord'] as String),

                  if (planet['nakshatraLord'] != null)
                    _buildDetailRow(
                        'Vimsottari Lord', planet['nakshatraLord'] as String),

                  if (planet['nakshatraNumber'] != null)
                    _buildDetailRow(
                        'Nakshatra Number', planet['nakshatraNumber'].toString()),

                  if (planet['degrees'] != null)
                    _buildDetailRow(
                      'Degrees',
                      '${planet['degrees']}° ${planet['minutes']}\' ${planet['seconds']}"',
                    ),

                  if (planet['fullDegree'] != null)
                    _buildDetailRow(
                      'Full Degree',
                      '${(planet['fullDegree'] as num).toStringAsFixed(4)}°',
                    ),

                  if (planet['houseNumber'] != null)
                    _buildDetailRow('House', 'House ${planet['houseNumber']}'),

                  if (planet['longitude'] != null)
                    _buildDetailRow(
                      'Longitude',
                      '${(planet['longitude'] as num).toStringAsFixed(4)}°',
                    ),

                  if (planet['latitude'] != null)
                    _buildDetailRow(
                      'Latitude',
                      '${(planet['latitude'] as num).toStringAsFixed(4)}°',
                    ),

                  if (planet['speed'] != null)
                    _buildDetailRow(
                      'Speed',
                      (planet['speed'] as num).toStringAsFixed(4),
                    ),

                  if (planet['localizedName'] != null)
                    _buildDetailRow(
                        'Localized Name', planet['localizedName'] as String),

                  if (planet['combust'] != null || planet['isCombust'] != null)
                    _buildDetailRow(
                      'Combust',
                      (planet['combust'] ?? planet['isCombust']) == true
                          ? 'Yes'
                          : 'No',
                      isWarning:
                          (planet['combust'] ?? planet['isCombust']) == true,
                    ),

                  if (planet['isRetrograde'] != null ||
                      planet['retrograde'] != null)
                    _buildDetailRow(
                      'Retrograde',
                      (planet['isRetrograde'] ?? planet['retrograde']) == true
                          ? 'Yes'
                          : 'No',
                      isWarning:
                          (planet['isRetrograde'] ?? planet['retrograde']) ==
                              true,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isWarning = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white.withOpacity(0.6) : Colors.black54,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isWarning
                    ? (isDark ? Colors.orange.shade300 : Colors.orange.shade700)
                    : (isDark ? Colors.white : Colors.black87),
              ),
            ),
          ),
        ],
      ),
    );
  }
}




