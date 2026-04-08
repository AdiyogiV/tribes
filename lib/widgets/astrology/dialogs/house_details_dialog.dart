import 'package:flutter/material.dart';
import 'package:aurogram/utils/theme/app_dimensions.dart';

/// Data class for house information
class HouseInfo {
  final int houseNumber;
  final String zodiacSign;
  final String signLord;
  final List<String> planets;
  final String? interpretation;

  const HouseInfo({
    required this.houseNumber,
    required this.zodiacSign,
    required this.signLord,
    required this.planets,
    this.interpretation,
  });
}

/// Simple dialog to display house details
class HouseDetailsDialog extends StatelessWidget {
  final HouseInfo info;
  final bool isDark;

  const HouseDetailsDialog({
    super.key,
    required this.info,
    required this.isDark,
  });

  static void show(BuildContext context, HouseInfo info, bool isDark) {
    showDialog(
      context: context,
      builder: (_) => HouseDetailsDialog(info: info, isDark: isDark),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = _houseColor(info.houseNumber);
    final bg = isDark ? Theme.of(context).colorScheme.surface : Colors.white;

    return Dialog(
      backgroundColor: bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusXl)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingXl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  _badge(color),
                  const SizedBox(width: AppDimensions.spacingMd),
                  Expanded(child: _title(color)),
                  _closeButton(context),
                ],
              ),
              const SizedBox(height: AppDimensions.spacingLg),

              // Interpretation
              _interpretationCard(color),

              // Planets
              if (info.planets.isNotEmpty) ...[
                const SizedBox(height: AppDimensions.spacingMd),
                _planetChips(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingMd, vertical: AppDimensions.paddingSm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMdSm),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _ordinal(info.houseNumber),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: color,
              height: 1,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingXxs),
          Text(
            'House',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color.withValues(alpha: 0.8),
              height: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _title(Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _houseName(info.houseNumber),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        Text(
          '${info.zodiacSign} • ${info.signLord}',
          style: TextStyle(
              fontSize: 12, color: color, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  String _ordinal(int n) {
    if (n >= 11 && n <= 13) return '${n}th';
    switch (n % 10) {
      case 1:
        return '${n}st';
      case 2:
        return '${n}nd';
      case 3:
        return '${n}rd';
      default:
        return '${n}th';
    }
  }

  Widget _closeButton(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Icon(
        Icons.close,
        size: 20,
        color: isDark ? Colors.white54 : Colors.black38,
      ),
    );
  }

  Widget _interpretationCard(Color color) {
    final text = info.interpretation ??
        'Sync your birth chart to unlock personalized insights.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.paddingMdLg),
      decoration: BoxDecoration(
        color:
            isDark ? Colors.white.withValues(alpha: 0.05) : color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          height: 1.5,
          color: isDark ? Colors.white.withValues(alpha: 0.85) : Colors.black87,
        ),
      ),
    );
  }

  Widget _planetChips() {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: info.planets.map((p) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.amber.withValues(alpha: 0.15)
                : Colors.orange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          ),
          child: Text(
            '${_planetSymbol(p)} $p',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color:
                  isDark ? Colors.amber.shade300 : Colors.deepOrange.shade700,
            ),
          ),
        );
      }).toList(),
    );
  }

  Color _houseColor(int h) {
    if ([1, 4, 7, 10].contains(h)) return Colors.amber.shade700;
    if ([5, 9].contains(h)) return Colors.green.shade600;
    if ([6, 8, 12].contains(h)) return Colors.red.shade400;
    if ([3, 11].contains(h)) return Colors.blue.shade500;
    return Colors.purple.shade400;
  }

  String _houseName(int h) {
    const names = {
      1: 'Self & Identity',
      2: 'Wealth & Values',
      3: 'Courage & Siblings',
      4: 'Home & Mother',
      5: 'Children & Creativity',
      6: 'Health & Service',
      7: 'Marriage & Partnership',
      8: 'Transformation',
      9: 'Fortune & Dharma',
      10: 'Career & Status',
      11: 'Gains & Aspirations',
      12: 'Spirituality & Liberation',
    };
    return names[h] ?? 'House $h';
  }

  String _planetSymbol(String name) {
    final l = name.toLowerCase();
    if (l.contains('sun')) return '☉';
    if (l.contains('moon')) return '☽';
    if (l.contains('mars')) return '♂';
    if (l.contains('mercury')) return '☿';
    if (l.contains('jupiter')) return '♃';
    if (l.contains('venus')) return '♀';
    if (l.contains('saturn')) return '♄';
    if (l.contains('rahu')) return '☊';
    if (l.contains('ketu')) return '☋';
    return '•';
  }
}

/// Helpers for house calculations
class HouseSignifications {
  static String getSignForHouse(int houseNumber, int lagnaSignIndex) {
    const signs = [
      'Aries',
      'Taurus',
      'Gemini',
      'Cancer',
      'Leo',
      'Virgo',
      'Libra',
      'Scorpio',
      'Sagittarius',
      'Capricorn',
      'Aquarius',
      'Pisces'
    ];
    return signs[(lagnaSignIndex + houseNumber - 1) % 12];
  }

  static String getSignLord(String sign) {
    const lords = {
      'Aries': 'Mars',
      'Taurus': 'Venus',
      'Gemini': 'Mercury',
      'Cancer': 'Moon',
      'Leo': 'Sun',
      'Virgo': 'Mercury',
      'Libra': 'Venus',
      'Scorpio': 'Mars',
      'Sagittarius': 'Jupiter',
      'Capricorn': 'Saturn',
      'Aquarius': 'Saturn',
      'Pisces': 'Jupiter',
    };
    return lords[sign] ?? 'Unknown';
  }
}
