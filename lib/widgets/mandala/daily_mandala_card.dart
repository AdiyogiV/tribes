import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:aurogram/shared/models/astrology_profile.dart';
import 'package:aurogram/shared/models/ayurveda_profile.dart';
import 'package:aurogram/shared/models/daily_insight.dart';
import 'package:aurogram/features/ayurveda/domain/ayurveda_service.dart';
import 'package:aurogram/features/astrology/domain/sky_positions_service.dart';
import 'package:aurogram/features/astrology/data/utils/astrology_formatters.dart';
import 'package:aurogram/core/theme/app_theme.dart';

/// Daily Mandala card - 5-section pie with interactive rotation.
class DailyMandalaCard extends StatefulWidget {
  final DailyInsight? insight;
  final AstrologyProfile? astrologyProfile;
  final AyurvedaProfile? ayurvedaProfile;
  final VoidCallback? onCosmicTap;
  final VoidCallback? onWellnessTap;
  final VoidCallback? onRitualTap;
  final VoidCallback? onMindfulTap;
  final VoidCallback? onResonanceTap;
  final VoidCallback? onShareTap;

  const DailyMandalaCard({
    super.key,
    required this.insight,
    required this.astrologyProfile,
    required this.ayurvedaProfile,
    this.onCosmicTap,
    this.onWellnessTap,
    this.onRitualTap,
    this.onMindfulTap,
    this.onResonanceTap,
    this.onShareTap,
  });

  @override
  State<DailyMandalaCard> createState() => _DailyMandalaCardState();
}

