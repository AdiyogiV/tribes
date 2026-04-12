import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:aurogram/shared/models/watch_health_data.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';
import 'package:aurogram/features/ayurveda/presentation/widgets/ayurveda_theme.dart';

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
    final score = data.ojasScore;
    if (score == null) return const SizedBox.shrink();

    final scoreInt = score.round();
    final fraction = (score / 100).clamp(0.0, 1.0);

    return AyurvedaCardContainer(
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
                        data.ojasSummary ?? _ojasLabel(score),
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

          // Agni + Nadi badges
          if (data.agniType != null || data.nadiDosha != null) ...[
            const SizedBox(height: AppDimensions.spacingMd),
            Row(
              children: [
                if (data.agniType != null)
                  _buildBadge(
                    '🔥 ${_agniLabel(data.agniType!)}',
                    isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade50,
                    isDark ? Colors.white60 : Colors.black54,
                  ),
                if (data.agniType != null && data.nadiDosha != null)
                  const SizedBox(width: 8),
                if (data.nadiDosha != null)
                  _buildBadge(
                    '${_nadiGlyph(data.nadiDosha!)} ${capitalize(data.nadiDosha!)} Nadi',
                    getDoshaColor(data.nadiDosha!).withValues(alpha: 0.1),
                    getDoshaColor(data.nadiDosha!),
                  ),
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
    );
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
// BodySignalsCard — All watch sensor data in compact rows
// ─────────────────────────────────────────────────────────────────────────────

class BodySignalsCard extends StatefulWidget {
  final WatchHealthData data;
  final bool isDark;

  const BodySignalsCard({
    super.key,
    required this.data,
    required this.isDark,
  });

  @override
  State<BodySignalsCard> createState() => _BodySignalsCardState();
}

class _BodySignalsCardState extends State<BodySignalsCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.primaryColor;
    final signals = _buildSignalList();
    if (signals.isEmpty) return const SizedBox.shrink();

    // Show first 4 by default, rest on expand
    final visibleCount = _expanded ? signals.length : signals.length.clamp(0, 4);

    return AyurvedaCardContainer(
      isDark: widget.isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Text(
                'Body Signals',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: c,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: widget.isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                ),
                child: Text(
                  '${signals.length} active',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: widget.isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacingMd),

          // Signal rows
          ...signals.take(visibleCount).map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _SignalRow(
                  icon: s.icon,
                  label: s.label,
                  value: s.value,
                  unit: s.unit,
                  status: s.status,
                  statusColor: s.statusColor,
                  ayurvedaHint: s.ayurvedaHint,
                  isDark: widget.isDark,
                ),
              )),

          // Expand/collapse
          if (signals.length > 4)
            GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: widget.isDark
                      ? Colors.white.withValues(alpha: 0.03)
                      : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMdSm),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _expanded
                          ? 'Show less'
                          : 'Show ${signals.length - 4} more',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: c.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _expanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: 16,
                      color: c.withValues(alpha: 0.7),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<_SignalData> _buildSignalList() {
    final d = widget.data;
    final list = <_SignalData>[];

    // Heart
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
        ayurvedaHint: v < 6 ? 'Vata ↑' : v > 9 ? 'Kapha ↑' : null,
      ));
    }
    if (d.deepSleepMins != null) {
      final v = d.deepSleepMins!;
      list.add(_SignalData(
        icon: Icons.nights_stay_outlined,
        label: 'Deep Sleep',
        value: '${v.round()}',
        unit: 'min',
        status: v >= 60 ? 'Good' : v >= 30 ? 'Fair' : 'Low',
        statusColor: v >= 60 ? kaphaColor : v >= 30 ? Colors.amber.shade600 : pittaColor,
      ));
    }
    if (d.remSleepMins != null) {
      final v = d.remSleepMins!;
      list.add(_SignalData(
        icon: Icons.remove_red_eye_outlined,
        label: 'REM Sleep',
        value: '${v.round()}',
        unit: 'min',
        status: v >= 90 ? 'Good' : v >= 45 ? 'Fair' : 'Low',
        statusColor: v >= 90 ? kaphaColor : v >= 45 ? Colors.amber.shade600 : pittaColor,
      ));
    }

    // Breath & Oxygen
    if (d.spO2 != null) {
      final pct = d.normalizedSpO2!;
      list.add(_SignalData(
        icon: Icons.air,
        label: 'Blood Oxygen',
        value: '${pct.round()}',
        unit: '%',
        status: pct >= 95 ? 'Normal' : pct >= 92 ? 'Fair' : 'Low',
        statusColor: pct >= 95 ? kaphaColor : pct >= 92 ? Colors.amber.shade600 : pittaColor,
        ayurvedaHint: pct < 94 ? 'Kapha ↑' : null,
      ));
    }
    if (d.respRate != null) {
      final v = d.respRate!;
      list.add(_SignalData(
        icon: Icons.waves,
        label: 'Breath Rate',
        value: '${v.round()}',
        unit: '/min',
        status: (v >= 12 && v <= 20) ? 'Normal' : 'Elevated',
        statusColor: (v >= 12 && v <= 20) ? kaphaColor : pittaColor,
        ayurvedaHint: v > 18 ? 'Vata ↑' : null,
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
      ));
    }

    // Fitness
    if (d.vo2Max != null) {
      final v = d.vo2Max!;
      list.add(_SignalData(
        icon: Icons.directions_run,
        label: 'VO₂ Max',
        value: '${v.round()}',
        unit: 'mL/kg/min',
        status: v >= 40 ? 'Good' : v >= 30 ? 'Fair' : 'Low',
        statusColor: v >= 40 ? kaphaColor : v >= 30 ? Colors.amber.shade600 : pittaColor,
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
      ));
    }

    // Recovery
    if (d.hrRecovery != null) {
      final v = d.hrRecovery!;
      list.add(_SignalData(
        icon: Icons.restore,
        label: 'HR Recovery',
        value: '${v.round()}',
        unit: 'bpm drop',
        status: v >= 20 ? 'Good' : v >= 12 ? 'Fair' : 'Low',
        statusColor: v >= 20 ? kaphaColor : v >= 12 ? Colors.amber.shade600 : pittaColor,
      ));
    }

    // Energy & Mindful
    if (d.activeEnergy != null) {
      list.add(_SignalData(
        icon: Icons.local_fire_department_outlined,
        label: 'Active Energy',
        value: '${d.activeEnergy!.round()}',
        unit: 'kcal',
        status: d.activeEnergy! >= 300 ? 'Active' : 'Low',
        statusColor: d.activeEnergy! >= 300 ? kaphaColor : Colors.amber.shade600,
      ));
    }
    if (d.mindfulMins != null && d.mindfulMins! > 0) {
      list.add(_SignalData(
        icon: Icons.self_improvement,
        label: 'Mindful',
        value: '${d.mindfulMins!.round()}',
        unit: 'min',
        status: d.mindfulMins! >= 10 ? 'Good' : 'Brief',
        statusColor: d.mindfulMins! >= 10 ? kaphaColor : Colors.amber.shade600,
      ));
    }

    return list;
  }

  String _formatSteps(int steps) {
    if (steps >= 1000) {
      return '${(steps / 1000).toStringAsFixed(1)}k';
    }
    return '$steps';
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
    if (data.nadiDosha == null && data.hrv == null) return const SizedBox.shrink();

    // Compute approximate dosha percentages from available signals
    final doshaBalance = _computeDoshaFromSignals();

    return AyurvedaCardContainer(
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
                Icons.watch,
                size: 16,
                color: isDark ? Colors.white24 : Colors.black26,
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacingMd),

          // Nadi type
          if (data.nadiDosha != null) ...[
            Row(
              children: [
                Text(
                  _nadiGlyph(data.nadiDosha!),
                  style: const TextStyle(fontSize: 24),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${capitalize(data.nadiDosha!)} Nadi',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: getDoshaColor(data.nadiDosha!),
                      ),
                    ),
                    Text(
                      _nadiDescription(data.nadiDosha!),
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingLg),
          ],

          // Dosha balance bars (from watch signals)
          _buildDoshaBar('Vata', doshaBalance['vata']!, vataColor),
          const SizedBox(height: 8),
          _buildDoshaBar('Pitta', doshaBalance['pitta']!, pittaColor),
          const SizedBox(height: 8),
          _buildDoshaBar('Kapha', doshaBalance['kapha']!, kaphaColor),

          const SizedBox(height: AppDimensions.spacingMd),

          // Source note
          Text(
            'Derived from HRV, heart rate, temperature & activity patterns',
            style: TextStyle(
              fontSize: 10,
              fontStyle: FontStyle.italic,
              color: isDark ? Colors.white24 : Colors.black26,
            ),
          ),
        ],
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

  /// Approximate dosha balance from watch health signals.
  /// Mirrors the VikritiView.swift logic on the watch.
  Map<String, double> _computeDoshaFromSignals() {
    double vata = 33, pitta = 33, kapha = 34;

    if (data.hrv != null) {
      if (data.hrv! > 60) {
        vata += 8;
        pitta -= 3;
        kapha -= 5;
      } else if (data.hrv! < 25) {
        kapha += 6;
        vata -= 3;
        pitta -= 3;
      }
    }

    if (data.restingHR != null) {
      if (data.restingHR! > 75) {
        pitta += 5;
        vata += 3;
        kapha -= 5;
      } else if (data.restingHR! < 55) {
        kapha += 5;
        pitta -= 3;
      }
    }

    if (data.wristTemp != null) {
      if (data.wristTemp! > 0.3) {
        pitta += 6;
        vata -= 2;
      } else if (data.wristTemp! < -0.3) {
        vata += 5;
        kapha += 2;
        pitta -= 4;
      }
    }

    if (data.sleepHours != null) {
      if (data.sleepHours! < 6) {
        vata += 6;
        pitta += 3;
        kapha -= 5;
      } else if (data.sleepHours! > 9) {
        kapha += 8;
        vata -= 4;
        pitta -= 2;
      }
    }

    if (data.respRate != null) {
      if (data.respRate! > 18) {
        vata += 4;
        kapha -= 2;
      } else if (data.respRate! < 12) {
        kapha += 3;
      }
    }

    if (data.normalizedSpO2 != null) {
      if (data.normalizedSpO2! < 94) {
        kapha += 4;
        vata += 2;
      }
    }

    if (data.steps != null) {
      if (data.steps! < 2000) {
        kapha += 5;
        vata -= 2;
      } else if (data.steps! > 15000) {
        vata += 4;
        kapha -= 3;
      }
    }

    // Normalize
    final total = [vata, pitta, kapha].reduce((a, b) => a + b);
    if (total > 0) {
      vata = (vata / total) * 100;
      pitta = (pitta / total) * 100;
      kapha = (kapha / total) * 100;
    }

    return {'vata': vata, 'pitta': pitta, 'kapha': kapha};
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

  String _nadiDescription(String dosha) {
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

    return AyurvedaCardContainer(
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
                  color: total >= 7 ? kaphaColor : total >= 5 ? Colors.amber.shade600 : pittaColor,
                ),
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

          // Quality word
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
// Internal Widgets & Painters
// ─────────────────────────────────────────────────────────────────────────────

class _SignalData {
  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final String status;
  final Color statusColor;
  final String? ayurvedaHint;

  const _SignalData({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.status,
    required this.statusColor,
    this.ayurvedaHint,
  });
}

class _SignalRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final String status;
  final Color statusColor;
  final String? ayurvedaHint;
  final bool isDark;

  const _SignalRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.status,
    required this.statusColor,
    this.ayurvedaHint,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: statusColor.withValues(alpha: 0.7),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              if (ayurvedaHint != null)
                Text(
                  ayurvedaHint!,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: getDoshaColor(
                      ayurvedaHint!.contains('Vata')
                          ? 'vata'
                          : ayurvedaHint!.contains('Pitta')
                              ? 'pitta'
                              : 'kapha',
                    ).withValues(alpha: 0.6),
                  ),
                ),
            ],
          ),
        ),
        Text(
          '$value $unit',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            fontFamily: 'monospace',
            color: isDark ? Colors.white.withValues(alpha: 0.85) : Colors.black87,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            status,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: statusColor,
            ),
          ),
        ),
      ],
    );
  }
}

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
