import re

content = """import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../domain/models/prakriti_model.dart';
import '../../domain/models/vikriti_model.dart';

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
    // Ultra minimal, strictly monochrome chic palette - no borders, no boxes, no glow
    final bg = isDark ? Colors.black : Colors.white;
    final fgMain = isDark ? Colors.white : Colors.black87;
    final fgMuted = isDark ? Colors.white54 : Colors.black54;
    final fgFaint = isDark ? Colors.white24 : Colors.black26;
    final lineCol = isDark ? Colors.white12 : Colors.black12;
    
    final hasVikriti = vikriti != null;

    return Container(
      width: double.infinity,
      color: bg,
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isCalculating)
            _buildLoadingState(fgMain, fgMuted)
          else if (!hasVikriti)
            _buildNoDataState(fgMain, fgMuted)
          else
            _buildChicContent(fgMain, fgMuted, fgFaint, lineCol),
        ],
      ),
    );
  }

  Widget _buildLoadingState(Color fgMain, Color fgMuted) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Analyzing.',
          style: TextStyle(
            color: fgMain,
            fontSize: 24,
            fontWeight: FontWeight.w300,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 32),
        SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 1.5, color: fgMuted)),
      ],
    );
  }

  Widget _buildNoDataState(Color fgMain, Color fgMuted) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Unrecorded.',
          style: TextStyle(
            color: fgMain,
            fontSize: 24,
            fontWeight: FontWeight.w300,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Tap to log your current mind and body alignment.',
          style: TextStyle(
            color: fgMuted,
            fontSize: 13,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildChicContent(Color fgMain, Color fgMuted, Color fgFaint, Color lineCol) {
    String stateTitle = 'Perfectly aligned.';
    String dominantDosha = 'balanced';
    List<String> foodTips = ['Follow natural diet', 'Favor fresh produce'];
    List<String> doTips = ['Maintain routines', 'Observe daily balance'];

    if (vikriti!.imbalances.isNotEmpty) {
       final sorted = List<DoshaImbalance>.from(vikriti!.imbalances)
         ..sort((a, b) => b.shift.compareTo(a.shift));
       final top = sorted.first;
       dominantDosha = top.dosha.toLowerCase();
       
       final doshaName = '${top.dosha[0].toUpperCase()}${top.dosha.substring(1).toLowerCase()}';
       stateTitle = '$doshaName elevated.';
       
       if (dominantDosha == 'vata') {
         foodTips = ['Warm, moist meals', 'Root vegetables', 'Heavy grains', 'Warm teas'];
         doTips = ['Gentle yoga', 'Oil massage', 'Strict routine'];
       } else if (dominantDosha == 'pitta') {
         foodTips = ['Cooling foods', 'Sweet fruits', 'Leafy greens', 'Coconut'];
         doTips = ['Moonlight walks', 'Swimming', 'Avoid midday sun'];
       } else if (dominantDosha == 'kapha') {
         foodTips = ['Light, warm dishes', 'Spicy flavors', 'Clear broths', 'Bitter greens'];
         doTips = ['Vigorous exercise', 'Dry brushing', 'Early rising'];
       }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Hero Text & Sigil
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              stateTitle,
              style: TextStyle(
                color: fgMain,
                fontSize: 26,
                fontWeight: FontWeight.w300,
                letterSpacing: -0.5,
              ),
            ),
            Row(
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CustomPaint(
                    painter: _DoshaSigilPainter(dosha: dominantDosha, color: fgMain),
                  ),
                ),
                if (onInfo != null)
                  GestureDetector(
                    onTap: onInfo,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 16.0),
                      child: Icon(Icons.info_outline, size: 18, color: fgMuted),
                    ),
                  ),
              ],
            ),
          ],
        ),
        
        const SizedBox(height: 48),
        
        // Header Row for Data
        Row(
          children: [
            SizedBox(
              width: 50,
              child: Text('DOSHA', style: _labelStyle(fgFaint)),
            ),
            Expanded(child: SizedBox()),
            SizedBox(
              width: 45,
              child: Text('CUR', textAlign: TextAlign.right, style: _labelStyle(fgFaint)),
            ),
            SizedBox(
              width: 45,
              child: Text('SHIFT', textAlign: TextAlign.right, style: _labelStyle(fgFaint)),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Data Rows - sharp, geometric
        _buildDataRow('Vata', prakriti.vata, vikriti!.vata, fgMain, fgMuted, lineCol),
        const SizedBox(height: 20),
        _buildDataRow('Pitta', prakriti.pitta, vikriti!.pitta, fgMain, fgMuted, lineCol),
        const SizedBox(height: 20),
        _buildDataRow('Kapha', prakriti.kapha, vikriti!.kapha, fgMain, fgMuted, lineCol),
        
        const SizedBox(height: 56),

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

  TextStyle _labelStyle(Color color) {
    return TextStyle(
      color: color,
      fontSize: 9,
      fontWeight: FontWeight.w600,
      letterSpacing: 1.5,
    );
  }

  Widget _buildDataRow(String label, int base, int cur, Color fgMain, Color fgMuted, Color lineCol) {
    final shift = cur - base;
    final shiftStr = shift > 0 ? '+$shift%' : (shift < 0 ? '$shift%' : '—');
    final shiftColor = shift > 0 ? fgMain : fgMuted;

    return Row(
      children: [
        SizedBox(
          width: 50,
          child: Text(
            label,
            style: TextStyle(
              color: fgMuted,
              fontSize: 13,
              fontWeight: FontWeight.w400,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Minimal visualizer line - sharp, no glow
        Expanded(
          child: LayoutBuilder(builder: (context, constraints) {
            final w = constraints.maxWidth;
            final bX = w * (base / 100).clamp(0.0, 1.0);
            final cX = w * (cur / 100).clamp(0.0, 1.0);
            
            return SizedBox(
              height: 12,
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  Container(height: 1, width: w, color: lineCol),
                  // Baseline constant
                  Positioned(
                    left: bX,
                    child: Container(width: 1, height: 8, color: fgMuted),
                  ),
                  // Current diamond marker
                  Positioned(
                    left: cX - 3,
                    child: Transform.rotate(
                      angle: 45 * math.pi / 180,
                      child: Container(
                        width: 6, 
                        height: 6, 
                        color: fgMain,
                      ),
                    ),
                  )
                ],
              ),
            );
          }),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 45,
          child: Text(
            '$cur%',
            textAlign: TextAlign.right,
            style: TextStyle(
              color: fgMain,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        SizedBox(
          width: 45,
          child: Text(
            shiftStr,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: shiftColor,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
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
                    fontFamily: 'Georgia', // Fallback serif
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
                    maxLines: 1,
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
}

class _DoshaSigilPainter extends CustomPainter {
  final String dosha;
  final Color color;

  _DoshaSigilPainter({required this.dosha, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;

    final w = size.width;
    final h = size.height;

    if (dosha == 'pitta') {
      // Triangle (Fire)
      final path = Path()
        ..moveTo(w / 2, 2)
        ..lineTo(w - 2, h - 2)
        ..lineTo(2, h - 2)
        ..close();
      canvas.drawPath(path, paint);
    } else if (dosha == 'kapha') {
      // Square/Earth or Circle/Water. Let's do a sharp square.
      canvas.drawRect(Rect.fromLTWH(3, 3, w - 6, h - 6), paint);
    } else if (dosha == 'vata') {
      // Diamond / Space
      final path = Path()
        ..moveTo(w / 2, 2)
        ..lineTo(w - 2, h / 2)
        ..lineTo(w / 2, h - 2)
        ..lineTo(2, h / 2)
        ..close();
      canvas.drawPath(path, paint);
    } else {
      // Balanced: Perfect circle
      canvas.drawCircle(Offset(w / 2, h / 2), w / 2 - 2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DoshaSigilPainter oldDelegate) => 
      oldDelegate.dosha != dosha || oldDelegate.color != color;
}
"""

with open('lib/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart', 'w') as f:
    f.write(content)