class _DailyMandalaCardState extends State<DailyMandalaCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _introController;
  double _manualRotation = 0.0; // Manual rotation in radians
  bool _introComplete = false;
  Offset? _lastPointerPosition;
  bool _isRotating = false;

  // High sensitivity multiplier for frictionless feel
  static const double _rotationSensitivity = 5.0;

  @override
  void initState() {
    super.initState();
    // Initial intro animation - fast multiple rotations
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // Play intro animation once, then allow manual control
    _introController.forward().then((_) {
      if (mounted) {
        setState(() => _introComplete = true);
      }
    });
  }

  @override
  void dispose() {
    _introController.dispose();
    super.dispose();
  }

  void _onPointerDown(PointerDownEvent event, Offset center, double radius) {
    if (!_introComplete) return;

    // Check if touch is within the mandala circle
    final distance = (event.localPosition - center).distance;
    if (distance <= radius) {
      _isRotating = true;
      _lastPointerPosition = event.localPosition;
      HapticFeedback.lightImpact();
    }
  }

  void _onPointerMove(PointerMoveEvent event, Offset center) {
    if (!_introComplete || !_isRotating || _lastPointerPosition == null) return;

    final currentPosition = event.localPosition;

    // Calculate angles from center
    final currentAngle = math.atan2(
      currentPosition.dy - center.dy,
      currentPosition.dx - center.dx,
    );
    final previousAngle = math.atan2(
      _lastPointerPosition!.dy - center.dy,
      _lastPointerPosition!.dx - center.dx,
    );

    // Update rotation with high sensitivity for frictionless feel
    final delta = currentAngle - previousAngle;
    final newRotation = _manualRotation + delta * _rotationSensitivity;
    _lastPointerPosition = currentPosition;
    
    // CRITICAL: Defer setState to avoid re-entrant mouse tracker updates on web
    // Calling setState directly in pointer callbacks causes assertion failures
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _isRotating) {
        setState(() {
          _manualRotation = newRotation;
        });
      }
    });
  }

  void _onPointerUp(PointerUpEvent event) {
    _isRotating = false;
    _lastPointerPosition = null;
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _isRotating = false;
    _lastPointerPosition = null;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ayurvedaService = AyurvedaService();
    final skyService = SkyPositionsService();
    final doshaPeriod = ayurvedaService.getCurrentDoshaPeriod();
    final dominantDosha = widget.ayurvedaProfile?.prakriti?.highestDosha ??
        doshaPeriod['dosha'] as String? ??
        'vata';
    final ritual = _ritualByDosha[dominantDosha] ?? _ritualFallback;
    final dailyTheme = widget.insight?.displayTheme ?? 'Cosmic Pulse';
    final dailyMessage =
        widget.insight?.displayMessage ?? 'Move with intention';
    final wellnessTitle =
        widget.ayurvedaProfile?.prakritiType ?? _titleCase(dominantDosha);
    final wellnessNote = widget.ayurvedaProfile?.vikriti?.isBalanced == true
        ? 'Balanced today'
        : '${_titleCase(dominantDosha)} focus';

    // Cosmic data (panchang + upcoming events)
    final panchang = skyService.getTodayPanchang();
    final tithi = _extractPanchangValue(
      panchang?['tithi'] ?? panchang?['name'] ?? panchang?['tithi_name'],
    );
    final nakshatra = _extractPanchangValue(panchang?['nakshatra']);
    final yoga = _extractPanchangValue(panchang?['yoga']);
    final karana = _extractPanchangValue(panchang?['karana']);
    final upcomingEvent = _pickUpcomingEvent(skyService.allUpcomingEvents);
    final upcomingLabel = upcomingEvent?.displayText ?? '';
    final upcomingDate = upcomingEvent?.formattedDate ?? '';

    // Muhurat timing window (best next window)
    final muhurat =
        _extractMuhuratSource(widget.astrologyProfile, widget.insight);
    final muhuratWindow = _pickMuhuratWindow(muhurat);
    final timingPrimary = muhuratWindow != null
        ? (muhuratWindow['type'] == 'inauspicious'
            ? 'Avoid ${muhuratWindow['name']}'
            : muhuratWindow['name'] as String)
        : 'Open window';
    final timingSecondary = muhuratWindow != null
        ? _formatTimeRange(
            muhuratWindow['start'] as int, muhuratWindow['end'] as int)
        : 'Anytime today';

    final tidePrimary = _shorten(
      nakshatra.isNotEmpty ? nakshatra : (tithi.isNotEmpty ? tithi : 'Tide'),
      22,
    );
    final tideSecondary = _shorten(
      _joinParts([tithi, yoga.isNotEmpty ? yoga : karana], ' · '),
      32,
    );

    // Mandala floats directly without card background
    return AspectRatio(
      aspectRatio: 1,
      child: _MandalaPieWheel(
        isDark: isDark,
        onShareTap: widget.onShareTap,
        introController: _introController,
        manualRotation: _manualRotation,
        introComplete: _introComplete,
        onPointerDown: _onPointerDown,
        onPointerMove: _onPointerMove,
        onPointerUp: _onPointerUp,
        onPointerCancel: _onPointerCancel,
        sections: [
          _SectionInfo(
            title: 'Tide',
            primary: tidePrimary,
            secondary: tideSecondary,
            color: const Color(0xFFFF9800),
          ),
          _SectionInfo(
            title: 'Signal',
            primary: _shorten(dailyTheme, 26),
            secondary: _shorten(dailyMessage, 56),
            color: const Color(0xFF7E57C2),
          ),
          _SectionInfo(
            title: 'Pulse',
            primary: _shorten(wellnessTitle, 20),
            secondary: _shorten(wellnessNote, 34),
            color: const Color(0xFF26A69A),
          ),
          _SectionInfo(
            title: 'Window',
            primary: _shorten(timingPrimary, 22),
            secondary: _shorten(timingSecondary, 30),
            color: const Color(0xFF26C6DA),
          ),
          _SectionInfo(
            title: 'Rite',
            primary: _shorten(ritual['title'] as String, 20),
            secondary: '2 min',
            color: const Color(0xFFEF6C00),
          ),
          _SectionInfo(
            title: 'Orbit',
            primary: _shorten(
              upcomingLabel.isNotEmpty ? upcomingLabel : 'Share insight',
              24,
            ),
            secondary:
                upcomingLabel.isNotEmpty ? upcomingDate : 'With your circle',
            color: const Color(0xFFE91E63),
          ),
        ],
      ),
    );
  }

  String _shorten(String text, int maxLen) {
    if (text.length <= maxLen) return text;
    return '${text.substring(0, maxLen - 3)}...';
  }

  String _joinParts(List<String> parts, String separator) {
    final filtered = parts.where((p) => p.trim().isNotEmpty).toList();
    return filtered.join(separator);
  }

  String _extractPanchangValue(dynamic value) {
    if (value == null) return '';
    if (value is Map) {
      return value['name']?.toString() ??
          value['tithi']?.toString() ??
          value['nakshatra']?.toString() ??
          value['yoga']?.toString() ??
          value['karana']?.toString() ??
          value.values.first?.toString() ??
          '';
    }
    return value.toString();
  }

  UpcomingEvent? _pickUpcomingEvent(List<UpcomingEvent> events) {
    if (events.isEmpty) return null;
    final now = DateTime.now();
    UpcomingEvent? next;
    DateTime? nextDate;
    for (final event in events) {
      final parsed = DateTime.tryParse(event.date);
      if (parsed == null) continue;
      if (parsed.isBefore(now.subtract(const Duration(days: 1)))) continue;
      if (nextDate == null || parsed.isBefore(nextDate)) {
        next = event;
        nextDate = parsed;
      }
    }
    return next ?? events.first;
  }

  String _titleCase(String value) {
    if (value.isEmpty) return value;
    return '${value[0].toUpperCase()}${value.substring(1)}';
  }

  Map<String, dynamic>? _extractMuhuratSource(
    AstrologyProfile? profile,
    DailyInsight? insight,
  ) {
    if (profile?.muhurat != null && profile!.muhurat!.isNotEmpty) {
      return profile.muhurat;
    }
    final raw = insight?.astrologicalData?['muhurat'];
    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return null;
  }

  Map<String, dynamic>? _pickMuhuratWindow(Map<String, dynamic>? muhurat) {
    if (muhurat == null || muhurat.isEmpty) return null;
    final dayData = _getTodayMuhuratDay(muhurat);
    if (dayData == null || dayData.isEmpty) return null;

    final events = _collectMuhuratEvents(dayData);
    if (events.isEmpty) return null;

    final nowMinutes = DateTime.now().hour * 60 + DateTime.now().minute;
    Map<String, dynamic>? pickNext(List<Map<String, dynamic>> list) {
      list.sort((a, b) => (a['start'] as int).compareTo(b['start'] as int));
      final upcoming = list.firstWhere(
        (e) => (e['start'] as int) >= nowMinutes,
        orElse: () => list.first,
      );
      return upcoming;
    }

    final auspicious = events.where((e) => e['type'] == 'auspicious').toList();
    if (auspicious.isNotEmpty) {
      return pickNext(auspicious);
    }
    return pickNext(events);
  }

  Map<String, dynamic>? _getTodayMuhuratDay(Map<String, dynamic> muhurat) {
    if (muhurat['days'] is Map) {
      final days = Map<String, dynamic>.from(muhurat['days'] as Map);
      final today = DateTime.now();
      final todayKey =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      final dayRaw = days[todayKey];
      if (dayRaw is Map) {
        return Map<String, dynamic>.from(dayRaw);
      }
    }
    return muhurat;
  }

  List<Map<String, dynamic>> _collectMuhuratEvents(
    Map<String, dynamic> dayData,
  ) {
    final timelineEvents = <Map<String, dynamic>>[];

    Map<String, int>? extractRange(dynamic timeData) {
      if (timeData == null) return null;
      final timeMap =
          timeData is Map ? Map<String, dynamic>.from(timeData) : null;
      if (timeMap == null) return null;
      final startsAt = timeMap['starts_at'] ?? timeMap['startsAt'];
      final endsAt = timeMap['ends_at'] ?? timeMap['endsAt'];
      if (startsAt != null && endsAt != null) {
        return {
          'start': AstrologyFormatters.parseTimeToMinutes(startsAt.toString()),
          'end': AstrologyFormatters.parseTimeToMinutes(endsAt.toString()),
        };
      }
      return null;
    }

    const inauspiciousTypes = [
      {'key': 'rahuKala', 'name': 'Rahu Kala', 'fallback': 'rahu_kala'},
      {'key': 'gulikaKala', 'name': 'Gulika Kala', 'fallback': 'gulika_kala'},
      {'key': 'yamaganda', 'name': 'Yamaganda', 'fallback': 'yamagandaKala'},
      {'key': 'varjyam', 'name': 'Varjyam', 'fallback': null},
    ];

    for (final type in inauspiciousTypes) {
      final timeData = dayData[type['key']] ??
          (type['fallback'] != null ? dayData[type['fallback']] : null);
      final range = extractRange(timeData);
      if (range != null) {
        timelineEvents.add({
          'name': type['name'] as String,
          'start': range['start']!,
          'end': range['end']!,
          'type': 'inauspicious',
        });
      }
    }

    const auspiciousTypes = [
      {'key': 'abhijit', 'name': 'Abhijit Muhurat'},
      {'key': 'amrit', 'name': 'Amrit Kaal', 'fallback': 'amritKaal'},
      {'key': 'brahmaMuhurat', 'name': 'Brahma Muhurat'},
    ];

    for (final type in auspiciousTypes) {
      final timeData = dayData[type['key']] ??
          (type['fallback'] != null ? dayData[type['fallback']] : null);
      final range = extractRange(timeData);
      if (range != null) {
        timelineEvents.add({
          'name': type['name'] as String,
          'start': range['start']!,
          'end': range['end']!,
          'type': 'auspicious',
        });
      }
    }

    return timelineEvents;
  }

  String _formatTimeRange(int startMinutes, int endMinutes) {
    final start = AstrologyFormatters.formatTimeWithAMPM(startMinutes);
    final end = AstrologyFormatters.formatTimeWithAMPM(endMinutes);
    return '$start - $end';
  }
}

