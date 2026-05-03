import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/shared/providers/watch_health_provider.dart';
import 'package:aurogram/features/ayurveda/presentation/widgets/ayurveda_theme.dart';
import 'package:aurogram/features/ayurveda/presentation/pages/metric_info.dart';
import 'package:aurogram/features/ayurveda/presentation/pages/trend_chart_painters.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SignalDetailPage — Granular health metric drill-down
// ─────────────────────────────────────────────────────────────────────────────

/// Drill-down page for a single health metric.
/// Loads granular timestamped data from LocalStore and shows:
///   - Hero value card with current reading
///   - Time range selector (Today / 3D / 7D)
///   - Granular trend chart with real timestamps on x-axis
///   - Stats row (min / avg / max)
///   - Normal ranges & explanations
class SignalDetailPage extends StatefulWidget {
  final String label;
  final String value;
  final String unit;
  final String status;
  final Color statusColor;
  final IconData icon;
  final String? ayurvedaHint;
  final String? metricKey;
  /// Legacy fallback: flat values without timestamps.
  final List<double>? trend;
  final MetricInfo info;

  const SignalDetailPage({
    super.key,
    required this.label,
    required this.value,
    required this.unit,
    required this.status,
    required this.statusColor,
    required this.icon,
    this.ayurvedaHint,
    this.metricKey,
    this.trend,
    required this.info,
  });

  @override
  State<SignalDetailPage> createState() => _SignalDetailPageState();
}

class _SignalDetailPageState extends State<SignalDetailPage> {
  /// Selected time range index: 0=Today, 1=3 Days, 2=7 Days.
  int _rangeIndex = 2;
  static const _rangeDays = [1, 3, 7];
  static const _rangeLabels = ['Today', '3 Days', '7 Days'];

