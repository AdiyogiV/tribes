import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/shared/models/watch_health_data.dart';
import 'package:aurogram/shared/providers/watch_health_provider.dart';
import 'package:aurogram/features/ayurveda/presentation/widgets/ayurveda_theme.dart';
import 'package:aurogram/features/ayurveda/presentation/widgets/watch_health_cards.dart';
import 'package:aurogram/features/ayurveda/presentation/pages/dosha_trend_painter.dart';
import 'package:aurogram/features/ayurveda/presentation/widgets/nadi_calculation_section.dart';

// ─────────────────────────────────────────────────────────────────────────────
// NadiDetailPage — Pulse reading / Dosha balance drill-down
// ─────────────────────────────────────────────────────────────────────────────

/// Detail page for Nadi Pariksha (pulse reading / dosha balance).
/// Shows current balance, granular timestamped dosha trend, prahar context,
/// and Ayurvedic info.
class NadiDetailPage extends StatefulWidget {
  final WatchHealthData data;

  const NadiDetailPage({super.key, required this.data});

  @override
  State<NadiDetailPage> createState() => _NadiDetailPageState();
}

class _NadiDetailPageState extends State<NadiDetailPage> {
  int _rangeIndex = 2;
  static const _rangeDays = [1, 3, 7];
  static const _rangeLabels = ['Today', '3 Days', '7 Days'];

