import 'package:aurogram/core/theme/app_dimensions.dart';
import 'package:flutter/material.dart';
import 'package:aurogram/core/theme/app_theme.dart';

/// Horizontal strip showing lunar cycle for NON-PAKSHA calendars (Islamic, Chinese, Jewish)
/// Shows continuous 29/30-day month cycle starting from new moon
class LunarMonthStrip extends StatefulWidget {
  final int dayOfMonth;      // 1-30
  final int daysInMonth;     // 29 or 30
  final bool isDark;
  final String? calendarType; // 'islamic', 'chinese', 'jewish' for custom labels

  const LunarMonthStrip({
    super.key,
    required this.dayOfMonth,
    required this.daysInMonth,
    required this.isDark,
    this.calendarType,
  });

  @override
  State<LunarMonthStrip> createState() => _LunarMonthStripState();
}

class _LunarMonthStripState extends State<LunarMonthStrip> {
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollToCurrentDay();
  }

  void _scrollToCurrentDay() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        const itemWidth = 33.0;
        const separatorWidth = 3.0;
        const itemWithSeparator = itemWidth + separatorWidth;

        final viewportWidth = _scrollController.position.viewportDimension;
        final itemPosition = (widget.dayOfMonth - 1) * itemWithSeparator;
        final scrollPosition = itemPosition - (viewportWidth / 2) + (itemWidth / 2);

        _scrollController.animateTo(
          scrollPosition.clamp(0.0, _scrollController.position.maxScrollExtent),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _getMoonIcon(int day, int totalDays) {
    // Calculate position in lunar cycle (0.0 to 1.0)
    final position = (day - 1) / totalDays;
    
    if (day == 1) return '🌑';                          // New Moon
    if (position <= 0.12) return '🌒';                  // Waxing Crescent
    if (position <= 0.25) return '🌓';                  // First Quarter
    if (position <= 0.45) return '🌔';                  // Waxing Gibbous
    if (position <= 0.55) return '🌕';                  // Full Moon (~day 15)
    if (position <= 0.70) return '🌖';                  // Waning Gibbous
    if (position <= 0.80) return '🌗';                  // Last Quarter
    return '🌘';                                         // Waning Crescent
  }

  String _getLabel() {
    switch (widget.calendarType) {
      case 'islamic':
        return 'Lunar Month (Shahr)';
      case 'chinese':
        return 'Lunar Month (Yue)';
      case 'jewish':
        return 'Lunar Month (Chodesh)';
      default:
        return 'Lunar Month';
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalDays = widget.daysInMonth;
    final currentDay = widget.dayOfMonth;
    
    // Determine special days
    final fullMoonDay = (totalDays / 2).round(); // ~14 or 15

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _getLabel(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppTheme.primaryColor.withValues(alpha: 0.65),
            height: 1.3,
          ),
        ),
        const SizedBox(height: AppDimensions.spacingSm),
        SizedBox(
          height: 60,
          child: ListView.separated(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.zero,
            itemCount: totalDays,
            separatorBuilder: (_, __) => const SizedBox(width: 3),
            itemBuilder: (context, index) {
              final day = index + 1;
              final isCurrent = day == currentDay;
              final isNewMoon = day == 1;
              final isFullMoon = day == fullMoonDay;

              return Container(
                constraints: const BoxConstraints(minWidth: 32, maxWidth: 34),
                padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
                decoration: BoxDecoration(
                  color: isCurrent
                      ? AppTheme.primaryColor.withValues(alpha: 0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSmMd),
                  border: isCurrent
                      ? Border.all(color: AppTheme.primaryColor, width: 1.5)
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _getMoonIcon(day, totalDays),
                      style: const TextStyle(fontSize: 24, height: 1.0),
                    ),
                    const SizedBox(height: AppDimensions.spacingXs),
                    if (isNewMoon || isFullMoon)
                      Text(
                        isNewMoon ? 'NM' : 'FM',
                        style: TextStyle(
                          fontSize: 7.5,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primaryColor.withValues(alpha: 0.8),
                          height: 1.0,
                          letterSpacing: 0.3,
                        ),
                      )
                    else
                      Text(
                        '$day',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                          color: isCurrent
                              ? AppTheme.primaryColor
                              : AppTheme.primaryColor.withValues(alpha: 0.5),
                          height: 1.0,
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Horizontal strip showing lunar cycle with moon phase emojis (PAKSHA-based)
/// For Vedic, Jain, Buddhist calendars that use Shukla/Krishna paksha system
class MoonPhaseStrip extends StatefulWidget {
  final int tithiNumber;
  final String paksha; // 'shukla' or 'krishna'
  final bool isDark;

  const MoonPhaseStrip({
    super.key,
    required this.tithiNumber,
    required this.paksha,
    required this.isDark,
  });

  @override
  State<MoonPhaseStrip> createState() => _MoonPhaseStripState();
}

class _MoonPhaseStripState extends State<MoonPhaseStrip> {
  late ScrollController _scrollController;
  int? _currentIndex;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _findCurrentPhaseAndScroll();
  }

  void _findCurrentPhaseAndScroll() {
    final phases = _buildPhases();
    for (int i = 0; i < phases.length; i++) {
      if (phases[i]['isCurrent'] == true) {
        _currentIndex = i;
        break;
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_currentIndex != null && _scrollController.hasClients) {
        _scrollToCenter(_currentIndex!);
      }
    });
  }

  void _scrollToCenter(int index) {
    if (!_scrollController.hasClients) return;

    const itemWidth = 48.0;
    const separatorWidth = 5.0;
    const itemWithSeparator = itemWidth + separatorWidth;

    final viewportWidth = _scrollController.position.viewportDimension;
    final itemPosition = index * itemWithSeparator;
    final scrollPosition = itemPosition - (viewportWidth / 2) + (itemWidth / 2);

    _scrollController.animateTo(
      scrollPosition.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  List<Map<String, dynamic>> _buildPhases() {
    final day = widget.tithiNumber;
    final currentPaksha = widget.paksha == 'shukla' ? 1 : 2;
    final phases = <Map<String, dynamic>>[];

    // Shukla Paksha (Waxing: 1-15)
    for (int i = 1; i <= 15; i++) {
      String icon;
      if (i == 1) {
        icon = '🌑';
      } else if (i <= 3) {
        icon = '🌒';
      } else if (i <= 7) {
        icon = '🌓';
      } else if (i <= 11) {
        icon = '🌔';
      } else {
        icon = '🌕';
      }
      phases.add({
        'tithi': i,
        'paksha': 1,
        'icon': icon,
        'label': '$i/1',
        'isCurrent': i == day && currentPaksha == 1,
      });
    }

    // Krishna Paksha (Waning: 1-15)
    for (int i = 1; i <= 15; i++) {
      String icon;
      if (i == 1) {
        icon = '🌕';
      } else if (i <= 3) {
        icon = '🌖';
      } else if (i <= 7) {
        icon = '🌗';
      } else if (i <= 11) {
        icon = '🌘';
      } else {
        icon = '🌑';
      }
      phases.add({
        'tithi': i,
        'paksha': 2,
        'icon': icon,
        'label': '$i/2',
        'isCurrent': i == day && currentPaksha == 2,
      });
    }

    return phases;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final phases = _buildPhases();

    return SizedBox(
      height: 92,
      child: ListView.separated(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: phases.length,
        separatorBuilder: (_, __) => const SizedBox(width: 5),
        itemBuilder: (context, index) {
          final phase = phases[index];
          final isCurrent = phase['isCurrent'] as bool;
          final tithi = phase['tithi'] as int;
          final pakshaNum = phase['paksha'] as int;
          final isNewMoon = tithi == 15 && pakshaNum == 2;
          final isFullMoon = tithi == 15 && pakshaNum == 1;

          final moonSize = isCurrent ? 38.0 : 30.0;

          return SizedBox(
            width: 48,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Moon — selected is scaled up, others normal
                AnimatedScale(
                  scale: isCurrent ? 1.0 : 0.82,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  child: Text(
                    phase['icon'] as String,
                    style: TextStyle(fontSize: moonSize, height: 1.0),
                  ),
                ),
                const SizedBox(height: 4),
                // Label
                if (isNewMoon || isFullMoon)
                  Text(
                    isNewMoon ? 'NM' : 'FM',
                    style: TextStyle(
                      fontSize: isCurrent ? 12 : 11,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primaryColor.withValues(alpha: 0.8),
                      height: 1.0,
                      letterSpacing: 0.3,
                    ),
                  )
                else
                  Text(
                    phase['label'] as String,
                    style: TextStyle(
                      fontSize: isCurrent ? 12 : 11,
                      fontWeight:
                          isCurrent ? FontWeight.w700 : FontWeight.w500,
                      color: isCurrent
                          ? AppTheme.primaryColor
                          : AppTheme.primaryColor.withValues(alpha: 0.45),
                      height: 1.0,
                    ),
                  ),
                const SizedBox(height: 5),
                // Selection indicator — small pill dot
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  width: isCurrent ? 16 : 0,
                  height: 3,
                  decoration: BoxDecoration(
                    color: isCurrent
                        ? AppTheme.primaryColor
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}




