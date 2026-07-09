import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:aurogram/shared/models/ayurveda_profile.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/features/ayurveda/presentation/widgets/ayurveda_theme.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PrakritiHeroCard - Your permanent constitution
// ─────────────────────────────────────────────────────────────────────────────

class PrakritiHeroCard extends StatelessWidget {
  final PrakritiData prakriti;
  final bool isRefined;
  final VoidCallback onRefine;
  final VoidCallback? onInfo;
  final bool isDark;

  const PrakritiHeroCard({
    super.key,
    required this.prakriti,
    required this.isRefined,
    required this.onRefine,
    this.onInfo,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.primaryColor;

    return AyurvedaCardContainer(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Text(
                'Core Constitution',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: c,
                ),
              ),
              const Spacer(),
              if (onInfo != null)
                GestureDetector(
                  onTap: onInfo,
                  child: Icon(
                    Icons.info_outline,
                    size: 18,
                    color: isDark ? Colors.white38 : Colors.black26,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacingSmMd),

          // Type name and description
          Text(
            prakriti.type,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingXs),
          Text(
            getPrakritiDescription(prakriti.type),
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingXl),

          // Dosha bars
          _buildDoshaBar('Vata', prakriti.vata, vataColor),
          const SizedBox(height: AppDimensions.spacingMdSm),
          _buildDoshaBar('Pitta', prakriti.pitta, pittaColor),
          const SizedBox(height: AppDimensions.spacingMdSm),
          _buildDoshaBar('Kapha', prakriti.kapha, kaphaColor),
          const SizedBox(height: AppDimensions.spacingXl),

          // Refine button
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              onRefine();
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isRefined
                    ? (isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.grey.shade50)
                    : c.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppDimensions.radiusMdSm),
                border: Border.all(
                  color: isRefined
                      ? (isDark ? Colors.white12 : Colors.grey.shade200)
                      : c.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isRefined ? Icons.check_circle : Icons.tune,
                    size: 16,
                    color: isRefined ? Colors.green : c,
                  ),
                  const SizedBox(width: AppDimensions.spacingSm),
                  Text(
                    isRefined ? 'Profile Refined' : 'Personalize with Quiz',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isRefined
                          ? (isDark ? Colors.white70 : Colors.black54)
                          : c,
                    ),
                  ),
                  if (!isRefined) ...[
                    const SizedBox(width: AppDimensions.spacingXs),
                    Icon(Icons.arrow_forward_ios, size: 12, color: c),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDoshaBar(String label, int value, Color color) {
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
        const SizedBox(width: AppDimensions.spacingSm),
        Expanded(
          child: Stack(
            children: [
              // Background
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
                ),
              ),
              // Filled bar
              FractionallySizedBox(
                widthFactor: value / 100,
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppDimensions.spacingSm),
        SizedBox(
          width: 35,
          child: Text(
            '$value%',
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
}

// ─────────────────────────────────────────────────────────────────────────────
// TodaysBalanceCard - Your current state (Vikriti)
// ─────────────────────────────────────────────────────────────────────────────

class TodaysBalanceCard extends StatelessWidget {
  final PrakritiData prakriti;
  final VikritiData? vikriti;
  final bool isCalculating;
  final DateTime? lastCheckIn;
  final VoidCallback? onInfo;
  final bool isDark;

  const TodaysBalanceCard({
    super.key,
    required this.prakriti,
    this.vikriti,
    required this.isCalculating,
    this.lastCheckIn,
    this.onInfo,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    // Theme-aware minimal card: night-black in dark, clean white in light.
    final bg = isDark ? const Color(0xFF000000) : Colors.white;
    final fgMain = isDark ? Colors.white : const Color(0xFF1A1A1C);
    final fgMuted = isDark ? Colors.white54 : Colors.black54;
    final fgFaint = isDark ? Colors.white24 : Colors.black26;
    
    final hasVikriti = vikriti != null;

    return Container(
      width: double.infinity,
      color: bg,
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isCalculating)
            _buildLoadingState(fgMain, fgMuted)
          else if (!hasVikriti)
            _buildNoDataState(fgMain, fgMuted)
          else
            _buildVennContent(context, fgMain, fgMuted, fgFaint, bg),
        ],
      ),
    );
  }

  Widget _buildLoadingState(Color fgMain, Color fgMuted) {
    return Text(
      'Analyzing...',
      style: TextStyle(color: fgMain, fontSize: 24, fontFamily: 'Georgia', fontStyle: FontStyle.italic),
    );
  }

  Widget _buildNoDataState(Color fgMain, Color fgMuted) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onInfo,
      child: Text(
        'Unrecorded.\nTap to log your state.',
        style: TextStyle(color: fgMain, fontSize: 24, fontFamily: 'Georgia', fontStyle: FontStyle.italic, height: 1.4),
      ),
    );
  }

  Widget _buildVennContent(BuildContext context, Color fgMain, Color fgMuted, Color fgFaint, Color bg) {
    String dominantDosha = 'balanced';
    String doshaDisplay = '';
    String stateTitle = 'Perfectly aligned.';
    String symptomText = 'Your mind and body are in natural harmony.';
    List<String> foodTips = ['Follow natural diet', 'Favor fresh produce'];
    List<String> doTips = ['Maintain routines', 'Observe daily balance'];

    if (vikriti!.imbalances.isNotEmpty) {
      final sorted = List<DoshaImbalance>.from(vikriti!.imbalances)
        ..sort((a, b) => b.shift.compareTo(a.shift)); // Sort by highest positive shift
      final top = sorted.first;
      dominantDosha = top.dosha.toLowerCase();
      
      // If there's any notable positive shift, or the model isn't explicitly balanced
      if (top.shift > 0 || !vikriti!.isBalanced) {
        doshaDisplay = '${dominantDosha[0].toUpperCase()}${dominantDosha.substring(1)}';
        stateTitle = ' elevated.';
        
        if (dominantDosha == 'vata') {
          symptomText = 'You may feel scattered, restless, or experience dry skin and variable digestion.';
          foodTips = ['Warm, moist meals', 'Root vegetables', 'Heavy grains', 'Warm teas'];
          doTips = ['Gentle yoga', 'Oil massage', 'Strict routine'];
        } else if (dominantDosha == 'pitta') {
          symptomText = 'You may experience increased body heat, intensity, or irritability today.';
          foodTips = ['Cooling foods', 'Sweet fruits', 'Leafy greens', 'Coconut'];
          doTips = ['Moonlight walks', 'Swimming', 'Avoid midday sun'];
        } else if (dominantDosha == 'kapha') {
          symptomText = 'You may feel heavy, sluggish, or prone to holding onto water and emotions.';
          foodTips = ['Light, warm dishes', 'Spicy flavors', 'Clear broths', 'Bitter greens'];
          doTips = ['Vigorous exercise', 'Dry brushing', 'Early rising'];
        }
      }
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Heading
        doshaDisplay.isEmpty 
          ? Text(
              stateTitle,
              style: TextStyle(
                fontFamily: 'Georgia',
                fontSize: 32,
                fontStyle: FontStyle.italic,
                color: fgMain,
                letterSpacing: -1.2,
              ),
            )
          : RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: doshaDisplay,
                    style: TextStyle(
                      fontFamily: 'Georgia',
                      fontStyle: FontStyle.italic,
                      color: getDoshaColor(dominantDosha),
                      fontSize: 32,
                      letterSpacing: -1.2,
                    ),
                  ),
                  TextSpan(
                    text: stateTitle,
                    style: TextStyle(
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
          symptomText,
          style: TextStyle(
            color: fgMuted,
            fontSize: 13,
            height: 1.4,
            fontFamily: 'Georgia',
            fontStyle: FontStyle.italic,
          ),
        ),
        
        const SizedBox(height: 24),

        // Single Unified Wavy Orb + Venn Diagram Graphic
        Center(
          child: SizedBox(
            width: 260,
            height: 260,
            child: CustomPaint(
              painter: _UnifiedTrifectaPainter(
                baseVata: prakriti.vata,
                curVata: vikriti!.vata,
                colorVata: getDoshaColor('vata'),
                basePitta: prakriti.pitta,
                curPitta: vikriti!.pitta,
                colorPitta: getDoshaColor('pitta'),
                baseKapha: prakriti.kapha,
                curKapha: vikriti!.kapha,
                colorKapha: getDoshaColor('kapha'),
                fgMain: fgMain,
                fgMuted: fgMuted,
                accent: getDoshaColor(dominantDosha),
              ),
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Chic Editorial Tappable Bars
        _buildChicBar(context, 'Vata', prakriti.vata, vikriti!.vata, getDoshaColor('vata'), fgMain, fgMuted, bg),
        _buildChicBar(context, 'Pitta', prakriti.pitta, vikriti!.pitta, getDoshaColor('pitta'), fgMain, fgMuted, bg),
        _buildChicBar(context, 'Kapha', prakriti.kapha, vikriti!.kapha, getDoshaColor('kapha'), fgMain, fgMuted, bg),

        const SizedBox(height: 24),

        // Utility: Tips (Two columns with ghosted serifs)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildTipSection('F O O D', foodTips, fgMain, fgMuted, fgFaint),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: _buildTipSection('P R A C T I C E', doTips, fgMain, fgMuted, fgFaint),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTipSection(String header, List<String> items, Color fgMain, Color fgMuted, Color fgFaint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          header,
          style: TextStyle(
            color: fgMuted,
            fontSize: 9,
            fontWeight: FontWeight.w600,
            letterSpacing: 2.0,
          ),
        ),
        const SizedBox(height: 16),
        ...items.asMap().entries.map((entry) {
          final idx = entry.key + 1;
          final text = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '0$idx',
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontStyle: FontStyle.italic,
                    fontSize: 10,
                    color: fgFaint,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: fgMain,
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildChicBar(BuildContext context, String name, int baseVal, int curVal, Color col, Color fgMain, Color fgMuted, Color bg) {
    String element = '';
    String function = '';
    if (name.toLowerCase() == 'vata') {
      element = 'AIR / ETHER';
      function = 'Governs movement and communication.';
    } else if (name.toLowerCase() == 'pitta') {
      element = 'FIRE / WATER';
      function = 'Governs metabolism and transformation.';
    } else {
      element = 'EARTH / WATER';
      function = 'Governs structure and lubrication.';
    }

    final shift = curVal - baseVal;
    final shiftStr = shift > 0 ? '+$shift' : (shift < 0 ? '$shift' : '');
    final shiftColor = shift > 0 ? fgMain : (shift < 0 ? fgMuted : Colors.transparent);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.lightImpact();
        _showDoshaExplainer(context, name.toLowerCase(), fgMain, fgMuted, bg);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontStyle: FontStyle.italic,
                    fontSize: 20,
                    color: fgMain.withValues(alpha: 0.9),
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                if (shiftStr.isNotEmpty) ...[
                  Text(
                    shiftStr,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: shiftColor.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  '$curVal',
                  style: TextStyle(
                    fontWeight: FontWeight.w400,
                    fontSize: 14,
                    letterSpacing: 1.0,
                    color: fgMain.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              element,
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.0,
                color: fgMuted.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              function,
              style: TextStyle(
                fontFamily: 'Georgia',
                fontStyle: FontStyle.italic,
                fontSize: 12,
                color: fgMuted.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                final double curWidth = constraints.maxWidth * (curVal / 100.0).clamp(0.0, 1.0);
                final double baseWidth = constraints.maxWidth * (baseVal / 100.0).clamp(0.0, 1.0);
                
                return Stack(
                  alignment: Alignment.centerLeft,
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      height: 1.0,
                      width: double.infinity,
                      color: fgMuted.withValues(alpha: 0.12),
                    ),
                    Container(
                      height: 1.0,
                      width: curWidth,
                      color: col.withValues(alpha: 0.8),
                    ),
                    Positioned(
                      left: baseWidth,
                      top: -2.5,
                      child: Container(
                        height: 6.0,
                        width: 1.5,
                        color: fgMain.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDoshaExplainer(BuildContext context, String dosha, Color fgMain, Color fgMuted, Color bg) {
    String title = '';
    String element = '';
    String function = '';
    String qualities = '';
    Color accent = getDoshaColor(dosha);

    if (dosha == 'pitta') {
      title = 'Pitta';
      element = 'FIRE & WATER';
      function = 'METABOLISM & TRANSFORMATION';
      qualities = 'Hot, sharp, light, liquid, spreading. Governs digestion, absorption, assimilation, and body temperature. In balance, it brings intelligence and understanding. Out of balance, it brings anger and inflammation.';
    } else if (dosha == 'kapha') {
      title = 'Kapha';
      element = 'EARTH & WATER';
      function = 'STRUCTURE & LUBRICATION';
      qualities = 'Heavy, slow, cool, oily, smooth, dense. Governs structure, bones, joints, and fluid balance. In balance, it brings love, calmness, and forgiveness. Out of balance, it brings attachment, greed, and lethargy.';
    } else {
      title = 'Vata';
      element = 'AIR & ETHER';
      function = 'MOVEMENT & COMMUNICATION';
      qualities = 'Light, cold, dry, rough, subtle, mobile. Governs all movement in the mind and body, including blood flow, breathing, and nervous system. In balance, it promotes creativity and flexibility. Out of balance, it produces fear and anxiety.';
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          padding: const EdgeInsets.only(left: 32, right: 32, top: 32, bottom: 56),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: fgMuted.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 32,
                  fontStyle: FontStyle.italic,
                  color: accent,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                element,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 3.0,
                  color: fgMain.withValues(alpha: 0.78),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                function,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 3.0,
                  color: fgMuted,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                qualities,
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 16,
                  height: 1.6,
                  color: fgMain.withValues(alpha: 0.86),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// _UnifiedTrifectaPainter - Wavy elemental resonance orb (baseline vs current)
// ─────────────────────────────────────────────────────────────────────────────

class _UnifiedTrifectaPainter extends CustomPainter {
  final int baseVata, curVata;
  final Color colorVata;
  final int basePitta, curPitta;
  final Color colorPitta;
  final int baseKapha, curKapha;
  final Color colorKapha;
  final Color fgMain, fgMuted, accent;

  _UnifiedTrifectaPainter({
    required this.baseVata,
    required this.curVata,
    required this.colorVata,
    required this.basePitta,
    required this.curPitta,
    required this.colorPitta,
    required this.baseKapha,
    required this.curKapha,
    required this.colorKapha,
    required this.fgMain,
    required this.fgMuted,
    required this.accent,
  });

  static const double _aVata = -math.pi / 2;
  static const double _aPitta = math.pi / 6;
  static const double _aKapha = 5 * math.pi / 6;
  static const int _samples = 240;

  List<Offset> _orbPoints(double rP, double rK, double rV, double wave) {
    const tP = math.pi / 6;
    const tK = 5 * math.pi / 6;
    const tV = 3 * math.pi / 2;

    final pts = <Offset>[];
    for (int i = 0; i <= _samples; i++) {
      final t = (i / _samples) * 2 * math.pi;
      double tNorm = t % (2 * math.pi);
      if (tNorm < 0) tNorm += 2 * math.pi;

      double a0, a1, r0, r1;
      if (tNorm >= tP && tNorm < tK) {
        a0 = tP; r0 = rP; a1 = tK; r1 = rK;
      } else if (tNorm >= tK && tNorm < tV) {
        a0 = tK; r0 = rK; a1 = tV; r1 = rV;
      } else {
        a0 = tV; r0 = rV; a1 = tP + 2 * math.pi; r1 = rP;
        if (tNorm < tP) tNorm += 2 * math.pi;
      }

      final f = (tNorm - a0) / (a1 - a0);
      final smooth = 0.5 - 0.5 * math.cos(f * math.pi);
      final baseRadius = r0 + smooth * (r1 - r0);

      final wobble = math.sin(t * 3) * wave * 0.5 +
          math.cos(t * 5) * wave * 0.3 +
          math.sin(t * 7 + wave) * wave * 0.2;

      final radius = baseRadius + wobble;
      pts.add(Offset(radius * math.cos(t), radius * math.sin(t)));
    }
    return pts;
  }

  Path _pathFrom(List<Offset> pts, Offset Function(Offset) map) {
    final path = Path();
    for (int i = 0; i < pts.length; i++) {
      final p = map(pts[i]);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    return path;
  }

  // Generate a wavy circle path for the Venn shapes
  Path _wavyCirclePath(Offset center, double baseRadius, double disturbance, int seed) {
    final path = Path();
    const int samples = 120;
    for (int i = 0; i <= samples; i++) {
      final double t = (i / samples) * 2 * math.pi;
      
      // Seed phase to make each dosha's wave pattern unique
      final double p1 = seed * 1.5;
      final double p2 = seed * 2.7;

      // Disturbance multiplier: 0 means almost perfectly circular, 1.0 means highly disturbed
      final double intensity = 0.005 + (disturbance * 0.20); 

      // Organic wobble proportional to how far off baseline the dosha is
      final double wobble = math.sin(t * 4 + p1) * (baseRadius * intensity) + 
                            math.cos(t * 7 + p2) * (baseRadius * (intensity * 0.6));

      final double r = baseRadius + wobble;
      final double x = center.dx + r * math.cos(t);
      final double y = center.dy + r * math.sin(t);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  Path _dashPath(Path source, {double dashLength = 6.0, double dashGap = 6.0}) {
    final Path dest = Path();
    for (final metric in source.computeMetrics()) {
      double distance = 0.0;
      bool draw = true;
      while (distance < metric.length) {
        final double len = draw ? dashLength : dashGap;
        if (draw) {
          dest.addPath(metric.extractPath(distance, distance + len), Offset.zero);
        }
        distance += len;
        draw = !draw;
      }
    }
    return dest;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    int maxReading = [basePitta, baseKapha, baseVata, curPitta, curKapha, curVata].reduce(math.max);
    if (maxReading < 1) maxReading = 1;

    double unitR(int val) => 0.25 + 0.75 * (val / maxReading);

    final totalShift = ((curPitta - basePitta).abs() + (curKapha - baseKapha).abs() + (curVata - baseVata).abs()).toDouble();
    final curWave = (0.03 + totalShift * 0.0015).clamp(0.03, 0.12);
    const baseWave = 0.02;

    final basePts = _orbPoints(unitR(basePitta), unitR(baseKapha), unitR(baseVata), baseWave);
    final curPts = _orbPoints(unitR(curPitta), unitR(curKapha), unitR(curVata), curWave);

    final allPts = [...basePts, ...curPts];
    double minX = allPts.first.dx, maxX = allPts.first.dx;
    double minY = allPts.first.dy, maxY = allPts.first.dy;
    for (final p in allPts) {
      minX = math.min(minX, p.dx); maxX = math.max(maxX, p.dx);
      minY = math.min(minY, p.dy); maxY = math.max(maxY, p.dy);
    }

    final bboxW = (maxX - minX).clamp(0.0001, double.infinity);
    final bboxH = (maxY - minY).clamp(0.0001, double.infinity);

    const pad = 24.0;
    final scale = math.min((w - pad * 2) / bboxW, (h - pad * 2) / bboxH);

    final bboxCx = (minX + maxX) / 2;
    final bboxCy = (minY + maxY) / 2;

    Offset map(Offset p) => Offset(w / 2 + (p.dx - bboxCx) * scale, h / 2 + (p.dy - bboxCy) * scale);

    // 1. Draw current path background fill (lowest layer)
    final curPath = _pathFrom(curPts, map);
    canvas.drawPath(curPath, Paint()..color = accent.withValues(alpha: 0.10)..style = PaintingStyle.fill..isAntiAlias = true);

    // Calculate anchors moved slightly INSIDE by multiplying radius by 0.65, plus an extra 5 points inward
    Offset anchor(double angle, int val) {
      final r = math.max(0.0, (unitR(val) * 0.65) - (5.0 / scale));
      return map(Offset(r * math.cos(angle), r * math.sin(angle)));
    }

    void drawWavyVennCircle(Offset pt, Color col, String label, int curVal, int baseVal, int seed) {
      // Circle sized proportionally to its value, overall smaller than before
      final double radius = 38.0 + (curVal / maxReading) * 38.0;
      
      // Calculate how disturbed this specific dosha is from its baseline
      final double disturbance = (curVal - baseVal).abs() / maxReading.toDouble();

      final Path wavyPath = _wavyCirclePath(pt, radius, disturbance, seed);

      canvas.drawPath(
        wavyPath, 
        Paint()
          ..color = col.withValues(alpha: 0.85)
          ..style = PaintingStyle.fill
          ..isAntiAlias = true
      );

      final namePainter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            fontFamily: 'Georgia',
            fontStyle: FontStyle.italic,
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.95),
            shadows: const [Shadow(color: Colors.black45, blurRadius: 4)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final valPainter = TextPainter(
        text: TextSpan(
          text: '$curVal',
          style: TextStyle(
            fontWeight: FontWeight.w400,
            fontSize: 14,
            letterSpacing: 1.0,
            color: Colors.white.withValues(alpha: 0.95),
            shadows: const [Shadow(color: Colors.black26, blurRadius: 2)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final totalHeight = namePainter.height + 2 + valPainter.height;
      namePainter.paint(canvas, Offset(pt.dx - namePainter.width / 2, pt.dy - totalHeight / 2));
      valPainter.paint(canvas, Offset(pt.dx - valPainter.width / 2, pt.dy - totalHeight / 2 + namePainter.height + 2));
    }

    // 2. Draw the Wavy Venn Circles (they sit below the solid line)
    // Pitta, Vata, Kapha get different seeds (1, 2, 3) to randomize their wave phases
    drawWavyVennCircle(anchor(_aPitta, curPitta), colorPitta, 'Pitta', curPitta, basePitta, 1);
    drawWavyVennCircle(anchor(_aVata, curVata), colorVata, 'Vata', curVata, baseVata, 2);
    drawWavyVennCircle(anchor(_aKapha, curKapha), colorKapha, 'Kapha', curKapha, baseKapha, 3);

    // 3. Draw current path solid stroke OVER the circles
    canvas.drawPath(curPath, Paint()..color = fgMain..style = PaintingStyle.stroke..strokeWidth = 3.5..isAntiAlias = true);

    // 4. Draw base path as a dotted/dashed line on TOP of everything
    final basePathRaw = _pathFrom(basePts, map);
    final basePath = _dashPath(basePathRaw, dashLength: 5.0, dashGap: 5.0);
    canvas.drawPath(
      basePath, 
      Paint()
        ..color = fgMain.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..isAntiAlias = true
        ..strokeCap = StrokeCap.round
    );
  }

  @override
  bool shouldRepaint(covariant _UnifiedTrifectaPainter old) => true;
}