  List<({DateTime time, Map<String, double> doshas})> _doshaTimeSeries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDoshaTimeSeries();
  }

  Future<void> _loadDoshaTimeSeries() async {
    setState(() => _isLoading = true);

    final provider = context.read<WatchHealthProvider>();
    final days = _rangeDays[_rangeIndex];
    final data = await provider.doshaTimeSeries(days: days);

    if (mounted) {
      setState(() {
        _doshaTimeSeries = data;
        _isLoading = false;
      });
    }
  }

  void _onRangeChanged(int index) {
    if (index == _rangeIndex) return;
    setState(() => _rangeIndex = index);
    _loadDoshaTimeSeries();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = AppTheme.primaryColor;
    final balance = computeDoshaBalance(widget.data);
    // Prefer backend engine dominant, then watch, then infer from balance
    final dominant =
        widget.data.engineNadiDominant ?? widget.data.nadiDosha ?? _dominantFromBalance(balance);

    return Scaffold(
      backgroundColor: isDark
          ? Theme.of(context).scaffoldBackgroundColor
          : const Color(0xFFF5F5F5),
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
            _buildHeroCard(isDark, balance, dominant),

            // ── Time range selector ───────────────────────────
            const SizedBox(height: 16),
            _buildRangeSelector(isDark),

            // ── Dosha trend chart ─────────────────────────────
            const SizedBox(height: 12),
            _buildDoshaTrendCard(isDark),

            // ── Dosha stats ───────────────────────────────────
            if (_doshaTimeSeries.length >= 2) ...[
              const SizedBox(height: 12),
              _buildDoshaStats(isDark),
            ],

            // ── Signal contributors + calculation ───────────
            const SizedBox(height: 12),
            NadiCalculationSection(data: widget.data),

            // ── Prahar context ────────────────────────────────
            const SizedBox(height: 12),
            _buildPraharCard(isDark, dominant),

            // ── What it means ─────────────────────────────────
            const SizedBox(height: 12),
            _buildExplanationCard(isDark),

            // ── Ayurvedic view ────────────────────────────────
            const SizedBox(height: 12),
            _buildAyurvedicCard(isDark),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ── Hero Card ──────────────────────────────────────────────────────────

  Widget _buildHeroCard(
      bool isDark, Map<String, double> balance, String dominant) {
    return DetailCard(
      isDark: isDark,
      child: Column(
        children: [
          Text(_nadiGlyph(dominant), style: const TextStyle(fontSize: 40)),
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
          Builder(builder: (context) {
            final gati = widget.data.engineNadiGati ?? widget.data.nadiGati;
            return Text(
              gati != null
                  ? _gatiDescription(gati)
                  : _nadiDescription(dominant),
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white54 : Colors.black45,
              ),
            );
          }),
          Builder(builder: (context) {
            final confidence = widget.data.engineNadiConfidence ?? widget.data.nadiConfidence;
            final signalCount = widget.data.engineNadiSignalCount ?? widget.data.nadiSignalCount;
            if (confidence == null) return const SizedBox.shrink();
            return Column(
              children: [
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${(confidence * 100).round()}% confidence',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white30 : Colors.black26,
                      ),
                    ),
                    if (signalCount != null) ...[
                      Text(
                        ' · $signalCount signals',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white24 : Colors.black26,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            );
          }),
          const SizedBox(height: 20),
          _doshaBar('Vata', balance['vata']!, vataColor, isDark),
          const SizedBox(height: 8),
          _doshaBar('Pitta', balance['pitta']!, pittaColor, isDark),
          const SizedBox(height: 8),
          _doshaBar('Kapha', balance['kapha']!, kaphaColor, isDark),
        ],
      ),
    );
  }

  // ── Range Selector ─────────────────────────────────────────────────────

  Widget _buildRangeSelector(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: List.generate(_rangeLabels.length, (i) {
          final isSelected = i == _rangeIndex;
          return Expanded(
            child: GestureDetector(
              onTap: () => _onRangeChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark
                          ? Colors.white.withValues(alpha: 0.12)
                          : Colors.white)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  _rangeLabels[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? (isDark ? Colors.white : Colors.black87)
                        : (isDark ? Colors.white38 : Colors.black38),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── Dosha Trend Chart ──────────────────────────────────────────────────

  Widget _buildDoshaTrendCard(bool isDark) {
    if (_isLoading) {
      return DetailCard(
        isDark: isDark,
        child: const SizedBox(
          height: 200,
          child: Center(child: CupertinoActivityIndicator()),
        ),
      );
    }

    if (_doshaTimeSeries.length < 2) {
      return DetailCard(
        isDark: isDark,
        child: SizedBox(
          height: 120,
          child: Center(
            child: Text(
              'Need more data for trend chart.\nKeep wearing your Apple Watch!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
          ),
        ),
      );
    }

    return DetailCard(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dosha Trend',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white54 : Colors.black45,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: CustomPaint(
              size: const Size(double.infinity, 200),
              painter: DoshaTrendPainter(
                data: _doshaTimeSeries,
                gridColor: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.06),
                labelColor: isDark
                    ? Colors.white.withValues(alpha: 0.3)
                    : Colors.black.withValues(alpha: 0.3),
                isDark: isDark,
              ),
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
    );
  }

  // ── Dosha Stats ────────────────────────────────────────────────────────

  Widget _buildDoshaStats(bool isDark) {
    // Compute min/avg/max for each dosha
    final stats = <String, ({double min, double avg, double max})>{};
    for (final key in ['vata', 'pitta', 'kapha']) {
      final values =
          _doshaTimeSeries.map((d) => d.doshas[key] ?? 33).toList();
      final minV = values.reduce(math.min);
      final maxV = values.reduce(math.max);
      final avgV = values.reduce((a, b) => a + b) / values.length;
      stats[key] = (min: minV, avg: avgV, max: maxV);
    }

    Widget statColumn(
        String label, Color color, ({double min, double avg, double max}) s) {
      return Expanded(
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            const SizedBox(height: 8),
            _statRow('Min', s.min, isDark),
            _statRow('Avg', s.avg, isDark),
            _statRow('Max', s.max, isDark),
          ],
        ),
      );
    }

    return DetailCard(
      isDark: isDark,
      child: Row(
        children: [
          statColumn('Vata', vataColor, stats['vata']!),
          Container(
            width: 1,
            height: 60,
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.1),
          ),
          statColumn('Pitta', pittaColor, stats['pitta']!),
          Container(
            width: 1,
            height: 60,
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.1),
          ),
          statColumn('Kapha', kaphaColor, stats['kapha']!),
        ],
      ),
    );
  }

  Widget _statRow(String label, double value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: isDark ? Colors.white30 : Colors.black26,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '${value.round()}%',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  // ── Prahar Context ─────────────────────────────────────────────────────

  Widget _buildPraharCard(bool isDark, String dominant) {
    final hour = DateTime.now().hour;
    final expectedDosha = _praharDosha(hour);
    final inHarmony =
        dominant.toLowerCase() == expectedDosha.toLowerCase();
    final period = _praharPeriod(hour);

    return DetailCard(
      isDark: isDark,
      child: Column(
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
                    color:
                        inHarmony ? kaphaColor : Colors.amber.shade600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            inHarmony
                ? 'Your dominant $dominant energy aligns with the '
                    'current $period ($expectedDosha time).'
                : 'Your dominant $dominant energy differs from the '
                    'current $period ($expectedDosha time). '
                    'This is normal and may shift naturally.',
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  // ── Explanation ────────────────────────────────────────────────────────

  Widget _buildExplanationCard(bool isDark) {
    return DetailCard(
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
            'by analyzing HRV patterns, heart rate, temperature, and '
            'activity to estimate your current dosha balance.',
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  // ── Ayurvedic View ─────────────────────────────────────────────────────

  Widget _buildAyurvedicCard(bool isDark) {
    return DetailCard(
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
            'Nadi Pariksha reads the pulse at three points on the '
            'radial artery. Vata pulses like a snake (Sarpa), Pitta '
            'jumps like a frog (Manduka), and Kapha glides like a '
            'swan (Hamsa). Balance shifts with season, time of day, '
            'and lifestyle.',
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  // ── Dosha Bar ──────────────────────────────────────────────────────────

  Widget _doshaBar(
      String label, double value, Color color, bool isDark) {
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

  // ── Static Helpers ─────────────────────────────────────────────────────

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

  /// When the watch sends the actual gati name, display it directly.
  static String _gatiDescription(String gati) {
    switch (gati.toLowerCase()) {
      case 'sarpa':
        return 'Sarpa gati · Snake-like pulse';
      case 'manduka':
        return 'Manduka gati · Frog-like pulse';
      case 'hamsa':
        return 'Hamsa gati · Swan-like pulse';
      default:
        return '${capitalize(gati)} gati';
    }
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
}

