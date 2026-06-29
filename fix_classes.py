import re

with open('lib/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart', 'r') as f:
    content = f.read()

prakriti_start = content.find('class PrakritiHeroCard extends StatelessWidget {')
todays_start = content.find('class TodaysBalanceCard extends StatelessWidget {')

# Keep everything before TodaysBalanceCard
safe_top = content[:todays_start]

todays_balance_card = """class TodaysBalanceCard extends StatelessWidget {
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
    final bg = isDark ? const Color(0xFF121212) : const Color(0xFFFAFAFA);
    final fgMain = isDark ? Colors.white : Colors.black87;
    final fgMuted = isDark ? Colors.white54 : Colors.black54;
    final fgFaint = isDark ? Colors.white24 : Colors.black26;
    
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
            _buildChicContent(context, fgMain, fgMuted, fgFaint, bg),
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
        SizedBox(
          width: 20, 
          height: 20, 
          child: CircularProgressIndicator(strokeWidth: 1.5, color: fgMuted)
        ),
      ],
    );
  }

  Widget _buildNoDataState(Color fgMain, Color fgMuted) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onInfo,
      child: Column(
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
      ),
    );
  }

  Widget _buildChicContent(BuildContext context, Color fgMain, Color fgMuted, Color fgFaint, Color bg) {
    String stateTitle = 'Perfectly aligned.';
    String dominantDosha = 'balanced';
    List<String> foodTips = ['Follow natural diet', 'Favor fresh produce'];
    List<String> doTips = ['Maintain routines', 'Observe daily balance'];

    if (vikriti!.imbalances.isNotEmpty) {
      final sorted = List<DoshaImbalance>.from(vikriti!.imbalances)
        ..sort((a, b) => b.shift.abs().compareTo(a.shift.abs()));
      dominantDosha = sorted.first.dosha.toLowerCase();
      
      final isBalanced = vikriti!.isBalanced || sorted.first.shift.abs() < 5;
      
      if (!isBalanced) {
        stateTitle = '${capitalize(dominantDosha)} elevated.';
        
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
    }
    
    final accent = getDoshaColor(dominantDosha);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top section: "Your Current State"
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CURRENT STATE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2.0,
                    color: fgMuted,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  stateTitle,
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontSize: 32,
                    fontStyle: FontStyle.italic,
                    color: fgMain,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                SizedBox(
                  width: 32,
                  height: 32,
                  child: CustomPaint(
                    painter: _DoshaSigilPainter(dosha: dominantDosha, color: accent),
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
        
        const SizedBox(height: 40),

        // The "Unified Elemental Resonance" Diagram (Pure Art, not tappable)
        AspectRatio(
          aspectRatio: 1.0,
          child: CustomPaint(
            painter: _UnifiedTrifectaPainter(
              baseVata: prakriti.vata,
              curVata: vikriti!.vata,
              colorVata: vataColor,
              basePitta: prakriti.pitta,
              curPitta: vikriti!.pitta,
              colorPitta: pittaColor,
              baseKapha: prakriti.kapha,
              curKapha: vikriti!.kapha,
              colorKapha: kaphaColor,
              fgMain: fgMain,
              fgMuted: fgMuted,
              accent: accent,
            ),
          ),
        ),

        const SizedBox(height: 32),

        // Chic Editorial Tappable Bars
        _buildChicBar(context, 'Vata', vikriti!.vata, vataColor, fgMain, fgMuted, bg),
        _buildChicBar(context, 'Pitta', vikriti!.pitta, pittaColor, fgMain, fgMuted, bg),
        _buildChicBar(context, 'Kapha', vikriti!.kapha, kaphaColor, fgMain, fgMuted, bg),

        const SizedBox(height: 48),

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

  Widget _buildChicBar(BuildContext context, String name, int val, Color col,
      Color fgMain, Color fgMuted, Color bg) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.lightImpact();
        _showDoshaExplainer(context, name.toLowerCase(), fgMain, fgMuted, bg);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14.0),
        child: Row(
          children: [
            SizedBox(
              width: 64,
              child: Text(
                name,
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontStyle: FontStyle.italic,
                  fontSize: 16,
                  color: fgMain.withValues(alpha: 0.86),
                  letterSpacing: 0.5,
                ),
              ),
            ),
            SizedBox(
              width: 44,
              child: Text(
                '$val%',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: fgMuted,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      Container(
                        height: 2,
                        width: double.infinity,
                        color: fgMuted.withValues(alpha: 0.12),
                      ),
                      Container(
                        height: 2,
                        width: constraints.maxWidth *
                            (val / 100.0).clamp(0.0, 1.0),
                        color: col.withValues(alpha: 0.8),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Icon(Icons.chevron_right, size: 16, color: fgMuted),
          ],
        ),
      ),
    );
  }

  void _showDoshaExplainer(BuildContext context, String dosha, Color fgMain,
      Color fgMuted, Color bg) {
    String title;
    String element;
    String function;
    String qualities;
    final accent = getDoshaColor(dosha);

    if (dosha == 'pitta') {
      title = 'Pitta';
      element = 'FIRE & WATER';
      function = 'METABOLISM & TRANSFORMATION';
      qualities =
          'Hot, sharp, light, liquid, spreading. Governs digestion, absorption, '
          'assimilation, and body temperature. In balance, it brings intelligence '
          'and understanding. Out of balance, it brings anger and inflammation.';
    } else if (dosha == 'kapha') {
      title = 'Kapha';
      element = 'EARTH & WATER';
      function = 'STRUCTURE & LUBRICATION';
      qualities =
          'Heavy, slow, cool, oily, smooth, dense. Governs structure, bones, '
          'joints, and fluid balance. In balance, it brings love, calmness, and '
          'forgiveness. Out of balance, it brings attachment and lethargy.';
    } else {
      title = 'Vata';
      element = 'AIR & ETHER';
      function = 'MOVEMENT & COMMUNICATION';
      qualities =
          'Light, cold, dry, rough, subtle, mobile. Governs all movement in the '
          'mind and body, including circulation, breathing, and the nervous '
          'system. In balance, it promotes creativity and flexibility. Out of '
          'balance, it produces fear and anxiety.';
    }

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          padding:
              const EdgeInsets.only(left: 32, right: 32, top: 32, bottom: 56),
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

  // Anchor angles for the three doshas.
  static const double _aPitta = -math.pi / 2; // Top (Fire)
  static const double _aKapha = math.pi / 6; // Bottom right (Earth)
  static const double _aVata = 5 * math.pi / 6; // Bottom left (Air)

  static const int _samples = 240;

  // Generate a wavy, mostly-circular orb in unit space (centre = origin).
  List<Offset> _orbPoints(double rP, double rK, double rV, double wave) {
    const tK = math.pi / 6; // 0.524
    const tV = 5 * math.pi / 6; // 2.618
    const tP = 3 * math.pi / 2; // 4.712

    final pts = <Offset>[];
    for (int i = 0; i <= _samples; i++) {
      final t = (i / _samples) * 2 * math.pi;
      double tNorm = t % (2 * math.pi);
      if (tNorm < 0) tNorm += 2 * math.pi;

      double a0, a1, r0, r1;
      if (tNorm >= tK && tNorm < tV) {
        a0 = tK;
        r0 = rK;
        a1 = tV;
        r1 = rV;
      } else if (tNorm >= tV && tNorm < tP) {
        a0 = tV;
        r0 = rV;
        a1 = tP;
        r1 = rP;
      } else {
        a0 = tP;
        r0 = rP;
        a1 = tK + 2 * math.pi;
        r1 = rK;
        if (tNorm < tK) tNorm += 2 * math.pi;
      }

      // Cosine easing -> smooth circular blend that hits each anchor exactly.
      final f = (tNorm - a0) / (a1 - a0);
      final smooth = 0.5 - 0.5 * math.cos(f * math.pi);
      final baseRadius = r0 + smooth * (r1 - r0);

      // Organic breathing wave on top.
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

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    int maxReading = [
      basePitta,
      baseKapha,
      baseVata,
      curPitta,
      curKapha,
      curVata,
    ].reduce(math.max);
    if (maxReading < 1) maxReading = 1;

    // Normalised radius in unit space. Floor so nothing collapses to a dot.
    double unitR(int val) => 0.25 + 0.75 * (val / maxReading);

    // Wave amplitude scales with how far current drifts from baseline.
    final totalShift = ((curPitta - basePitta).abs() +
            (curKapha - baseKapha).abs() +
            (curVata - baseVata).abs())
        .toDouble();
    final curWave = (0.03 + totalShift * 0.0015).clamp(0.03, 0.12);
    const baseWave = 0.02;

    final basePts =
        _orbPoints(unitR(basePitta), unitR(baseKapha), unitR(baseVata), baseWave);
    final curPts =
        _orbPoints(unitR(curPitta), unitR(curKapha), unitR(curVata), curWave);

    // Tight bounding box over BOTH orbs so the whole thing fills the canvas.
    final allPts = [...basePts, ...curPts];
    double minX = allPts.first.dx, maxX = allPts.first.dx;
    double minY = allPts.first.dy, maxY = allPts.first.dy;
    for (final p in allPts) {
      minX = math.min(minX, p.dx);
      maxX = math.max(maxX, p.dx);
      minY = math.min(minY, p.dy);
      maxY = math.max(maxY, p.dy);
    }

    final bboxW = (maxX - minX).clamp(0.0001, double.infinity);
    final bboxH = (maxY - minY).clamp(0.0001, double.infinity);

    const pad = 24.0;
    final scale = math.min((w - pad * 2) / bboxW, (h - pad * 2) / bboxH);

    final bboxCx = (minX + maxX) / 2;
    final bboxCy = (minY + maxY) / 2;

    Offset map(Offset p) => Offset(
          w / 2 + (p.dx - bboxCx) * scale,
          h / 2 + (p.dy - bboxCy) * scale,
        );

    // 1. Baseline orb (Prakriti) - faint anchor.
    final basePath = _pathFrom(basePts, map);
    canvas.drawPath(
      basePath,
      Paint()
        ..color = fgMuted.withValues(alpha: 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..isAntiAlias = true,
    );

    // 2. Current orb (Vikriti) - bold solid.
    final curPath = _pathFrom(curPts, map);
    canvas.drawPath(
      curPath,
      Paint()
        ..color = accent.withValues(alpha: 0.10)
        ..style = PaintingStyle.fill
        ..isAntiAlias = true,
    );
    canvas.drawPath(
      curPath,
      Paint()
        ..color = fgMain
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..isAntiAlias = true,
    );

    // 3. Colour-coded markers at the three anchor points.
    Offset anchor(double angle, int val) {
      final r = unitR(val);
      return map(Offset(r * math.cos(angle), r * math.sin(angle)));
    }

    void drawMarker(Offset pt, Color col) {
      canvas.drawCircle(
        pt,
        16.0,
        Paint()
          ..color = col.withValues(alpha: 0.12)
          ..style = PaintingStyle.fill
          ..isAntiAlias = true,
      );
      canvas.drawCircle(
        pt,
        16.0,
        Paint()
          ..color = col
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0
          ..isAntiAlias = true,
      );
      canvas.drawCircle(
        pt,
        6.0,
        Paint()
          ..color = col
          ..style = PaintingStyle.fill
          ..isAntiAlias = true,
      );
    }

    drawMarker(anchor(_aPitta, curPitta), colorPitta);
    drawMarker(anchor(_aKapha, curKapha), colorKapha);
    drawMarker(anchor(_aVata, curVata), colorVata);
  }

  @override
  bool shouldRepaint(covariant _UnifiedTrifectaPainter old) =>
      old.curVata != curVata ||
      old.curPitta != curPitta ||
      old.curKapha != curKapha ||
      old.baseVata != baseVata ||
      old.basePitta != basePitta ||
      old.baseKapha != baseKapha ||
      old.fgMain != fgMain ||
      old.accent != accent;
}

// ─────────────────────────────────────────────────────────────────────────────
// _DoshaSigilPainter - Minimal elemental glyph for the dominant dosha
// ─────────────────────────────────────────────────────────────────────────────

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
      // Square (Earth)
      canvas.drawRect(Rect.fromLTWH(3, 3, w - 6, h - 6), paint);
    } else if (dosha == 'vata') {
      // Diamond (Air / Space)
      final path = Path()
        ..moveTo(w / 2, 2)
        ..lineTo(w - 2, h / 2)
        ..lineTo(w / 2, h - 2)
        ..lineTo(2, h / 2)
        ..close();
      canvas.drawPath(path, paint);
    } else {
      // Balanced: perfect circle.
      canvas.drawCircle(Offset(w / 2, h / 2), w / 2 - 2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DoshaSigilPainter oldDelegate) =>
      oldDelegate.dosha != dosha || oldDelegate.color != color;
}
"""

with open('lib/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart', 'w') as f:
    f.write(safe_top + todays_balance_card)
