import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:aurogram/shared/models/watch_health_data.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';
import 'package:aurogram/features/ayurveda/presentation/widgets/ayurveda_theme.dart';
import 'package:provider/provider.dart';
import 'package:aurogram/shared/providers/watch_health_provider.dart';
import 'package:aurogram/features/ayurveda/presentation/pages/signal_detail_page.dart';
import 'package:aurogram/features/ayurveda/presentation/pages/metric_info.dart';
import 'package:aurogram/features/ayurveda/presentation/pages/nadi_detail_page.dart';
import 'package:aurogram/features/ayurveda/presentation/pages/ojas_detail_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Dosha Balance Computation — shared between NadiCard and NadiDetailPage
// ─────────────────────────────────────────────────────────────────────────────

/// Dosha balance from health signals.
/// Priority: backend engine > watch engine > heuristic fallback.
///
/// Backend engine (Cloud Functions) uses the full signal set with personal
/// baselines and is the most accurate. Watch engine runs on-device with
/// 11 weighted signals. Heuristic is a crude approximation from raw vitals.
Map<String, double> computeDoshaBalance(WatchHealthData data) {
  // 1. Prefer backend-computed dosha breakdown (most accurate, cross-platform)
  if (data.hasBackendNadi) {
    final v = data.engineNadiVata!;
    final p = data.engineNadiPitta!;
    final k = data.engineNadiKapha!;
    final total = v + p + k;
    if (total > 0) {
      return {
        'vata': (v / total) * 100,
        'pitta': (p / total) * 100,
        'kapha': (k / total) * 100,
      };
    }
  }

  // 2. Fall back to watch-computed dosha breakdown (on-device NadiEngine)
  if (data.hasNadiBreakdown) {
    final v = data.nadiVata!;
    final p = data.nadiPitta!;
    final k = data.nadiKapha!;
    final total = v + p + k;
    if (total > 0) {
      return {
        'vata': (v / total) * 100,
        'pitta': (p / total) * 100,
        'kapha': (k / total) * 100,
      };
    }
  }

  // Fallback: approximate from raw signals (less accurate)
  double vata = 33, pitta = 33, kapha = 34;

  if (data.hrv != null) {
    if (data.hrv! > 60) { vata += 8; pitta -= 3; kapha -= 5; }
    else if (data.hrv! < 25) { kapha += 6; vata -= 3; pitta -= 3; }
  }
  if (data.restingHR != null) {
    if (data.restingHR! > 75) { pitta += 5; vata += 3; kapha -= 5; }
    else if (data.restingHR! < 55) { kapha += 5; pitta -= 3; }
  }
  if (data.wristTemp != null) {
    if (data.wristTemp! > 0.3) { pitta += 6; vata -= 2; }
    else if (data.wristTemp! < -0.3) { vata += 5; kapha += 2; pitta -= 4; }
  }
  if (data.sleepHours != null) {
    if (data.sleepHours! < 6) { vata += 6; pitta += 3; kapha -= 5; }
    else if (data.sleepHours! > 9) { kapha += 8; vata -= 4; pitta -= 2; }
  }
  if (data.respRate != null) {
    if (data.respRate! > 18) { vata += 4; kapha -= 2; }
    else if (data.respRate! < 12) { kapha += 3; }
  }
  if (data.normalizedSpO2 != null && data.normalizedSpO2! < 94) {
    kapha += 4; vata += 2;
  }
  if (data.steps != null) {
    if (data.steps! < 2000) { kapha += 5; vata -= 2; }
    else if (data.steps! > 15000) { vata += 4; kapha -= 3; }
  }

  final total = [vata, pitta, kapha].reduce((a, b) => a + b);
  if (total > 0) {
    vata = (vata / total) * 100;
    pitta = (pitta / total) * 100;
    kapha = (kapha / total) * 100;
  }
  return {'vata': vata, 'pitta': pitta, 'kapha': kapha};
}

// ─────────────────────────────────────────────────────────────────────────────
// OjasScoreCard — Hero vitality gauge from Apple Watch
// ─────────────────────────────────────────────────────────────────────────────