  List<TimedValue> _timeSeries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTimeSeries();
  }

  Future<void> _loadTimeSeries() async {
    if (widget.metricKey == null) {
      setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = true);

    final provider = context.read<WatchHealthProvider>();
    final days = _rangeDays[_rangeIndex];
    final data = await provider.metricTimeSeries(
      widget.metricKey!,
      days: days,
    );

    if (mounted) {
      setState(() {
        _timeSeries = data;
        _isLoading = false;
      });
    }
  }

  void _onRangeChanged(int index) {
    if (index == _rangeIndex) return;
    setState(() => _rangeIndex = index);
    _loadTimeSeries();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = AppTheme.primaryColor;
    final hasTimeSeries = _timeSeries.length >= 2;

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
          widget.label,
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
            // ── Hero value card ───────────────────────────────
            _buildHeroCard(isDark),

            // ── Time range selector ──────────────────────────
            const SizedBox(height: 16),
            _buildRangeSelector(isDark),

            // ── Granular trend chart ─────────────────────────
            const SizedBox(height: 12),
            _buildTrendCard(isDark, hasTimeSeries),

            // ── Stats row (min / avg / max) ──────────────────
            if (hasTimeSeries) ...[
              const SizedBox(height: 12),
              _buildStatsRow(isDark),
            ],

            // ── Normal ranges ────────────────────────────────
            const SizedBox(height: 12),
            _buildNormalRanges(isDark),

            // ── What it means ────────────────────────────────
            const SizedBox(height: 12),
            _buildExplanation(isDark),

            // ── Ayurvedic perspective ────────────────────────
            const SizedBox(height: 12),
            _buildAyurvedicView(isDark),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ── Hero Card ──────────────────────────────────────────────────────────

  Widget _buildHeroCard(bool isDark) {
    return DetailCard(
      isDark: isDark,
      child: Column(
        children: [
          Icon(widget.icon, size: 28,
              color: widget.statusColor.withValues(alpha: 0.6)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                widget.value,
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black87,
                  height: 1,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                widget.unit,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: widget.statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              widget.status,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: widget.statusColor,
              ),
            ),
          ),
          if (widget.ayurvedaHint != null) ...[
            const SizedBox(height: 6),
            Text(
              widget.ayurvedaHint!,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: getDoshaColor(
                  widget.ayurvedaHint!.contains('Vata')
                      ? 'vata'
                      : widget.ayurvedaHint!.contains('Pitta')
                          ? 'pitta'
                          : 'kapha',
                ).withValues(alpha: 0.7),
              ),
            ),
          ],
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
                      ? (isDark ? Colors.white.withValues(alpha: 0.12)
                                : Colors.white)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: isSelected
                      ? [BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        )]
                      : null,
                ),
                child: Text(
                  _rangeLabels[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
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

  // ── Trend Chart Card ───────────────────────────────────────────────────

  Widget _buildTrendCard(bool isDark, bool hasTimeSeries) {
    if (_isLoading) {
      return DetailCard(
        isDark: isDark,
        child: const SizedBox(
          height: 160,
          child: Center(child: CupertinoActivityIndicator()),
        ),
      );
    }

    // Use timestamped data if available, fall back to legacy flat trend
    if (hasTimeSeries) {
      return _buildTimestampedChart(isDark);
    }

    // Fallback: legacy flat trend (no timestamps)
    if (widget.trend != null && widget.trend!.length >= 2) {
      return _buildLegacyChart(isDark);
    }

    return DetailCard(
      isDark: isDark,
      child: SizedBox(
        height: 80,
        child: Center(
          child: Text(
            'No trend data yet — wear your watch for a day',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white30 : Colors.black26,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildTimestampedChart(bool isDark) {
    final dataPoints = _timeSeries.length;
    final rangeLabel = _rangeLabels[_rangeIndex];

    return DetailCard(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '$rangeLabel Trend',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
              ),
              const Spacer(),
              // Data point count badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: widget.statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$dataPoints readings',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: widget.statusColor.withValues(alpha: 0.7),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _trendDirectionFromTimeSeries(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: widget.statusColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // The chart
          SizedBox(
            height: 140,
            child: CustomPaint(
              size: const Size(double.infinity, 140),
              painter: TimestampedTrendPainter(
                data: _timeSeries,
                lineColor: widget.statusColor,
                fillColor: widget.statusColor.withValues(alpha: 0.08),
                dotColor: widget.statusColor,
                gridColor: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.06),
                labelColor: isDark
                    ? Colors.white.withValues(alpha: 0.35)
                    : Colors.black.withValues(alpha: 0.35),
                isDark: isDark,
                showDayBoundaries: _rangeDays[_rangeIndex] > 1,
              ),
            ),
          ),
          const SizedBox(height: 6),
          // Time labels
          _buildTimeLabels(isDark),
        ],
      ),
    );
  }

  Widget _buildTimeLabels(bool isDark) {
    if (_timeSeries.isEmpty) return const SizedBox.shrink();

    final days = _rangeDays[_rangeIndex];
    final labelColor = isDark ? Colors.white24 : Colors.black26;
    final labelStyle = TextStyle(fontSize: 9, color: labelColor);

    if (days == 1) {
      // Today: show hour labels (6am, 12pm, 6pm, etc.)
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('12am', style: labelStyle),
          Text('6am', style: labelStyle),
          Text('12pm', style: labelStyle),
          Text('6pm', style: labelStyle),
          Text('Now', style: labelStyle),
        ],
      );
    }

    // Multi-day: show date labels
    final first = _timeSeries.first.time;
    final last = _timeSeries.last.time;
    final totalDuration = last.difference(first);
    final stepCount = math.min(days + 1, 5);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(stepCount, (i) {
        final fraction = i / (stepCount - 1);
        final date = first.add(totalDuration * fraction);
        return Text(
          _formatDateLabel(date, days),
          style: labelStyle,
        );
      }),
    );
  }

  String _formatDateLabel(DateTime date, int rangeDays) {
    final months = ['', 'Jan','Feb','Mar','Apr','May','Jun',
                     'Jul','Aug','Sep','Oct','Nov','Dec'];
    if (rangeDays <= 3) {
      return '${months[date.month]} ${date.day}\n${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    }
    return '${months[date.month]} ${date.day}';
  }

  Widget _buildLegacyChart(bool isDark) {
    return DetailCard(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '7-Day Trend',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
              ),
              const Spacer(),
              Text(
                _trendDirection(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: widget.statusColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 120,
            child: CustomPaint(
              size: const Size(double.infinity, 120),
              painter: TrendChartPainter(
                data: widget.trend!,
                lineColor: widget.statusColor,
                fillColor: widget.statusColor.withValues(alpha: 0.08),
                dotColor: widget.statusColor,
                gridColor: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.06),
                isDark: isDark,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(
              widget.trend!.length.clamp(0, 7),
              (i) {
                final daysAgo = widget.trend!.length - 1 - i;
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
        ],
      ),
    );
  }

  // ── Stats Row ──────────────────────────────────────────────────────────

  Widget _buildStatsRow(bool isDark) {
    final values = _timeSeries.map((t) => t.value).toList();
    final minVal = values.reduce(math.min);
    final maxVal = values.reduce(math.max);
    final avgVal = values.reduce((a, b) => a + b) / values.length;

    return Row(
      children: [
        _StatChip(label: 'Min', value: _formatStat(minVal),
            isDark: isDark, color: vataColor),
        const SizedBox(width: 8),
        _StatChip(label: 'Avg', value: _formatStat(avgVal),
            isDark: isDark, color: AppTheme.primaryColor),
        const SizedBox(width: 8),
        _StatChip(label: 'Max', value: _formatStat(maxVal),
            isDark: isDark, color: pittaColor),
      ],
    );
  }

  String _formatStat(double v) {
    if (v == v.roundToDouble()) return '${v.round()}';
    return v.toStringAsFixed(1);
  }

  // ── Normal Ranges ──────────────────────────────────────────────────────

  Widget _buildNormalRanges(bool isDark) {
    return DetailCard(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Normal Ranges',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white54 : Colors.black45,
            ),
          ),
          const SizedBox(height: 10),
          ...widget.info.ranges.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Container(
                      width: 8, height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle, color: r.color,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      r.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      r.range,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  // ── Explanation ────────────────────────────────────────────────────────

  Widget _buildExplanation(bool isDark) {
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
            widget.info.explanation,
            style: TextStyle(
              fontSize: 14, height: 1.5,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  // ── Ayurvedic View ─────────────────────────────────────────────────────

  Widget _buildAyurvedicView(bool isDark) {
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
            widget.info.ayurvedicNote,
            style: TextStyle(
              fontSize: 14, height: 1.5,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────

  String _trendDirection() {
    if (widget.trend == null || widget.trend!.length < 2) return '';
    final diff = widget.trend!.last - widget.trend!.first;
    if (diff.abs() < 0.5) return '→ Stable';
    return diff > 0 ? '↑ Rising' : '↓ Falling';
  }

  String _trendDirectionFromTimeSeries() {
    if (_timeSeries.length < 2) return '';
    final diff = _timeSeries.last.value - _timeSeries.first.value;
    if (diff.abs() < 0.5) return '→ Stable';
    return diff > 0 ? '↑ Rising' : '↓ Falling';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _StatChip — Min/Avg/Max display
// ─────────────────────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;
  final Color color;

  const _StatChip({
    required this.label,
    required this.value,
    required this.isDark,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.04)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.grey.shade200,
          ),
        ),
        child: Column(
          children: [
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: isDark ? Colors.white30 : Colors.black26,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
