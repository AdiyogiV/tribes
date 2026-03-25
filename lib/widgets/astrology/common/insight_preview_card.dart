import 'package:flutter/material.dart';
import 'package:aurogram/models/daily_insight.dart';
import 'package:aurogram/services/astrology_service.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/utils/astrology/astrology_formatters.dart';
import 'package:aurogram/pages/astrology/daily_insight_page.dart';

/// Compact insight preview card shown on the astrology details page
/// Taps through to the full daily insight page
class InsightPreviewCard extends StatelessWidget {
  final String uid;
  final AstrologyService? astrologyService;

  const InsightPreviewCard({
    super.key,
    required this.uid,
    this.astrologyService,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final brown = AppTheme.astroBrown(isDark);
    final cardColor = isDark ? Theme.of(context).colorScheme.surface : Colors.white;
    final service = astrologyService ?? AstrologyService();

    return Material(
      color: cardColor,
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => DailyInsightPage(uid: uid),
            ),
          );
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Insights',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: brown,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          AstrologyFormatters.formatTodayDate(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: brown.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'View All →',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: brown.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              StreamBuilder<DailyInsight?>(
                stream: service.streamTodayInsight(uid),
                builder: (context, snapshot) {
                  final insight = snapshot.data;
                  final isLoading = snapshot.connectionState == ConnectionState.waiting;

                  if (isLoading) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        'Loading your personalized insight...',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: brown.withValues(alpha: 0.5),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    );
                  } else if (insight != null && insight.message.isNotEmpty) {
                    return Text(
                      insight.message,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: brown.withValues(alpha: 0.85),
                        height: 1.5,
                      ),
                    );
                  } else {
                    return Text(
                      'Tap to generate your personalized insight based on your birth chart.',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: brown.withValues(alpha: 0.6),
                        height: 1.5,
                        fontStyle: FontStyle.italic,
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