class OjasScoreCard extends StatelessWidget {
  final WatchHealthData data;
  final bool isDark;

  const OjasScoreCard({
    super.key,
    required this.data,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.primaryColor;
    // Prefer backend engine score, fall back to watch-computed
    final score = data.bestOjasScore;
    if (score == null) return const SizedBox.shrink();

    final scoreInt = score.round();
    final fraction = (score / 100).clamp(0.0, 1.0);
    final summary = data.bestOjasSummary ?? _ojasLabel(score);

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.of(context).push(
          CupertinoPageRoute<void>(
            builder: (_) => OjasDetailPage(data: data),
          ),
        );
      },
      child: AyurvedaCardContainer(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Text(
                'Ojas · Vitality',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: c,
                ),
              ),
              const Spacer(),
              if (data.freshness.isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: data.isFresh
                            ? kaphaColor
                            : Colors.amber.shade600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      data.freshness,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacingLg),

          // Circular gauge + score
          Center(
            child: SizedBox(
              width: 140,
              height: 140,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Arc gauge
                  CustomPaint(
                    size: const Size(140, 140),
                    painter: _OjasArcPainter(
                      fraction: fraction,
                      color: _ojasColor(score),
                      trackColor: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.grey.shade200,
                    ),
                  ),
                  // Score text
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$scoreInt',
                        style: TextStyle(
                          fontSize: 44,
                          fontWeight: FontWeight.w800,
                          color: _ojasColor(score),
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        summary,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _ojasColor(score).withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.spacingLg),

          // Ojas history sparkline
          if (data.ojasHistory.length >= 2) ...[
            Row(
              children: [
                Text(
                  '7-DAY TREND',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: isDark ? Colors.white30 : Colors.black26,
                  ),
                ),
                const Spacer(),
                Text(
                  '${data.ojasHistory.last.round()}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace',
                    color: _ojasColor(data.ojasHistory.last),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 32,
              child: CustomPaint(
                size: const Size(double.infinity, 32),
                painter: _SparklinePainter(
                  data: data.ojasHistory,
                  color: _ojasColor(score),
                  fillOpacity: 0.15,
                ),
              ),
            ),
          ],

          // Agni + Nadi badges (prefer backend engine values)
          if (data.bestAgniType != null || data.engineNadiDominant != null || data.nadiDosha != null) ...[
            const SizedBox(height: AppDimensions.spacingMd),
            Row(
              children: [
                if (data.bestAgniType != null)
                  _buildBadge(
                    '🔥 ${_agniLabel(data.bestAgniType!)}',
                    isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade50,
                    isDark ? Colors.white60 : Colors.black54,
                  ),
                if (data.bestAgniType != null && (data.engineNadiDominant ?? data.nadiDosha) != null)
                  const SizedBox(width: 8),
                if ((data.engineNadiDominant ?? data.nadiDosha) != null)
                  Builder(builder: (context) {
                    final d = data.engineNadiDominant ?? data.nadiDosha!;
                    return _buildBadge(
                      '${_nadiGlyph(d)} ${capitalize(d)} Nadi',
                      getDoshaColor(d).withValues(alpha: 0.1),
                      getDoshaColor(d),
                    );
                  }),
              ],
            ),
          ],

          // Signal count
          const SizedBox(height: AppDimensions.spacingMd),
          Text(
            '${data.signalCount} signals from Apple Watch',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.white24 : Colors.black26,
            ),
          ),
        ],
      ),
    ),  // close GestureDetector child (AyurvedaCardContainer)
    );  // close GestureDetector
  }

  Widget _buildBadge(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }

  Color _ojasColor(double score) {
    if (score >= 75) return kaphaColor;
    if (score >= 50) return const Color(0xFF3498DB);
    if (score >= 30) return Colors.amber.shade600;
    return pittaColor;
  }

  String _ojasLabel(double score) {
    if (score >= 80) return 'Thriving';
    if (score >= 60) return 'Balanced';
    if (score >= 40) return 'Moderate';
    if (score >= 20) return 'Depleted';
    return 'Low';
  }

  String _agniLabel(String type) {
    switch (type.toLowerCase()) {
      case 'sama':
        return 'Sama';
      case 'vishama':
        return 'Vishama';
      case 'tikshna':
        return 'Tikshna';
      case 'manda':
        return 'Manda';
      default:
        return capitalize(type);
    }
  }

  String _nadiGlyph(String dosha) {
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
}

