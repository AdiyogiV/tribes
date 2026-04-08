import 'package:flutter/material.dart';
import 'package:aurogram/features/astrology/data/utils/astrology_formatters.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/features/astrology/presentation/widgets/cards/moon_phase_strip.dart';
import 'samvat_helpers.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

/// Vikram / Saka Samvat card showing full lunisolar date info
class SamvatCard extends StatelessWidget {
  final String label;
  final dynamic yearNumber;
  final dynamic yearName;
  final Map<String, dynamic>? samvat;
  final bool isDark;
  final double? userLat;
  final double? userLng;
  final String? birthTime;
  final DateTime? birthDate;
  final String? nakshatra;
  final String? yoga;
  final String? karana;

  const SamvatCard({
    super.key,
    required this.label,
    required this.yearNumber,
    required this.yearName,
    required this.samvat,
    required this.isDark,
    this.userLat,
    this.userLng,
    this.birthTime,
    this.birthDate,
    this.nakshatra,
    this.yoga,
    this.karana,
  });

  /// Vara (weekday) with planetary lord (Sanskrit romanized)
  /// Weekday: 1=Monday, 7=Sunday (Dart DateTime.weekday format)
  static const _varaNames = {
    1: 'Somvaar (Monday - Moon)',
    2: 'Mangalvaar (Tuesday - Mars)',
    3: 'Budhvaar (Wednesday - Mercury)',
    4: 'Guruvaar (Thursday - Jupiter)',
    5: 'Shukravaar (Friday - Venus)',
    6: 'Shanivaar (Saturday - Saturn)',
    7: 'Ravivaar (Sunday - Sun)',
  };

