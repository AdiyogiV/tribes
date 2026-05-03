import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/shared/models/watch_health_data.dart';
import 'package:aurogram/shared/providers/watch_health_provider.dart';
import 'package:aurogram/features/ayurveda/presentation/widgets/ayurveda_theme.dart';
import 'package:aurogram/features/ayurveda/presentation/widgets/watch_health_cards.dart';
import 'package:aurogram/features/ayurveda/presentation/pages/trend_chart_painters.dart';

/// Detail page for Nadi Pariksha (pulse reading / dosha balance).
/// Shows current balance, historical dosha trend, prahar context, and Ayurvedic info.
class NadiDetailPage extends StatelessWidget {
  final WatchHealthData data;

  const NadiDetailPage({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = AppTheme.primaryColor;
    final balance = computeDoshaBalance(data);
    final dominant = data.nadiDosha ?? _dominantFromBalance(balance);

    // Get dosha history from provider
    final provider = context.watch<WatchHealthProvider>();
    final doshaHistory = provider.history
        .map((d) => computeDoshaBalance(d))
        .toList();

    return Scaffold(
      backgroundColor:
          isDark ? Theme.of(context).scaffoldBackgroundColor : const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(CupertinoIcons.back, color: c),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Text(
          'Nadi Pariksha',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Hero: Current dosha ────────────────────────────
            DetailCard(
              isDark: isDark,
              child: Column(
                children: [
                  Text(
                    _nadiGlyph(dominant),
                    style: const TextStyle(fontSize: 40),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${capitalize(dominant)} Nadi',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: getDoshaColor(dominant),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _nadiDescription(dominant),
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Dosha bars
                  _doshaBar('Vata', balance['vata']!, vataColor, isDark),
                  const SizedBox(height: 8),
                  _doshaBar('Pitta', balance['pitta']!, pittaColor, isDark),
                  const SizedBox(height: 8),
                  _doshaBar('Kapha', balance['kapha']!, kaphaColor, isDark),
                ],
              ),
            ),

            // ── Dosha trend chart ──────────────────────────────
            if (doshaHistory.length >= 2) ...[
              const SizedBox(height: 12),
              DetailCard(
                isDark: isDark,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '7-Day Dosha Trend',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 120,
                      child: CustomPaint(
                        size: const Size(double.infinity, 120),
                        painter: _DoshaTrendPainter(
                          data: doshaHistory,
                          gridColor: isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : Colors.black.withValues(alpha: 0.06),
                          isDark: isDark,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Day labels
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(
                        doshaHistory.length.clamp(0, 7),
                        (i) {
                          final daysAgo = doshaHistory.length - 1 - i;
                          final day = DateTime.now().subtract(Duration(days: daysAgo));
                          return Text(
                            shortDayName(day.weekday),
                            style: TextStyle(
                              fontSize: 9,
                              color: isDark ? Colors.white24 : Colors.black26,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Legend
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _legendDot('Vata', vataColor, isDark),
                        const SizedBox(width: 16),
                        _legendDot('Pitta', pittaColor, isDark),
                        const SizedBox(width: 16),
                        _legendDot('Kapha', kaphaColor, isDark),
                      ],
                    ),
                  ],
                ),
              ),
            ],

            // ── Prahar context ─────────────────────────────────
            const SizedBox(height: 12),
            DetailCard(
              isDark: isDark,
              child: _buildPraharContext(isDark, dominant),
            ),

            // ── What is Nadi Pariksha ──────────────────────────
            const SizedBox(height: 12),
            DetailCard(
              isDark: isDark,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'What It Means',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Your Apple Watch approximates traditional pulse diagnosis '
                    'by analyzing HRV patterns, heart rate, temperature, and activity '
                    'to estimate your current dosha balance.',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),

            // ── Ayurvedic view ─────────────────────────────────
            const SizedBox(height: 12),
            DetailCard(
              isDark: isDark,
              accent: const Color(0xFFF5E6D0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('🪷', style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 6),
                      Text(
                        'Ayurvedic View',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white54 : Colors.black45,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Nadi Pariksha reads the pulse at three points on the radial artery. '
                    'Vata pulses like a snake (Sarpa), Pitta jumps like a frog (Manduka), '
                    'and Kapha glides like a swan (Hamsa). Balance shifts with season, '
                    'time of day, and lifestyle.',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ── Prahar (time-of-day dosha) ─────────────────────────────

  Widget _buildPraharContext(bool isDark, String dominant) {
    final hour = DateTime.now().hour;
    final expectedDosha = _praharDosha(hour);
    final inHarmony = dominant.toLowerCase() == expectedDosha.toLowerCase();
    final period = _praharPeriod(hour);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              inHarmony ? '☀' : '🌀',
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                inHarmony ? 'In Harmony' : 'Dosha Shift',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: inHarmony ? kaphaColor : Colors.amber.shade600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          inHarmony
              ? 'Your dominant $dominant energy aligns with the current $period ($expectedDosha time).'
              : 'Your dominant $dominant energy differs from the current $period ($expectedDosha time). '
                'This is normal and may shift naturally.',
          style: TextStyle(
            fontSize: 14,
            height: 1.5,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
      ],
    );
  }

  static String _praharDosha(int hour) {
    if (hour >= 2 && hour < 6) return 'Vata';
    if (hour >= 6 && hour < 10) return 'Kapha';
    if (hour >= 10 && hour < 14) return 'Pitta';
    if (hour >= 14 && hour < 18) return 'Vata';
    if (hour >= 18 && hour < 22) return 'Kapha';
    return 'Pitta'; // 22-2
  }

  static String _praharPeriod(int hour) {
    if (hour >= 5 && hour < 12) return 'morning';
    if (hour >= 12 && hour < 17) return 'afternoon';
    if (hour >= 17 && hour < 21) return 'evening';
    return 'night';
  }

  // ── Helpers ────────────────────────────────────────────────

  Widget _doshaBar(String label, double value, Color color, bool isDark) {
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
        const SizedBox(width: 8),
        Expanded(
          child: Stack(
            children: [
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              FractionallySizedBox(
                widthFactor: (value / 100).clamp(0.0, 1.0),
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 35,
          child: Text(
            '${value.round()}%',
            textAlign: TextAlign.right,
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

  Widget _legendDot(String label, Color color, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white54 : Colors.black54,
          ),
        ),
      ],
    );
  }

  String _dominantFromBalance(Map<String, double> balance) {
    final sorted = balance.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return capitalize(sorted.first.key);
  }

  static String _nadiGlyph(String dosha) {
    switch (dosha.toLowerCase()) {
      case 'vata':
        return '🐍';
      case 'pitta':
        return '🐸';
      case 'kapha':
        return '🦢';
      default:
        return '◉';
    }
  }

  static String _nadiDescription(String dosha) {
    switch (dosha.toLowerCase()) {
      case 'vata':
        return 'Sarpa gati · Snake-like pulse';
      case 'pitta':
        return 'Manduka gati · Frog-like pulse';
      case 'kapha':
        return 'Hamsa gati · Swan-like pulse';
      default:
        return 'Pulse pattern';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DoshaTrendPainter — Multi-line chart for Vata/Pitta/Kapha over time
// ─────────────────────────────────────────────────────────────────────────────

class _DoshaTrendPainter extends CustomPainter {
  final List<Map<String, double>> data;
  final Color gridColor;
  final bool isDark;

  _DoshaTrendPainter({
    required this.data,
    required this.gridColor,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;

    // Grid
    for (int i = 0; i <= 3; i++) {
      final y = (i / 3) * size.height;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        Paint()..color = gridColor,
      );
    }

    // Find max value for scaling (usually ~50-60%)
    double maxVal = 0;
    for (final d in data) {
      for (final v in d.values) {
        maxVal = math.max(maxVal, v);
      }
    }
    maxVal = math.max(maxVal, 50); // minimum scale
    final padding = maxVal * 0.05;

    // Draw each dosha line
    _drawSeries(canvas, size, 'vata', vataColor, maxVal, padding);
    _drawSeries(canvas, size, 'pitta', pittaColor, maxVal, padding);
    _drawSeries(canvas, size, 'kapha', kaphaColor, maxVal, padding);
  }

  void _drawSeries(
    Canvas canvas,
    Size size,
    String key,
    Color color,
    double maxVal,
    double padding,
  ) {
    final points = <Offset>[];
    for (int i = 0; i < data.length; i++) {
      final x = (i / (data.length - 1)) * size.width;
      final value = data[i][key] ?? 33;
      final normalized = (value + padding) / (maxVal + padding * 2);
      final y = size.height - normalized * size.height;
      points.add(Offset(x, y));
    }

    // Line
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Dots
    for (final p in points) {
      canvas.drawCircle(p, 4, Paint()..color = color);
      canvas.drawCircle(
        p,
        2.5,
        Paint()..color = isDark ? const Color(0xFF1E1E1E) : Colors.white,
      );
    }

    // Last value label
    final lastPoint = points.last;
    final lastValue = data.last[key] ?? 33;
    final tp = TextPainter(
      text: TextSpan(
        text: '${lastValue.round()}%',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    // Offset label to avoid overlap
    tp.paint(
      canvas,
      Offset(
        (lastPoint.dx + tp.width + 4 > size.width)
            ? lastPoint.dx - tp.width - 6
            : lastPoint.dx + 6,
        lastPoint.dy - tp.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant _DoshaTrendPainter old) =>
      old.data != data;
}
