import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/shared/models/watch_health_data.dart';
import 'package:aurogram/features/ayurveda/domain/ojas_engine.dart';
import 'package:aurogram/features/ayurveda/presentation/widgets/ayurveda_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// OjasDetailPage — Full Ojas calculation breakdown
// ─────────────────────────────────────────────────────────────────────────────

/// Transparent drill-down for Ojas score showing:
///   - Hero score + summary
///   - Signal contributor table (score × weight = contribution)
///   - Modifier ledger (bonuses / penalties)
///   - Final calculation walkthrough
class OjasDetailPage extends StatelessWidget {
  final WatchHealthData data;

  const OjasDetailPage({super.key, required this.data});

  OjasResult? _computeOjas() {
    return OjasEngine.compute(
      hrv: data.hrv,
      restingHR: data.restingHR,
      sleepHours: data.sleepHours,
      deepSleepMins: data.deepSleepMins,
      remSleepMins: data.remSleepMins,
      sleepOnsetHour: data.sleepOnset,
      spO2: data.spO2,
      wristTemp: data.wristTemp,
      respRate: data.respRate,
      vo2Max: data.vo2Max,
      steps: data.steps,
      hrRecovery: data.hrRecovery,
      activeEnergy: data.activeEnergy,
      mindfulMins: data.mindfulMins,
      standHours: data.standHours,
      daylightMins: data.daylightMins,
      envAudioExposure: data.envAudioExposure,
      afibBurden: data.afibBurden,
      highHRCount: data.highHRCount,
      irregularRhythmCount: data.irregularRhythmCount,
      sleepApneaCount: data.sleepApneaCount,
      fallCount: data.fallCount,
      lowCardioFitnessCount: data.lowCardioFitnessCount,
      walkingSteadiness: data.walkingSteadiness,
      rmssd: data.rmssd,
      uvExposure: data.uvExposure,
      heartRate: data.heartRate,
      exerciseMins: data.exerciseMins,
      coreSleepMins: data.coreSleepMins,
      pnn50: data.pnn50,
      walkingHR: data.walkingHR,
      walkingAsymmetry: data.walkingAsymmetry,
      walkingDoubleSupport: data.doubleSupport,
      headphoneAudioExposure: data.headphoneAudioExposure,
      lowHRCount: data.lowHRCount,
      bodyTemp: data.bodyTemp,
      timestamp: data.timestamp,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = AppTheme.primaryColor;
    final result = _computeOjas();

    // Fall back to raw watch score if engine can't recompute
    final displayScore = result?.score ?? data.bestOjasScore?.round() ?? 0;
    final displaySummary = result?.summary ?? data.bestOjasSummary ?? '';

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
          'Ojas · Vitality',
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
            // ── Hero score ────────────────────────────────────
            _buildHeroCard(isDark, displayScore, displaySummary, result),

            // ── Signal contributors table ─────────────────────
            if (result != null && result.contributors.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildContributorsCard(isDark, result),
            ],

            // ── Live calculation ──────────────────────────────
            if (result != null) ...[
              const SizedBox(height: 12),
              _buildCalculationCard(isDark, result),
            ],

            // ── Modifiers ledger ──────────────────────────────
            if (result != null && result.modifiers.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildModifiersCard(isDark, result),
            ],

            // ── Agni type ─────────────────────────────────────
            if (result != null) ...[
              const SizedBox(height: 12),
              _buildAgniCard(isDark, result),
            ],

            // ── Ayurvedic perspective ─────────────────────────
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
      bool isDark, int score, String summary, OjasResult? result) {
    final scoreColor = _ojasColor(score.toDouble());

    return DetailCard(
      isDark: isDark,
      child: Column(
        children: [
          // Arc gauge
          SizedBox(
            width: 120,
            height: 120,
            child: CustomPaint(
              painter: _OjasArcPainter(
                fraction: (score / 100).clamp(0.0, 1.0),
                color: scoreColor,
                trackColor: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.grey.shade200,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$score',
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w800,
                        color: scoreColor,
                        height: 1,
                      ),
                    ),
                    Text(
                      summary,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: scoreColor.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (result != null) ...[
            const SizedBox(height: 8),
            Text(
              '${result.signalCount} signals · ${result.isReliable ? "reliable" : "improving"}',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white30 : Colors.black26,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Contributors Card ──────────────────────────────────────────────────

  Widget _buildContributorsCard(bool isDark, OjasResult result) {
    return DetailCard(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('SIGNAL CONTRIBUTORS', isDark),
          const SizedBox(height: 12),
          ...result.contributors.map((c) => _contributorRow(c, isDark)),
        ],
      ),
    );
  }

  Widget _contributorRow(OjasContributor c, bool isDark) {
    final statusColor = _statusColor(c.status);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Icon + Name + Raw value
          Row(
            children: [
              Icon(
                _signalIcon(c.signal),
                size: 14,
                color: statusColor,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  c.name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white.withValues(alpha: 0.85) : Colors.black87,
                  ),
                ),
              ),
              Text(
                c.rawDisplay,
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Row 2: Score bar + weight + contribution
          Row(
            children: [
              const SizedBox(width: 20),
              Expanded(
                child: Stack(
                  children: [
                    Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: c.score.clamp(0.0, 1.0),
                      child: Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 70,
                child: Text(
                  '${(c.score * 100).round()} × ${(c.weight * 100).round()}%',
                  style: TextStyle(
                    fontSize: 10,
                    fontFamily: 'monospace',
                    color: isDark ? Colors.white38 : Colors.black26,
                  ),
                ),
              ),
              SizedBox(
                width: 35,
                child: Text(
                  '= ${c.contribution.toStringAsFixed(1)}',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'monospace',
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          // Row 3: Baseline + explanation
          Padding(
            padding: const EdgeInsets.only(left: 20, top: 2),
            child: Text(
              c.baselineDisplay,
              style: TextStyle(
                fontSize: 10,
                color: isDark ? Colors.white24 : Colors.black26,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Calculation Card ───────────────────────────────────────────────────

  Widget _buildCalculationCard(bool isDark, OjasResult result) {
    return DetailCard(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('CALCULATION', isDark),
          const SizedBox(height: 12),

          // Base score
          _calcRow('Base Score', '${result.baseScore}', isDark,
              color: isDark ? Colors.white70 : Colors.black54, bold: true),
          const SizedBox(height: 6),

          // Modifiers total
          if (result.modifiers.isNotEmpty) ...[
            _calcRow(
              'Modifiers',
              '${result.modifierDelta >= 0 ? "+" : ""}${result.modifierDelta}',
              isDark,
              color: result.modifierDelta >= 0 ? kaphaColor : pittaColor,
            ),
            const SizedBox(height: 6),
          ],

          // Ceiling
          if (result.ceiling < 100) ...[
            _calcRow('Ceiling', '≤ ${result.ceiling}', isDark,
                color: pittaColor.withValues(alpha: 0.7)),
            const SizedBox(height: 6),
          ],

          // Divider
          Container(
            height: 1,
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.06),
          ),
          const SizedBox(height: 8),

          // Final score
          _calcRow('Ojas Score', '${result.score}', isDark,
              color: _ojasColor(result.score.toDouble()),
              bold: true,
              large: true),
        ],
      ),
    );
  }

  Widget _calcRow(String label, String value, bool isDark,
      {Color? color, bool bold = false, bool large = false}) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: large ? 15 : 13,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            color: color ?? (isDark ? Colors.white60 : Colors.black45),
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: large ? 24 : 15,
            fontWeight: FontWeight.w800,
            fontFamily: 'monospace',
            color: color ?? (isDark ? Colors.white : Colors.black87),
          ),
        ),
      ],
    );
  }

  // ── Modifiers Card ─────────────────────────────────────────────────────

  Widget _buildModifiersCard(bool isDark, OjasResult result) {
    return DetailCard(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('MODIFIERS', isDark),
          const SizedBox(height: 12),
          ...result.modifiers.map((m) => _modifierRow(m, isDark)),
        ],
      ),
    );
  }

  Widget _modifierRow(OjasModifier m, bool isDark) {
    final isPositive = m.delta > 0;
    final isCap = m.note != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.03)
              : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    m.name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white.withValues(alpha: 0.85) : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    m.note ?? m.detail,
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              isCap ? 'cap' : '${m.delta >= 0 ? "+" : ""}${m.delta.round()}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                fontFamily: 'monospace',
                color: isCap
                    ? pittaColor
                    : (isPositive ? kaphaColor : pittaColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Agni Card ──────────────────────────────────────────────────────────

  Widget _buildAgniCard(bool isDark, OjasResult result) {
    return DetailCard(
      isDark: isDark,
      child: Row(
        children: [
          const Text('🔥', style: TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${result.agniType} Agni',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  result.agniDescription,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Ayurvedic Card ─────────────────────────────────────────────────────

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
            'Ojas is the subtle essence of all seven dhatus (tissues). '
            'It represents vitality, immunity, and life force. The score '
            'is computed from a transparent weighted sum of evidence-based '
            'vitality drivers: HRV (35%), Sleep (22%), Resting HR (18%), '
            'Wrist Temp (10%), Respiration (8%), and Activity (7%), with '
            'modifiers for recovery, mindfulness, and cardiac health.',
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

  // ── Helpers ────────────────────────────────────────────────────────────

  Widget _sectionHeader(String text, bool isDark) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
        color: isDark
            ? AppTheme.primaryColor.withValues(alpha: 0.7)
            : AppTheme.primaryColor.withValues(alpha: 0.6),
      ),
    );
  }

  Color _ojasColor(double score) {
    if (score >= 75) return kaphaColor;
    if (score >= 50) return const Color(0xFF3498DB);
    if (score >= 30) return Colors.amber.shade600;
    return pittaColor;
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'good':
        return kaphaColor;
      case 'moderate':
        return Colors.amber.shade600;
      case 'low':
        return pittaColor;
      default:
        return Colors.grey;
    }
  }

  IconData _signalIcon(String signal) {
    switch (signal) {
      case 'sleep':
        return CupertinoIcons.moon_fill;
      case 'pulse':
        return CupertinoIcons.waveform_path_ecg;
      case 'restingHR':
        return CupertinoIcons.heart_fill;
      case 'warmth':
        return CupertinoIcons.thermometer;
      case 'breath':
        return CupertinoIcons.wind;
      case 'fitness':
        return CupertinoIcons.sportscourt_fill;
      case 'movement':
        return CupertinoIcons.person_fill;
      case 'recovery':
        return CupertinoIcons.arrow_down_circle_fill;
      case 'oxygen':
        return CupertinoIcons.circle_fill;
      case 'energy':
        return CupertinoIcons.flame_fill;
      case 'mindful':
        return CupertinoIcons.sparkles;
      default:
        return CupertinoIcons.circle_fill;
    }
  }
}

// ─── Arc Painter ──────────────────────────────────────────────────────────────

class _OjasArcPainter extends CustomPainter {
  final double fraction;
  final Color color;
  final Color trackColor;

  _OjasArcPainter({
    required this.fraction,
    required this.color,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;

    const startAngle = 2.356; // ~135°
    const sweepTotal = 4.712; // ~270°

    // Track
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepTotal,
      false,
      Paint()
        ..color = trackColor
        ..strokeWidth = 8
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // Filled arc
    if (fraction > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepTotal * fraction,
        false,
        Paint()
          ..color = color
          ..strokeWidth = 8
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _OjasArcPainter oldDelegate) =>
      fraction != oldDelegate.fraction || color != oldDelegate.color;
}
