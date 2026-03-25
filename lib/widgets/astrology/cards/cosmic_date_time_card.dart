import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:aurogram/utils/logging/app_logger.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/widgets/astrology/cards/vedic_time_utils.dart';
import 'package:aurogram/widgets/astrology/cards/moon_phase_strip.dart';

/// Static flag to track if moon phase has been logged (once per session)
bool _loggedMoonPhase = false;

/// Date and time card for Cosmic Dashboard
/// Shows both Vedic and Western time formats
/// Matches astrology details page card styling
class CosmicDateTimeCard extends StatelessWidget {
  final Map<String, dynamic>? samvat;
  final Color brown;

  const CosmicDateTimeCard({
    super.key,
    required this.samvat,
    required this.brown,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color cardColor =
        isDark ? Theme.of(context).colorScheme.surface : Colors.white;
    final c = AppTheme.primaryColor;

    final now = DateTime.now();
    final westernDate = DateFormat('EEEE, d MMMM yyyy').format(now);
    final timeStr = DateFormat('h:mm a').format(now);

    final vedicTimeDetails = VedicTimeUtils.getVedicTimeDetails(now);
    final fullVedicDate = VedicTimeUtils.buildFullVedicDate(samvat);
    final samvatYear = VedicTimeUtils.buildSamvatYear(samvat);

    // Extract moon phase data
    // Backend stores as 'number', insight panchang uses 'tithi_number' or has tithi name
    int? tithiNumber = _extractTithiNumber(samvat);
    final pakshaRaw = _extractPaksha(samvat);
    final paksha = pakshaRaw.isNotEmpty ? pakshaRaw : 'shukla';
    final hasMoonPhase = tithiNumber != null && pakshaRaw.isNotEmpty;
    
    // Debug log for moon phase (only once per session when we have data)
    if (samvat != null && !_loggedMoonPhase) {
      _loggedMoonPhase = true;
      final s = samvat!;
      // Get raw number for debug
      final rawNum = s['number'] ?? s['tithi_number'] ?? s['tithiNumber'];
      AppLogger.i('CosmicDateTimeCard: Moon phase extraction',
          category: LogCategory.ui,
          data: {
            'RESULT_tithiNumber': tithiNumber,
            'RESULT_paksha': paksha,
            'RESULT_hasMoonPhase': hasMoonPhase,
            // Raw values from data
            'RAW_number': rawNum,
            'RAW_paksha': s['paksha'] ?? s['tithiPaksha'],
            'RAW_name': s['name'] ?? s['tithi'],
            'pakshaRaw_isEmpty': pakshaRaw.isEmpty,
            'allKeys': s.keys.take(10).toList(),
          });
    }
    // Note: Don't set _loggedMoonPhase when samvat is null - we want to log when data arrives

    // Log for debugging - helps identify when wrong data is shown
    final vikramNumber = samvat?['vikram_chaitradi_number'];
    final isValidYear = VedicTimeUtils.isValidVikramYearForToday(vikramNumber);
    if (samvat != null && !isValidYear && vikramNumber != null) {
      AppLogger.w('CosmicDateTimeCard: Possible stale samvat data',
          category: LogCategory.ui,
          data: {
            'vikramYear': vikramNumber,
            'expectedRange': '${now.year + 55}-${now.year + 59}',
            'lunarMonth': samvat?['lunar_month_full_name'],
            'tithi': samvat?['name'],
            'timestamp': samvat?['timestamp'],
          });
    }

    return SizedBox(
      width: double.infinity,
      child: Material(
        color: cardColor,
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () => _showVedicTimeInfo(context, isDark, c),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
              // 1. Vedic Time (Prahar, Ghati, Pala)
              Text(
                vedicTimeDetails,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: c,
                  height: 1.5,
                ),
              ),
              // 2. Full Vedic Date
              if (fullVedicDate != null)
                Text(
                  fullVedicDate,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: c,
                    height: 1.5,
                  ),
                ),
              // 3. Samvat Year
              if (samvatYear != null)
                Text(
                  samvatYear,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: c,
                    height: 1.5,
                  ),
                ),
              // 4. Western Time, Date, Year
              Text(
                '$timeStr, $westernDate',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: c.withValues(alpha: 0.6),
                  height: 1.5,
                ),
              ),
              // 5. Moon Phase Strip
              if (hasMoonPhase) ...[
                const SizedBox(height: 14),
                MoonPhaseStrip(
                  tithiNumber: tithiNumber is int
                      ? tithiNumber
                      : int.tryParse(tithiNumber.toString()) ?? 1,
                  paksha: paksha,
                  isDark: isDark,
                ),
              ],
            ],
          ),
        ),
      ),
      ),
    );
  }

  void _showVedicTimeInfo(BuildContext context, bool isDark, Color c) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => VedicTimeInfoSheet(
        isDark: isDark,
        brown: c,
      ),
    );
  }
}

/// Bottom sheet explaining Vedic time concepts
class VedicTimeInfoSheet extends StatelessWidget {
  final bool isDark;
  final Color brown;