class _MandalaPieWheel extends StatelessWidget {
  final bool isDark;
  final List<_SectionInfo> sections;
  final VoidCallback? onShareTap;
  final AnimationController introController;
  final double manualRotation;
  final bool introComplete;
  final void Function(PointerDownEvent, Offset, double) onPointerDown;
  final void Function(PointerMoveEvent, Offset) onPointerMove;
  final void Function(PointerUpEvent) onPointerUp;
  final void Function(PointerCancelEvent) onPointerCancel;

  const _MandalaPieWheel({
    required this.isDark,
    required this.sections,
    required this.introController,
    required this.manualRotation,
    required this.introComplete,
    required this.onPointerDown,
    required this.onPointerMove,
    required this.onPointerUp,
    required this.onPointerCancel,
    this.onShareTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.maxWidth;
        final scale = (size / 320).clamp(0.85, 1.1);
        final baseRadius = size * 0.49;
        final baseDiameter = baseRadius * 2;
        final centerRadius = size * 0.07; // Small center button
        final center = Offset(size / 2, size / 2);
        final sectionCount = sections.length;
        final sweepAngle =
            2 * math.pi / sectionCount; // 72 degrees for 5 sections

        Widget mandalaCircle = Material(
          elevation: 8,
          shadowColor: Colors.black.withValues(alpha: 0.3),
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: baseDiameter,
            height: baseDiameter,
            child: Stack(
              children: [
                // Draw pie slices
                for (int i = 0; i < sectionCount; i++)
                  _PieSlice(
                    info: sections[i],
                    startAngle:
                        -math.pi / 2 + (i * sweepAngle), // Start from top
                    sweepAngle: sweepAngle,
                    radius: baseRadius,
                    centerHoleRadius: centerRadius,
                    isDark: isDark,
                    scale: scale,
                  ),
              ],
            ),
          ),
        );

        // Use Listener for raw pointer events - doesn't compete with scroll
        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (event) => onPointerDown(event, center, baseRadius),
          onPointerMove: (event) => onPointerMove(event, center),
          onPointerUp: onPointerUp,
          onPointerCancel: onPointerCancel,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Mandala with intro animation or manual rotation
              if (!introComplete)
                AnimatedBuilder(
                  animation: introController,
                  builder: (context, child) {
                    final curved =
                        Curves.easeOutExpo.transform(introController.value);
                    return Transform.rotate(
                      angle: curved * 3 * 2 * math.pi,
                      child: child,
                    );
                  },
                  child: mandalaCircle,
                )
              else
                Transform.rotate(
                  angle: manualRotation,
                  child: mandalaCircle,
                ),
              // Static center button (doesn't rotate)
              _CenterShare(
                radius: centerRadius,
                isDark: isDark,
                onTap: onShareTap,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PieSlice extends StatelessWidget {
  final _SectionInfo info;
  final double startAngle;
  final double sweepAngle;
  final double radius;
  final double centerHoleRadius;
  final bool isDark;
  final double scale;

  const _PieSlice({
    required this.info,
    required this.startAngle,
    required this.sweepAngle,
    required this.radius,
    required this.centerHoleRadius,
    required this.isDark,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(radius * 2, radius * 2),
      painter: _PieSlicePainter(
        color: info.color,
        startAngle: startAngle,
        sweepAngle: sweepAngle,
        isDark: isDark,
        centerHoleRadius: centerHoleRadius,
      ),
      child: SizedBox(
        width: radius * 2,
        height: radius * 2,
        child: _buildLabel(),
      ),
    );
  }

  Widget _buildLabel() {
    final midAngle = startAngle + sweepAngle / 2;
    // Align text along the radius (reading from edge toward center)
    final textRotation = midAngle;

    // Position along the radius
    final outerR = radius * 0.88;
    final innerR = centerHoleRadius * 1.8;
    final labelLength = outerR - innerR;
    final midR = (outerR + innerR) / 2;

    final labelX = radius + midR * math.cos(midAngle);
    final labelY = radius + midR * math.sin(midAngle);

    // Width for text (arc width at middle radius)
    final labelWidth = midR * sweepAngle * 0.85;

    final textColor = isDark ? Colors.white : Colors.black87;

    return Stack(
      children: [
        Positioned(
          left: labelX - labelWidth / 2,
          top: labelY - labelLength / 2,
          child: Transform.rotate(
            angle: textRotation,
            child: SizedBox(
              width: labelWidth,
              height: labelLength,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Main content text (insight, etc.)
                  if (info.secondary.isNotEmpty)
                    Flexible(
                      flex: 2,
                      child: Text(
                        info.secondary,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 8 * scale,
                          fontWeight: FontWeight.w500,
                          height: 1.2,
                          color: textColor.withValues(alpha: 0.85),
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  if (info.secondary.isNotEmpty) SizedBox(height: 4 * scale),
                  // Title/theme
                  Text(
                    info.primary,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 9 * scale,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PieSlicePainter extends CustomPainter {
  final Color color;
  final double startAngle;
  final double sweepAngle;
  final bool isDark;
  final double centerHoleRadius;

  _PieSlicePainter({
    required this.color,
    required this.startAngle,
    required this.sweepAngle,
    required this.isDark,
    required this.centerHoleRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.width / 2;

    // Create pie slice path (donut shape)
    final path = Path();

    // Outer arc
    path.arcTo(
      Rect.fromCircle(center: center, radius: outerRadius),
      startAngle,
      sweepAngle,
      true,
    );

    // Line to inner arc
    final innerEndAngle = startAngle + sweepAngle;
    path.lineTo(
      center.dx + centerHoleRadius * math.cos(innerEndAngle),
      center.dy + centerHoleRadius * math.sin(innerEndAngle),
    );

    // Inner arc (reverse direction)
    path.arcTo(
      Rect.fromCircle(center: center, radius: centerHoleRadius),
      innerEndAngle,
      -sweepAngle,
      false,
    );

    path.close();

    // Gradient fill
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: isDark ? 0.35 : 0.25),
          color.withValues(alpha: isDark ? 0.15 : 0.08),
        ],
        center: Alignment.center,
        radius: 1.0,
      ).createShader(Rect.fromCircle(center: center, radius: outerRadius));

    canvas.drawPath(path, paint);

    // Subtle border between slices
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5
      ..color = color.withValues(alpha: 0.3);
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CenterShare extends StatelessWidget {
  final double radius;
  final bool isDark;
  final VoidCallback? onTap;

  const _CenterShare({
    required this.radius,
    required this.isDark,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.primaryColor;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: radius * 2,
        height: radius * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark ? const Color(0xFF2A2A2E) : Colors.white,
          border: Border.all(color: c.withValues(alpha: 0.5), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: c.withValues(alpha: 0.2),
              blurRadius: 8,
            ),
          ],
        ),
        child: Center(
          child: Icon(
            Icons.repeat_rounded, // Retweet-style icon
            size: radius * 1.1,
            color: c,
          ),
        ),
      ),
    );
  }
}

class _SectionInfo {
  final String title;
  final String primary;
  final String secondary;
  final Color color;

  const _SectionInfo({
    required this.title,
    required this.primary,
    required this.secondary,
    required this.color,
  });
}

// ─────────────────────────────────────────────────────────────
// Supporting data
// ─────────────────────────────────────────────────────────────

const Map<String, Map<String, String>> _ritualByDosha = {
  'vata': {'title': 'Ground'},
  'pitta': {'title': 'Cool'},
  'kapha': {'title': 'Energize'},
};

const Map<String, String> _ritualFallback = {'title': 'Center'};
