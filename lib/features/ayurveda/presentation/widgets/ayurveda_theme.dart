import 'package:flutter/material.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Dosha Colors (consistent across Ayurveda UI)
// ─────────────────────────────────────────────────────────────────────────────

const Color vataColor = Color(0xFF7C9CBF); // Cool blue
const Color pittaColor = Color(0xFFE67E22); // Warm orange
const Color kaphaColor = Color(0xFF27AE60); // Earth green

/// Returns the color associated with a dosha name
Color getDoshaColor(String dosha) {
  switch (dosha.toLowerCase()) {
    case 'vata':
      return vataColor;
    case 'pitta':
      return pittaColor;
    case 'kapha':
      return kaphaColor;
    default:
      return AppTheme.primaryColor;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Agni (Digestive Fire) Information
// ─────────────────────────────────────────────────────────────────────────────

const Map<String, Map<String, String>> agniInfo = {
  'sama': {
    'name': 'Sama Agni (Balanced)',
    'description': 'Optimal digestion - regular appetite, efficient processing',
  },
  'vishama': {
    'name': 'Vishama Agni (Irregular)',
    'description': 'Variable appetite, tendency toward gas and bloating',
  },
  'tikshna': {
    'name': 'Tikshna Agni (Sharp)',
    'description': 'Strong hunger, fast metabolism, acidity tendency',
  },
  'manda': {
    'name': 'Manda Agni (Slow)',
    'description': 'Low appetite, slow digestion, heaviness after meals',
  },
};

// ─────────────────────────────────────────────────────────────────────────────
// Prakriti Type Descriptions
// ─────────────────────────────────────────────────────────────────────────────

String getPrakritiDescription(String type) {
  switch (type.toLowerCase()) {
    case 'vata':
      return 'Air & Space • Creative, quick-thinking, energetic';
    case 'pitta':
      return 'Fire & Water • Focused, driven, sharp intellect';
    case 'kapha':
      return 'Earth & Water • Calm, steady, nurturing';
    case 'vata-pitta':
    case 'pitta-vata':
      return 'Air, Fire & Water • Dynamic and intellectually driven';
    case 'vata-kapha':
    case 'kapha-vata':
      return 'Air, Space & Earth • Creative yet grounded';
    case 'pitta-kapha':
    case 'kapha-pitta':
      return 'Fire, Water & Earth • Determined and stable';
    case 'tridoshic':
    case 'sama':
      return 'Balanced Constitution • Rare equilibrium of all three';
    default:
      return 'Unique blend of the three doshas';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Utility Functions
// ─────────────────────────────────────────────────────────────────────────────

/// Capitalize first letter of a string
String capitalize(String text) {
  if (text.isEmpty) return text;
  return text[0].toUpperCase() + text.substring(1).toLowerCase();
}

/// Format relative time for last check-in
String formatLastCheckIn(DateTime date) {
  final now = DateTime.now();
  final diff = now.difference(date);

  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${date.day}/${date.month}';
}

// ─────────────────────────────────────────────────────────────────────────────
// AyurvedaCardContainer - Reusable card wrapper
// ─────────────────────────────────────────────────────────────────────────────

/// Card container widget - aligned with astrology card style
class AyurvedaCardContainer extends StatelessWidget {
  final Widget child;
  final bool isDark;

  const AyurvedaCardContainer({
    super.key,
    required this.child,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final Color cardColor =
        isDark ? Theme.of(context).colorScheme.surface : Colors.white;

    return Material(
      color: cardColor,
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.paddingLg),
        child: child,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DoshaBar - Horizontal progress bar for dosha percentage
// ─────────────────────────────────────────────────────────────────────────────

class DoshaBar extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final bool isDark;

  const DoshaBar({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 50,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
        ),
        const SizedBox(width: AppDimensions.spacingSm),
        Expanded(
          child: Container(
            height: 8,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: value / 100,
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: AppDimensions.spacingSm),
        SizedBox(
          width: 32,
          child: Text(
            '$value%',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DoshaComparisonBar - Shows current (vikriti) vs baseline (prakriti)
// ─────────────────────────────────────────────────────────────────────────────

class DoshaComparisonBar extends StatelessWidget {
  final String label;
  final int baseline; // Prakriti value
  final int current; // Vikriti value
  final Color color;
  final Color primaryColor;
  final bool compact; // For profile card - smaller, no shift indicator

  const DoshaComparisonBar({
    super.key,
    required this.label,
    required this.baseline,
    required this.current,
    required this.color,
    required this.primaryColor,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final shift = current - baseline;
    final hasShift = shift.abs() > 5;
    final isIncreased = shift > 5;
    final isDecreased = shift < -5;

    const labelWidth = 50.0;
    final barHeight = compact ? 5.0 : 8.0;
    final valueWidth = compact ? 44.0 : 50.0;

    // Bar color based on direction of change
    // Increased (aggravated): amber tint, Decreased: green tint, Normal: dosha color
    final barColor = isIncreased
        ? Color.lerp(color, Colors.amber.shade600, 0.4)!
        : isDecreased
            ? Color.lerp(color, Colors.green, 0.3)!
            : color;

    return Row(
      children: [
        SizedBox(
          width: labelWidth,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: primaryColor.withValues(alpha: 0.7),
            ),
          ),
        ),
        const SizedBox(width: AppDimensions.spacingSm),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final totalWidth = constraints.maxWidth;
              final baselinePosition = (baseline / 100) * totalWidth;

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  // Background track
                  Container(
                    height: barHeight,
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(barHeight / 2),
                    ),
                  ),
                  // Current value bar (solid)
                  FractionallySizedBox(
                    widthFactor: current / 100,
                    child: Container(
                      height: barHeight,
                      decoration: BoxDecoration(
                        color: barColor,
                        borderRadius: BorderRadius.circular(barHeight / 2),
                      ),
                    ),
                  ),
                  // Baseline marker (thin vertical line showing original prakriti)
                  if (hasShift)
                    Positioned(
                      left: baselinePosition - 1,
                      top: -1,
                      child: Container(
                        width: 2,
                        height: barHeight + 2,
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        const SizedBox(width: AppDimensions.spacingSm),
        // Value with optional shift indicator
        SizedBox(
          width: hasShift ? valueWidth + 20 : valueWidth,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                compact ? '$current' : '$current%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color:
                      compact ? primaryColor.withValues(alpha: 0.5) : barColor,
                ),
              ),
              if (hasShift) ...[
                const SizedBox(width: AppDimensions.spacingXxs),
                Flexible(
                  child: Text(
                    shift > 0 ? '+$shift' : '$shift',
                    style: TextStyle(
                      fontSize: compact ? 9 : 10,
                      fontWeight: FontWeight.w600,
                      color: shift > 0 ? Colors.amber.shade700 : Colors.green,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