  const VedicTimeInfoSheet({
    super.key,
    required this.isDark,
    required this.brown,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.primaryColor;
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Understanding Vedic Time',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: c,
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoItem(
            title: 'Prahar',
            description:
                'A 3-hour time division. There are 8 Prahars in a full day (sunrise to sunrise), numbered Pratham through Ashtam.',
          ),
          _buildInfoItem(
            title: 'Ghati',
            description:
                'A Ghati equals 24 minutes. One day has 60 Ghatis. Used in astrological calculations and muhurat timing.',
          ),
          _buildInfoItem(
            title: 'Pala',
            description:
                'A Pala is 24 seconds (1/60th of a Ghati). The smallest commonly used Vedic time unit.',
          ),
          _buildInfoItem(
            title: 'Tithi',
            description:
                'The lunar day based on Moon\'s position relative to Sun. Each lunar month has 30 Tithis.',
          ),
          _buildInfoItem(
            title: 'Paksha',
            description:
                'The lunar fortnight. Shukla Paksha is the waxing half (new moon to full moon). Krishna Paksha is the waning half.',
          ),
          _buildInfoItem(
            title: 'Vikram Samvat',
            description:
                'The traditional Hindu calendar year, approximately 57 years ahead of the Gregorian calendar.',
            isLast: true,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Got it',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: c,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem({
    required String title,
    required String description,
    bool isLast = false,
  }) {
    final c = AppTheme.primaryColor;
    
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: c,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: c.withValues(alpha: 0.7),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// Extract tithi number from panchang data
/// Tries multiple field names and parses from tithi name if needed
/// Returns a value 1-15 (normalized for both pakshas)
int? _extractTithiNumber(Map<String, dynamic>? samvat) {
  if (samvat == null) return null;
  
  // Try direct number fields first (handles both global and insight panchang)
  // Global panchang: 'number', 'tithi_number'
  // Insight panchang: 'tithiNumber'
  final directNumber = samvat['number'] ?? 
                       samvat['tithi_number'] ?? 
                       samvat['tithiNumber'];
  if (directNumber != null) {
    int? rawNumber;
    if (directNumber is int) {
      rawNumber = directNumber;
    } else {
      rawNumber = int.tryParse(directNumber.toString());
    }
    
    if (rawNumber != null) {
      // Some APIs return continuous 1-30 numbering
      // Shukla: 1-15, Krishna: 16-30
      // Normalize to 1-15 for both pakshas
      if (rawNumber > 15 && rawNumber <= 30) {
        return rawNumber - 15;
      }
      return rawNumber;
    }
  }
  
  // Try to extract from tithi name
  // Global panchang: 'name'
  // Insight panchang: 'tithi'
  final tithiName = (samvat['name'] ?? samvat['tithi'] ?? '').toString().toLowerCase();
  if (tithiName.isEmpty) return null;
  
  // Map of tithi names to numbers
  const tithiNames = {
    'pratipada': 1, 'prathama': 1, 'padyami': 1, 'pratham': 1,
    'dwitiya': 2, 'vidiya': 2, 'dwitia': 2, 'dvitiya': 2,
    'tritiya': 3, 'tadiya': 3,
    'chaturthi': 4, 'chaviti': 4, 'chaturti': 4,
    'panchami': 5, 'panchmi': 5,
    'shashthi': 6, 'shashti': 6, 'shasti': 6,
    'saptami': 7, 'saptmi': 7,
    'ashtami': 8, 'ashtmi': 8, 'astami': 8,
    'navami': 9, 'navmi': 9,
    'dashami': 10, 'dashmi': 10, 'dasami': 10,
    'ekadashi': 11, 'ekadasi': 11,
    'dwadashi': 12, 'dwadasi': 12, 'dvadashi': 12,
    'trayodashi': 13, 'trayodasi': 13,
    'chaturdashi': 14, 'chaturdasi': 14,
    'purnima': 15, 'poornima': 15, 'pournami': 15,
    'amavasya': 15, 'amavas': 15, // New moon is also 15th tithi
  };
  
  for (final entry in tithiNames.entries) {
    if (tithiName.contains(entry.key)) {
      return entry.value;
    }
  }
  
  return null;
}

/// Extract paksha from panchang data
String _extractPaksha(Map<String, dynamic>? samvat) {
  if (samvat == null) return '';
  
  // Try direct paksha fields (handles both global and insight panchang)
  // Global panchang: 'paksha'
  // Insight panchang: 'tithiPaksha'
  final paksha = (samvat['paksha'] ?? samvat['tithiPaksha'] ?? '').toString().toLowerCase();
  
  // Check if paksha contains 'shukla' or 'krishna' (handles "Shukla Paksha", "shukla", etc.)
  if (paksha.contains('shukla') || paksha.contains('sukla')) {
    return 'shukla';
  }
  if (paksha.contains('krishna') || paksha.contains('krsna') || paksha.contains('krishan')) {
    return 'krishna';
  }
  
  // Try to infer from tithi name
  // Global panchang: 'name'
  // Insight panchang: 'tithi'
  final name = (samvat['name'] ?? samvat['tithi'] ?? '').toString().toLowerCase();
  final combined = '$paksha $name';
  
  if (combined.contains('shukla') || combined.contains('sukla') || combined.contains('waxing')) {
    return 'shukla';
  }
  if (combined.contains('krishna') || combined.contains('krsna') || combined.contains('waning')) {
    return 'krishna';
  }
  
  // If name contains purnima, it's end of shukla paksha
  if (name.contains('purnima') || name.contains('poornima')) {
    return 'shukla';
  }
  // If name contains amavasya, it's end of krishna paksha
  if (name.contains('amavasya') || name.contains('amavas')) {
    return 'krishna';
  }
  
  // IMPORTANT: Check if tithi number is 16-30 (continuous numbering = Krishna paksha)
  final rawNumber = samvat['number'] ?? 
                    samvat['tithi_number'] ?? 
                    samvat['tithiNumber'];
  if (rawNumber != null) {
    int? num;
    if (rawNumber is int) {
      num = rawNumber;
    } else {
      num = int.tryParse(rawNumber.toString());
    }
    if (num != null && num > 15 && num <= 30) {
      return 'krishna'; // Continuous numbering: 16-30 = Krishna paksha
    }
    if (num != null && num >= 1 && num <= 15) {
      // We have a valid tithi number 1-15, default to shukla if paksha unknown
      return 'shukla';
    }
  }
  
  return '';
}
