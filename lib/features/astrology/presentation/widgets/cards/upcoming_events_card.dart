import 'package:flutter/material.dart';
import 'package:aurogram/features/astrology/domain/sky_positions_service.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

/// Card showing upcoming planetary events (sign changes, retrogrades)
/// Matches astrology details page card styling
class UpcomingEventsCard extends StatelessWidget {
  final Color brown;
  final List<UpcomingEvent> events;
  final int maxEvents;

  const UpcomingEventsCard({
    super.key,
    required this.brown,
    required this.events,
    this.maxEvents = 8,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color cardColor =
        isDark ? Theme.of(context).colorScheme.surface : Colors.white;
    final c = AppTheme.primaryColor;

    if (events.isEmpty) {
      return const SizedBox.shrink();
    }

    // Filter to show only major planets and limit count
    final majorPlanets = ['Sun', 'Mars', 'Mercury', 'Jupiter', 'Venus', 'Saturn'];
    final filteredEvents = events
        .where((e) => majorPlanets.contains(e.planet))
        .take(maxEvents)
        .toList();

    if (filteredEvents.isEmpty) {
      return const SizedBox.shrink();
    }

    // Group events by type for cleaner display
    final transits = filteredEvents.where((e) => e.type == 'sign_ingress').toList();
    final retrogrades = filteredEvents.where((e) => e.type.contains('retrograde')).toList();

    return Material(
      color: cardColor,
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppDimensions.paddingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header - Title Case, matches astrology details page
            Text(
              'Upcoming Transits',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppTheme.holyCowTextSize,
                fontWeight: FontWeight.w700,
                color: c,
              ),
            ),
            const SizedBox(height: AppDimensions.spacingMd),

            // Sign Transits
            if (transits.isNotEmpty) ...[
              ...transits.take(5).toList().asMap().entries.map((entry) {
                final isLast = entry.key == transits.take(5).length - 1 && retrogrades.isEmpty;
                return _buildEventRow(entry.value, c, isDark, isLast: isLast);
              }),
            ],

            // Retrogrades
            if (retrogrades.isNotEmpty) ...[
              if (transits.isNotEmpty) const SizedBox(height: AppDimensions.spacingMd),
              if (transits.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppDimensions.paddingSm),
                  child: Text(
                    'Retrograde Motion',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: AppTheme.holyCowTextSize,
                      fontWeight: FontWeight.w600,
                      color: c.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ...retrogrades.take(3).toList().asMap().entries.map((entry) {
                final isLast = entry.key == retrogrades.take(3).length - 1;
                return _buildEventRow(entry.value, c, isDark, isLast: isLast);
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEventRow(UpcomingEvent event, Color c, bool isDark, {bool isLast = false}) {
    final action = _getEventAction(event);
    final isRetrograde = event.type.contains('retrograde');
    
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Planet name
          SizedBox(
            width: 90,
            child: Text(
              event.planet,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppTheme.holyCowTextSize,
                fontWeight: FontWeight.w700,
                color: c,
              ),
            ),
          ),

          // Action (enters sign / goes retrograde / goes direct)
          Expanded(
            child: Text(
              action,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppTheme.holyCowTextSize,
                fontWeight: FontWeight.w500,
                color: isRetrograde
                    ? (event.type == 'retrograde_end'
                        ? Colors.green.shade600
                        : Colors.orange.shade600)
                    : c.withValues(alpha: 0.7),
              ),
            ),
          ),

          // Date
          Text(
            event.formattedDate,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: AppTheme.holyCowTextSize,
              fontWeight: FontWeight.w600,
              color: c.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  String _getEventAction(UpcomingEvent event) {
    if (event.type == 'sign_ingress') {
      return 'enters ${event.toSign}';
    } else if (event.type == 'retrograde_start') {
      return 'goes retrograde';
    } else if (event.type == 'retrograde_end') {
      return 'goes direct';
    }
    return event.description ?? '';
  }
}