  @override
  Widget build(BuildContext context) {
    final lunarMonthName = samvat?['lunar_month_full_name']?.toString() ??
        samvat?['lunar_month_name']?.toString();
    final lunarMonthNumber = samvat?['lunar_month_number'];
    final tithiName =
        samvat?['name']?.toString() ?? samvat?['tithi']?.toString();

    // Use extraction functions to handle different data formats
    final tithiNumber = extractTithiNumber(samvat);
    final paksha = extractPaksha(samvat);

    final pakshaNameEng = paksha == 'shukla'
        ? 'Waxing Moon'
        : paksha == 'krishna'
            ? 'Waning Moon'
            : null;
    final pakshaSanskrit = paksha == 'shukla'
        ? 'Shukla'
        : paksha == 'krishna'
            ? 'Krishna'
            : paksha;
    final pakshaNumber = paksha == 'shukla'
        ? 1
        : paksha == 'krishna'
            ? 2
            : null;

    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingMd),
          // Numerical date
          if (lunarMonthNumber != null &&
              tithiNumber != null &&
              yearNumber != null)
            Row(
              children: [
                Text(
                  '$lunarMonthNumber${pakshaNumber != null ? '/$pakshaNumber' : ''}/$tithiNumber/$yearNumber',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryColor,
                    height: 1.2,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: AppDimensions.spacingMdSm),
                Flexible(
                  child: Text(
                    pakshaNumber != null
                        ? '(Masa/Paksha/Tithi/Varsha)'
                        : '(Masa/Tithi/Varsha)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.primaryColor.withValues(alpha: 0.5),
                      height: 1.3,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          const SizedBox(height: AppDimensions.spacingMd),
          // Month
          if (lunarMonthName != null)
            _buildDateComponent(
              'Masa (Month)',
              '$lunarMonthName${lunarMonthNumber != null ? ' ($lunarMonthNumber)' : ''}',
            ),
          // Paksha
          if (pakshaSanskrit != null && pakshaNameEng != null) ...[
            const SizedBox(height: AppDimensions.spacingSm),
            _buildDateComponent(
              'Paksha (Fortnight)',
              '$pakshaSanskrit \u2022 $pakshaNameEng',
            ),
          ],
          // Tithi
          if (tithiName != null) ...[
            const SizedBox(height: AppDimensions.spacingSm),
            _buildDateComponent(
              'Tithi (Lunar Day)',
              '$tithiName${tithiNumber != null ? ' ($tithiNumber of 15)' : ''}',
            ),
          ],
          // === PANCHANG ELEMENTS ===
          // Nakshatra (Lunar Mansion)
          if (nakshatra != null && nakshatra!.isNotEmpty) ...[
            const SizedBox(height: AppDimensions.spacingSm),
            _buildDateComponent(
              'Nakshatra (Star)',
              nakshatra!,
            ),
          ],
          // Yoga (Sun-Moon combination)
          if (yoga != null && yoga!.isNotEmpty) ...[
            const SizedBox(height: AppDimensions.spacingSm),
            _buildDateComponent(
              'Yoga (Combination)',
              yoga!,
            ),
          ],
          // Karana (Half-tithi)
          if (karana != null && karana!.isNotEmpty) ...[
            const SizedBox(height: AppDimensions.spacingSm),
            _buildDateComponent(
              'Karana (Half-Day)',
              karana!,
            ),
          ],
          // Vara (Weekday with planetary lord)
          if (birthDate != null) ...[
            const SizedBox(height: AppDimensions.spacingSm),
            _buildDateComponent(
              'Vara (Weekday)',
              _varaNames[birthDate!.weekday] ?? 'Unknown',
            ),
          ],
          // Year cycle
          if (yearName != null && yearName.toString().isNotEmpty) ...[
            const SizedBox(height: AppDimensions.spacingSm),
            _buildDateComponent(
              'Varsha (Year)',
              '${yearName.toString()} \u2022 $yearNumber',
            ),
          ],
          // Vedic Time - Prahar & Ghati/Pala
          if (birthTime != null && birthTime!.isNotEmpty) ...[
            const SizedBox(height: AppDimensions.spacingSm),
            Builder(builder: (context) {
              final vedicTime = AstrologyFormatters.calculatePrahar(birthTime);
              if (vedicTime == null) return const SizedBox.shrink();

              return Column(
                children: [
                  _buildDateComponent(
                    'Prahar (Watch)',
                    '${vedicTime['praharName']} \u2022 ${vedicTime['prahar']} of 8',
                  ),
                  const SizedBox(height: AppDimensions.spacingSm),
                  _buildDateComponent(
                    'Samay (Time)',
                    '${vedicTime['ghatis']} Ghati ${vedicTime['palas']} Pala',
                  ),
                ],
              );
            }),
          ],
          // Reference from Ujjain (Hindu Prime Meridian)
          if (userLat != null && userLng != null) ...[
            const SizedBox(height: AppDimensions.spacingSm),
            _buildDateComponent(
              'Akshansha (Latitude)',
              AstrologyFormatters.formatLatitudeFromUjjain(userLat!),
            ),
            const SizedBox(height: AppDimensions.spacingSm),
            _buildDateComponent(
              'Desantara (Longitude)',
              AstrologyFormatters.formatLongitudeFromUjjain(userLng!),
            ),
          ],
          // Moon phase visualization at bottom
          if (tithiNumber != null && paksha != null) ...[
            const SizedBox(height: AppDimensions.spacingMd),
            MoonPhaseStrip(
              tithiNumber: tithiNumber,
              paksha: paksha,
              isDark: isDark,
            ),
          ],
          const SizedBox(height: AppDimensions.spacingMd),
          // Epoch note
          Text(
            label == 'Vikram Samvat'
                ? 'Lunisolar calendar \u2022 Epoch: King Vikramaditya (57 BCE)'
                : 'Lunisolar calendar \u2022 Epoch: Shalivahana (78 CE)',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              fontStyle: FontStyle.italic,
              color: AppTheme.primaryColor.withValues(alpha: 0.5),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateComponent(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryColor.withValues(alpha: 0.6),
              height: 1.3,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryColor,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}