// ─────────────────────────────────────────────────────────────────────────────
// BodySignalsGrid — Clean 2-column grid of minimal metric tiles
// ─────────────────────────────────────────────────────────────────────────────

class BodySignalsGrid extends StatelessWidget {
  final WatchHealthData data;
  final bool isDark;
  final Map<String, List<double>>? trends;

  const BodySignalsGrid({
    super.key,
    required this.data,
    required this.isDark,
    this.trends,
  });

  @override
  Widget build(BuildContext context) {
    final signals = _buildSignalList();
    if (signals.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Row(
            children: [
              Text(
                'Body Signals',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryColor,
                ),
              ),
              const Spacer(),
              Text(
                '${signals.length} active',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white30 : Colors.black26,
                ),
              ),
            ],
          ),
        ),
        // 2-column grid of metric tiles
        ..._buildRows(context, signals),
      ],
    );
  }

  List<Widget> _buildRows(BuildContext context, List<_SignalData> signals) {
    final rows = <Widget>[];
    for (int i = 0; i < signals.length; i += 2) {
      if (i > 0) rows.add(const SizedBox(height: 10));
      final left = signals[i];
      final right = (i + 1 < signals.length) ? signals[i + 1] : null;
      rows.add(Row(
        children: [
          Expanded(
            child: _MetricTile(
              data: left,
              isDark: isDark,
              trend: _trendFor(left),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: right != null
                ? _MetricTile(
                    data: right,
                    isDark: isDark,
                    trend: _trendFor(right),
                  )
                : const SizedBox(),
          ),
        ],
      ));
    }
    return rows;
  }

  List<double>? _trendFor(_SignalData s) {
    if (s.metricKey == null || trends == null) return null;
    return trends![s.metricKey!];
  }

  List<_SignalData> _buildSignalList() {
    final d = data;
    final list = <_SignalData>[];

    // Current Heart Rate — the most useful live signal
    if (d.heartRate != null) {
      final v = d.heartRate!;
      list.add(_SignalData(
        icon: Icons.favorite_rounded,
        label: 'Heart Rate',
        value: '${v.round()}',
        unit: 'bpm',
        status: v < 60 ? 'Low' : v <= 100 ? 'Normal' : v <= 120 ? 'Elevated' : 'High',
        statusColor: (v >= 60 && v <= 100)
            ? kaphaColor
            : v <= 120 ? Colors.amber.shade600 : pittaColor,
        ayurvedaHint: v > 100 ? 'Pitta ↑' : v < 55 ? 'Kapha ↑' : null,
        metricKey: 'heartRate',
      ));
    }

    // Heart variability
    if (d.hrv != null) {
      final v = d.hrv!;
      list.add(_SignalData(
        icon: Icons.favorite_border,
        label: 'HRV',
        value: '${v.round()}',
        unit: 'ms',
        status: v > 50 ? 'Good' : v > 25 ? 'Fair' : 'Low',
        statusColor: v > 50 ? kaphaColor : v > 25 ? Colors.amber.shade600 : pittaColor,
        ayurvedaHint: v > 60 ? 'Vata ↑' : v < 25 ? 'Kapha ↑' : null,
        metricKey: 'hrv',
      ));
    }
    if (d.restingHR != null) {
      final v = d.restingHR!;
      list.add(_SignalData(
        icon: Icons.monitor_heart_outlined,
        label: 'Resting HR',
        value: '${v.round()}',
        unit: 'bpm',
        status: v < 65 ? 'Good' : v < 80 ? 'Normal' : 'Elevated',
        statusColor: v < 65 ? kaphaColor : v < 80 ? Colors.amber.shade600 : pittaColor,
        ayurvedaHint: v > 75 ? 'Pitta ↑' : v < 55 ? 'Kapha ↑' : null,
        metricKey: 'restingHR',
      ));
    }

    // Breath & Oxygen
    if (d.spO2 != null) {
      final pct = d.normalizedSpO2!;
      list.add(_SignalData(
        icon: Icons.air,
        label: 'Blood O₂',
        value: '${pct.round()}',
        unit: '%',
        status: pct >= 95 ? 'Normal' : pct >= 92 ? 'Fair' : 'Low',
        statusColor: pct >= 95 ? kaphaColor : pct >= 92 ? Colors.amber.shade600 : pittaColor,
        ayurvedaHint: pct < 94 ? 'Kapha ↑' : null,
        metricKey: 'spO2',
      ));
    }
    if (d.respRate != null) {
      final v = d.respRate!;
      list.add(_SignalData(
        icon: Icons.waves,
        label: 'Breath',
        value: '${v.round()}',
        unit: '/min',
        status: (v >= 12 && v <= 20) ? 'Normal' : 'Elevated',
        statusColor: (v >= 12 && v <= 20) ? kaphaColor : pittaColor,
        ayurvedaHint: v > 18 ? 'Vata ↑' : null,
        metricKey: 'respRate',
      ));
    }

    // Temperature
    if (d.wristTemp != null) {
      final v = d.wristTemp!;
      final sign = v >= 0 ? '+' : '';
      list.add(_SignalData(
        icon: Icons.thermostat_outlined,
        label: 'Wrist Temp',
        value: '$sign${v.toStringAsFixed(1)}',
        unit: '°C',
        status: v.abs() < 0.3 ? 'Stable' : 'Shifted',
        statusColor: v.abs() < 0.3 ? kaphaColor : pittaColor,
        ayurvedaHint: v > 0.3 ? 'Pitta ↑' : v < -0.3 ? 'Vata ↑' : null,
        metricKey: 'wristTemp',
      ));
    }

    // Fitness
    if (d.vo2Max != null) {
      final v = d.vo2Max!;
      list.add(_SignalData(
        icon: Icons.directions_run,
        label: 'VO₂ Max',
        value: '${v.round()}',
        unit: '',
        status: v >= 40 ? 'Good' : v >= 30 ? 'Fair' : 'Low',
        statusColor: v >= 40 ? kaphaColor : v >= 30 ? Colors.amber.shade600 : pittaColor,
        metricKey: 'vo2Max',
      ));
    }
    if (d.steps != null) {
      list.add(_SignalData(
        icon: Icons.directions_walk,
        label: 'Steps',
        value: _formatSteps(d.steps!),
        unit: '',
        status: d.steps! >= 8000 ? 'Active' : d.steps! >= 4000 ? 'Fair' : 'Low',
        statusColor: d.steps! >= 8000 ? kaphaColor : d.steps! >= 4000 ? Colors.amber.shade600 : pittaColor,
        ayurvedaHint: d.steps! < 2000 ? 'Kapha ↑' : d.steps! > 15000 ? 'Vata ↑' : null,
        metricKey: 'steps',
      ));
    }

    // Energy
    if (d.activeEnergy != null) {
      list.add(_SignalData(
        icon: Icons.local_fire_department_outlined,
        label: 'Active Cal',
        value: '${d.activeEnergy!.round()}',
        unit: 'kcal',
        status: d.activeEnergy! >= 300 ? 'Active' : 'Low',
        statusColor: d.activeEnergy! >= 300 ? kaphaColor : Colors.amber.shade600,
        metricKey: 'activeEnergy',
      ));
    }

    // Recovery
    if (d.hrRecovery != null) {
      final v = d.hrRecovery!;
      list.add(_SignalData(
        icon: Icons.restore,
        label: 'HR Recovery',
        value: '${v.round()}',
        unit: 'bpm',
        status: v >= 20 ? 'Good' : v >= 12 ? 'Fair' : 'Low',
        statusColor: v >= 20 ? kaphaColor : v >= 12 ? Colors.amber.shade600 : pittaColor,
        metricKey: 'hrRecovery',
      ));
    }

    // Mindful
    if (d.mindfulMins != null && d.mindfulMins! > 0) {
      list.add(_SignalData(
        icon: Icons.self_improvement,
        label: 'Mindful',
        value: '${d.mindfulMins!.round()}',
        unit: 'min',
        status: d.mindfulMins! >= 10 ? 'Good' : 'Brief',
        statusColor: d.mindfulMins! >= 10 ? kaphaColor : Colors.amber.shade600,
        metricKey: 'mindfulMins',
      ));
    }

    // RMSSD (parasympathetic tone — gold standard beat-to-beat HRV)
    if (d.rmssd != null) {
      final v = d.rmssd!;
      list.add(_SignalData(
        icon: Icons.monitor_heart,
        label: 'RMSSD',
        value: '${v.round()}',
        unit: 'ms',
        status: v >= 50 ? 'Good' : v >= 20 ? 'Fair' : 'Low',
        statusColor: v >= 50 ? kaphaColor : v >= 20 ? Colors.amber.shade600 : pittaColor,
        ayurvedaHint: v >= 80 ? 'Vagal ↑' : v < 15 ? 'Vata ↑' : null,
        metricKey: 'rmssd',
      ));
    }

    // Walking HR
    if (d.walkingHR != null) {
      final v = d.walkingHR!;
      list.add(_SignalData(
        icon: Icons.directions_walk,
        label: 'Walking HR',
        value: '${v.round()}',
        unit: 'bpm',
        status: v < 110 ? 'Normal' : v < 130 ? 'Elevated' : 'High',
        statusColor: v < 110 ? kaphaColor : v < 130 ? Colors.amber.shade600 : pittaColor,
        metricKey: 'walkingHR',
      ));
    }

    // Stand Hours
    if (d.standHours != null) {
      final v = d.standHours!;
      list.add(_SignalData(
        icon: Icons.accessibility,
        label: 'Stand Hrs',
        value: '$v',
        unit: 'hrs',
        status: v >= 10 ? 'Good' : v >= 6 ? 'Fair' : 'Low',
        statusColor: v >= 10 ? kaphaColor : v >= 6 ? Colors.amber.shade600 : pittaColor,
        metricKey: 'standHours',
      ));
    }

    // Exercise Minutes
    if (d.exerciseMins != null && d.exerciseMins! > 0) {
      final v = d.exerciseMins!;
      list.add(_SignalData(
        icon: Icons.fitness_center,
        label: 'Exercise',
        value: '${v.round()}',
        unit: 'min',
        status: v >= 30 ? 'Good' : v >= 15 ? 'Fair' : 'Low',
        statusColor: v >= 30 ? kaphaColor : v >= 15 ? Colors.amber.shade600 : pittaColor,
        metricKey: 'exerciseMins',
      ));
    }

    // Distance
    if (d.distance != null && d.distance! > 0) {
      final km = d.distance! / 1000;
      list.add(_SignalData(
        icon: Icons.straighten,
        label: 'Distance',
        value: km.toStringAsFixed(1),
        unit: 'km',
        status: km >= 5 ? 'Active' : km >= 2 ? 'Fair' : 'Low',
        statusColor: km >= 5 ? kaphaColor : km >= 2 ? Colors.amber.shade600 : pittaColor,
        metricKey: 'distance',
      ));
    }

    // Walking Steadiness
    if (d.walkingSteadiness != null) {
      final v = d.walkingSteadiness!;
      list.add(_SignalData(
        icon: Icons.accessibility_new,
        label: 'Steadiness',
        value: '${v.round()}',
        unit: '%',
        status: v >= 70 ? 'OK' : v >= 40 ? 'Low' : 'Very Low',
        statusColor: v >= 70 ? kaphaColor : v >= 40 ? Colors.amber.shade600 : pittaColor,
        metricKey: 'walkingSteadiness',
      ));
    }

    // Workout summary
    if (d.workoutCount != null && d.workoutCount! > 0) {
      list.add(_SignalData(
        icon: Icons.timer,
        label: 'Workouts',
        value: '${d.workoutCount}',
        unit: d.workoutMins != null ? '(${d.workoutMins!.round()}m)' : '',
        status: d.workoutCount! >= 1 ? 'Active' : 'None',
        statusColor: kaphaColor,
        metricKey: 'workoutMins',
      ));
    }

    // Sleep
    if (d.sleepHours != null) {
      final v = d.sleepHours!;
      list.add(_SignalData(
        icon: Icons.bedtime_outlined,
        label: 'Sleep',
        value: v.toStringAsFixed(1),
        unit: 'hrs',
        status: v >= 7 ? 'Good' : v >= 5 ? 'Fair' : 'Low',
        statusColor: v >= 7 ? kaphaColor : v >= 5 ? Colors.amber.shade600 : pittaColor,
        metricKey: 'sleepHours',
      ));
    }
    if (d.deepSleepMins != null) {
      final v = d.deepSleepMins!;
      list.add(_SignalData(
        icon: Icons.nightlight_round,
        label: 'Deep Sleep',
        value: '${v.round()}',
        unit: 'min',
        status: v >= 60 ? 'Good' : v >= 30 ? 'Fair' : 'Low',
        statusColor: v >= 60 ? kaphaColor : v >= 30 ? Colors.amber.shade600 : pittaColor,
        metricKey: 'deepSleepMins',
      ));
    }
    if (d.remSleepMins != null) {
      final v = d.remSleepMins!;
      list.add(_SignalData(
        icon: Icons.visibility_outlined,
        label: 'REM Sleep',
        value: '${v.round()}',
        unit: 'min',
        status: v >= 90 ? 'Good' : v >= 60 ? 'Fair' : 'Low',
        statusColor: v >= 90 ? kaphaColor : v >= 60 ? Colors.amber.shade600 : pittaColor,
        metricKey: 'remSleepMins',
      ));
    }

    return list;
  }

  static String _formatSteps(int steps) {
    if (steps >= 1000) return '${(steps / 1000).toStringAsFixed(1)}k';
    return '$steps';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _MetricTile — Minimal card tile for a single health metric
// ─────────────────────────────────────────────────────────────────────────────

class _MetricTile extends StatelessWidget {
  final _SignalData data;
  final bool isDark;
  final List<double>? trend;

  const _MetricTile({
    required this.data,
    required this.isDark,
    this.trend,
  });

  @override
  Widget build(BuildContext context) {
    final hasDetail = data.metricKey != null;

    return GestureDetector(
      onTap: hasDetail
          ? () {
              HapticFeedback.lightImpact();
              Navigator.of(context).push(
                CupertinoPageRoute<void>(
                  builder: (_) => SignalDetailPage(
                    label: data.label,
                    value: data.value,
                    unit: data.unit,
                    status: data.status,
                    statusColor: data.statusColor,
                    icon: data.icon,
                    ayurvedaHint: data.ayurvedaHint,
                    metricKey: data.metricKey,
                    trend: trend,
                    info: getMetricInfo(data.metricKey!),
                  ),
                ),
              );
            }
          : null,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark
              ? Theme.of(context).colorScheme.surface
              : Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Row 1: icon ... value + unit
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Icon(
                  data.icon,
                  size: 18,
                  color: data.statusColor.withValues(alpha: 0.7),
                ),
                const Spacer(),
                Text(
                  data.value,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87,
                    height: 1,
                  ),
                ),
                if (data.unit.isNotEmpty) ...[
                  const SizedBox(width: 3),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      data.unit,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),

            // Row 2: label ... status dot + text
            Row(
              children: [
                Expanded(
                  child: Text(
                    data.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: data.statusColor,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  data.status,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: data.statusColor,
                  ),
                ),
              ],
            ),

            // Optional Ayurveda hint
            if (data.ayurvedaHint != null) ...[
              const SizedBox(height: 4),
              Text(
                data.ayurvedaHint!,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: getDoshaColor(
                    data.ayurvedaHint!.contains('Vata')
                        ? 'vata'
                        : data.ayurvedaHint!.contains('Pitta')
                            ? 'pitta'
                            : 'kapha',
                  ).withValues(alpha: 0.6),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WatchNadiCard — Pulse / Dosha analysis from watch HRV
// ─────────────────────────────────────────────────────────────────────────────

class WatchNadiCard extends StatelessWidget {
  final WatchHealthData data;
  final bool isDark;

  const WatchNadiCard({
    super.key,
    required this.data,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.primaryColor;
    // Best available dominant dosha: backend > watch
    final dominant = data.engineNadiDominant ?? data.nadiDosha;
    if (dominant == null && data.hrv == null) return const SizedBox.shrink();

    final doshaBalance = computeDoshaBalance(data);

    // Best available confidence/signal count: backend > watch
    final confidence = data.engineNadiConfidence ?? data.nadiConfidence;
    final signalCount = data.engineNadiSignalCount ?? data.nadiSignalCount;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.of(context).push(
          CupertinoPageRoute<void>(
            builder: (_) => NadiDetailPage(data: data),
          ),
        );
      },
      child: AyurvedaCardContainer(
        isDark: isDark,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Text(
                  'Nadi · Pulse Reading',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: c,
                  ),
                ),
                const Spacer(),
                Icon(
                  CupertinoIcons.chevron_right,
                  size: 14,
                  color: isDark ? Colors.white24 : Colors.black26,
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingMd),

            // Nadi type
            if (dominant != null) ...[
              Row(
                children: [
                  Text(
                    _nadiGlyph(dominant),
                    style: const TextStyle(fontSize: 24),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${capitalize(dominant)} Nadi',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: getDoshaColor(dominant),
                          ),
                        ),
                        Text(
                          _nadiDescription(dominant),
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
              const SizedBox(height: AppDimensions.spacingLg),
            ],

            // Dosha balance bars
            _buildDoshaBar('Vata', doshaBalance['vata']!, vataColor),
            const SizedBox(height: 8),
            _buildDoshaBar('Pitta', doshaBalance['pitta']!, pittaColor),
            const SizedBox(height: 8),
            _buildDoshaBar('Kapha', doshaBalance['kapha']!, kaphaColor),

            // Confidence & signal count
            if (confidence != null || signalCount != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  if (confidence != null)
                    Text(
                      '${(confidence * 100).round()}% confidence',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white30 : Colors.black26,
                      ),
                    ),
                  const Spacer(),
                  if (signalCount != null)
                    Text(
                      '$signalCount signals',
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? Colors.white24 : Colors.black26,
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDoshaBar(String label, double value, Color color) {
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
// SleepSummaryCard — Sleep breakdown from watch
// ─────────────────────────────────────────────────────────────────────────────

class SleepSummaryCard extends StatelessWidget {
  final WatchHealthData data;
  final bool isDark;

  const SleepSummaryCard({
    super.key,
    required this.data,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.primaryColor;
    if (data.sleepHours == null) return const SizedBox.shrink();

    final total = data.sleepHours!;
    final deep = data.deepSleepMins ?? 0;
    final rem = data.remSleepMins ?? 0;
    final totalMins = (total * 60).round();
    final core = (totalMins - deep - rem).clamp(0, totalMins).toDouble();

    final statusColor = total >= 7 ? kaphaColor : total >= 5 ? Colors.amber.shade600 : pittaColor;
    final status = total >= 7 ? 'Good' : total >= 5 ? 'Fair' : 'Low';

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.of(context).push(
          CupertinoPageRoute<void>(
            builder: (_) => SignalDetailPage(
              label: 'Sleep',
              value: total.toStringAsFixed(1),
              unit: 'hrs',
              status: status,
              statusColor: statusColor,
              icon: Icons.bedtime_outlined,
              ayurvedaHint: total < 6 ? 'Vata ↑' : total > 9 ? 'Kapha ↑' : null,
              metricKey: 'sleepHours',
              trend: Provider.of<WatchHealthProvider>(context, listen: false)
                  .metricTrend('sleepHours'),
              info: getMetricInfo('sleepHours'),
            ),
          ),
        );
      },
      child: AyurvedaCardContainer(
        isDark: isDark,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Text(
                  'Nidra · Sleep',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: c,
                  ),
                ),
                const Spacer(),
                Text(
                  '${total.toStringAsFixed(1)} hrs',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  CupertinoIcons.chevron_right,
                  size: 14,
                  color: isDark ? Colors.white24 : Colors.black26,
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingLg),

            // Stacked bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 12,
              child: Row(
                children: [
                  if (deep > 0)
                    Expanded(
                      flex: deep.round(),
                      child: Container(color: const Color(0xFF1A237E)),
                    ),
                  if (rem > 0)
                    Expanded(
                      flex: rem.round(),
                      child: Container(color: const Color(0xFF5C6BC0)),
                    ),
                  if (core > 0)
                    Expanded(
                      flex: core.round(),
                      child: Container(color: const Color(0xFF9FA8DA)),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.spacingMd),

          // Legend
          Row(
            children: [
              _legendDot('Deep', const Color(0xFF1A237E), '${deep.round()}m'),
              const SizedBox(width: 16),
              _legendDot('REM', const Color(0xFF5C6BC0), '${rem.round()}m'),
              const SizedBox(width: 16),
              _legendDot('Core', const Color(0xFF9FA8DA), '${core.round()}m'),
            ],
          ),

          const SizedBox(height: AppDimensions.spacingMd),

          // Quality assessment
          Text(
            _sleepQuality(total, deep, rem),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white54 : Colors.black45,
            ),
          ),
        ],
        ),
      ),
    );
  }

  Widget _legendDot(String label, Color color, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '$label $value',
          style: TextStyle(
            fontSize: 11,
            color: isDark ? Colors.white54 : Colors.black54,
          ),
        ),
      ],
    );
  }

  String _sleepQuality(double hours, double deep, double rem) {
    if (hours >= 7 && deep >= 60 && rem >= 90) return '🌿 Restorative · Deep rest achieved';
    if (hours >= 6 && deep >= 30) return '🌙 Adequate · Decent rest';
    if (hours >= 4) return '⚡ Light · Could use more rest';
    return '🔥 Depleted · Recovery needed';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Internal Data Model
// ─────────────────────────────────────────────────────────────────────────────

class _SignalData {
  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final String status;
  final Color statusColor;
  final String? ayurvedaHint;
  final String? metricKey;

  const _SignalData({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.status,
    required this.statusColor,
    this.ayurvedaHint,
    this.metricKey,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Painters
// ─────────────────────────────────────────────────────────────────────────────

/// Arc painter for Ojas gauge.
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
    final radius = size.width / 2 - 10;
    const startAngle = math.pi * 0.7;
    const sweepAngle = math.pi * 1.6;

    // Track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      trackPaint,
    );

    // Fill
    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle * fraction,
      false,
      fillPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _OjasArcPainter old) =>
      old.fraction != fraction || old.color != color;
}

/// Sparkline painter for trend data.
class _SparklinePainter extends CustomPainter {
  final List<double> data;
  final Color color;
  final double fillOpacity;

  _SparklinePainter({
    required this.data,
    required this.color,
    this.fillOpacity = 0.2,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;

    final minVal = data.reduce(math.min);
    final maxVal = data.reduce(math.max);
    final range = maxVal - minVal;
    if (range == 0) return;

    final points = <Offset>[];
    for (int i = 0; i < data.length; i++) {
      final x = (i / (data.length - 1)) * size.width;
      final y = size.height - ((data[i] - minVal) / range) * size.height;
      points.add(Offset(x, y));
    }

    // Fill
    final fillPath = Path()..moveTo(points.first.dx, size.height);
    for (final p in points) {
      fillPath.lineTo(p.dx, p.dy);
    }
    fillPath.lineTo(points.last.dx, size.height);
    fillPath.close();

    canvas.drawPath(
      fillPath,
      Paint()..color = color.withValues(alpha: fillOpacity),
    );

    // Line
    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      linePath.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(
      linePath,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );

    // End dot
    canvas.drawCircle(
      points.last,
      3,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter old) =>
      old.data != data || old.color != color;
}
