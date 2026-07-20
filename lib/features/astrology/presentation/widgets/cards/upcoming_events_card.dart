import 'package:flutter/material.dart';
import 'package:aurogram/features/astrology/domain/sky_positions_service.dart';
import 'package:aurogram/core/theme/app_theme.dart';

/// Card showing upcoming planetary events (sign changes, retrogrades).
///
/// Styled to match the editorial design language of the Today's Balance and
/// Current Sky cards: a flat, edge-to-edge surface (night-black / paper-white),
/// left-aligned content, a two-tone Georgia-italic 32 header, and spaced
/// uppercase micro-labels for sections.
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
    final c = AppTheme.primaryColor;

    // Editorial palette — identical tokens to BalanceCard / SkyChartCard.
    final bg = isDark ? const Color(0xFF000000) : Colors.white;
    final fgMain = isDark ? Colors.white : const Color(0xFF1A1A1C);
    final fgMuted = isDark ? Colors.white54 : Colors.black54;
    final fgFaint = isDark ? Colors.white24 : Colors.black26;

    if (events.isEmpty) return const SizedBox.shrink();

    final majorPlanets = ['Sun', 'Mars', 'Mercury', 'Jupiter', 'Venus', 'Saturn'];
    final filteredEvents = events
        .where((e) => majorPlanets.contains(e.planet))
        .take(maxEvents)
        .toList();

    if (filteredEvents.isEmpty) return const SizedBox.shrink();

    final transits =
        filteredEvents.where((e) => e.type == 'sign_ingress').toList();
    final retrogrades =
        filteredEvents.where((e) => e.type.contains('retrograde')).toList();

    return Container(
      width: double.infinity,
      color: bg,
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Chic editorial header (matches "Current Sky." two-tone style)
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: 'Upcoming ',
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontStyle: FontStyle.italic,
                    color: c,
                    fontSize: 32,
                    letterSpacing: -1.2,
                  ),
                ),
                TextSpan(
                  text: 'Transits.',
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontStyle: FontStyle.italic,
                    color: fgMain,
                    fontSize: 32,
                    fontWeight: FontWeight.w300,
                    letterSpacing: -1.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Sign changes & retrogrades ahead.',
            style: TextStyle(
              color: fgMuted,
              fontSize: 13,
              height: 1.4,
              fontFamily: 'Georgia',
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 24),

          // Sign transits
          if (transits.isNotEmpty)
            ...transits.take(5).toList().asMap().entries.map((entry) {
              final isLast =
                  entry.key == transits.take(5).length - 1 && retrogrades.isEmpty;
              return _buildEventRow(
                  entry.value, c, fgMain, fgMuted, fgFaint,
                  isLast: isLast);
            }),

          // Retrogrades
          if (retrogrades.isNotEmpty) ...[
            if (transits.isNotEmpty) const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                'R E T R O G R A D E',
                style: TextStyle(
                  color: fgMuted,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2.0,
                ),
              ),
            ),
            ...retrogrades.take(3).toList().asMap().entries.map((entry) {
              final isLast = entry.key == retrogrades.take(3).length - 1;
              return _buildEventRow(
                  entry.value, c, fgMain, fgMuted, fgFaint,
                  isLast: isLast);
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildEventRow(
    UpcomingEvent event,
    Color c,
    Color fgMain,
    Color fgMuted,
    Color fgFaint, {
    bool isLast = false,
  }) {
    final action = _getEventAction(event);
    final isRetrograde = event.type.contains('retrograde');
    final actionColor = isRetrograde
        ? (event.type == 'retrograde_end'
            ? Colors.green.shade400
            : Colors.orange.shade400)
        : fgMuted;

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Planet + action (left, editorial)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.planet,
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontStyle: FontStyle.italic,
                    fontSize: 16,
                    color: fgMain,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  action,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: actionColor,
                  ),
                ),
              ],
            ),
          ),

          // Date (right, spaced uppercase micro-label)
          Text(
            event.formattedDate.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
              color: fgFaint,
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
