import re

with open('lib/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart', 'r') as f:
    content = f.read()

# 1. Replace the list items (remove numbers)
pattern_list = r"\.\.\.items\.asMap\(\)\.entries\.map\(\(entry\) \{[\s\S]*?\}\),"
replacement_list = """...items.map((text) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '—',
                  style: TextStyle(color: fgMain, fontSize: 13, fontWeight: FontWeight.w300),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(
                      color: fgMain,
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),"""
content = re.sub(pattern_list, replacement_list, content)

# 2. Replace the graph inside _buildDataRow
pattern_graph = r"Expanded\(\n\s*child: LayoutBuilder\(builder: \(context, constraints\) \{[\s\S]*?\}\),\n\s*\),"
replacement_graph = """Expanded(
          child: SizedBox(
            height: 24,
            child: CustomPaint(
              painter: _BarcodeGraphPainter(
                basePct: (base / 100).clamp(0.0, 1.0),
                curPct: (cur / 100).clamp(0.0, 1.0),
                fgMain: fgMain,
                fgFaint: lineCol,
                shiftColor: fgMuted,
              ),
            ),
          ),
        ),"""
content = re.sub(pattern_graph, replacement_graph, content)

# 3. Replace the _DoshaSigilPainter with the new offset brutalist geometry & append Barcode Graph
pattern_sigil = r"class _DoshaSigilPainter extends CustomPainter \{[\s\S]*?\}\n\}"
replacement_sigil = """class _DoshaSigilPainter extends CustomPainter {
  final String dosha;
  final Color color;

  _DoshaSigilPainter({required this.dosha, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = color.withOpacity(0.3)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final w = size.width;
    final h = size.height;
    final offset = 4.0;

    if (dosha == 'pitta') {
      // Offset overlapping triangles
      final path1 = Path()
        ..moveTo(w / 2, 0)..lineTo(w - offset, h - offset)..lineTo(offset, h - offset)..close();
      final path2 = Path()
        ..moveTo(w / 2 + offset, offset)..lineTo(w, h)..lineTo(offset*2, h)..close();
      canvas.drawPath(path2, strokePaint);
      canvas.drawPath(path1, fillPaint);
    } else if (dosha == 'kapha') {
      // Offset overlapping squares
      canvas.drawRect(Rect.fromLTWH(offset, offset, w - offset*1.5, h - offset*1.5), strokePaint);
      canvas.drawRect(Rect.fromLTWH(0, 0, w - offset*1.5, h - offset*1.5), fillPaint);
    } else if (dosha == 'vata') {
      // Offset overlapping diamonds
      final path1 = Path()
        ..moveTo(w / 2, 0)..lineTo(w - offset, h / 2)..lineTo(w / 2, h - offset)..lineTo(offset, h / 2)..close();
      final path2 = Path()
        ..moveTo(w / 2 + offset, offset)..lineTo(w, h / 2 + offset)..lineTo(w / 2 + offset, h)..lineTo(offset*2, h / 2 + offset)..close();
      canvas.drawPath(path2, strokePaint);
      canvas.drawPath(path1, fillPaint);
    } else {
      canvas.drawCircle(Offset(w / 2 + offset/2, h / 2 + offset/2), w / 2 - offset, strokePaint);
      canvas.drawCircle(Offset(w / 2 - offset/2, h / 2 - offset/2), w / 2 - offset, fillPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _DoshaSigilPainter oldDelegate) => 
      oldDelegate.dosha != dosha || oldDelegate.color != color;
}

class _BarcodeGraphPainter extends CustomPainter {
  final double basePct;
  final double curPct;
  final Color fgMain;
  final Color fgFaint;
  final Color shiftColor;

  _BarcodeGraphPainter({required this.basePct, required this.curPct, required this.fgMain, required this.fgFaint, required this.shiftColor});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    
    // Draw a "barcode" / "waveform" data scale
    int tickCount = 40;
    double spacing = w / (tickCount - 1);
    
    int baseTick = (basePct * tickCount).round();
    int curTick = (curPct * tickCount).round();
    
    for (int i = 0; i < tickCount; i++) {
      double x = i * spacing;
      
      Color tickColor = fgFaint;
      double tickHeight = h * 0.15; // Tiny baseline dots
      double strokeW = 1.0;
      
      bool isBetween = (i >= math.min(baseTick, curTick) && i <= math.max(baseTick, curTick));
      
      if (i <= curTick) {
        tickColor = fgMain.withOpacity(0.5); 
        tickHeight = h * 0.4;
      }
      
      if (isBetween) {
        // Highlighting the specific area of "shift"
        tickHeight = h * 0.7;
        tickColor = shiftColor;
      }
      
      if (i == curTick || i == baseTick) {
         // Anchor points
         tickHeight = h;
         tickColor = fgMain;
         strokeW = 1.5;
      }
      
      final paint = Paint()
        ..color = tickColor
        ..strokeWidth = strokeW
        ..strokeCap = StrokeCap.round;
        
      canvas.drawLine(Offset(x, h/2 - tickHeight/2), Offset(x, h/2 + tickHeight/2), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BarcodeGraphPainter oldDelegate) => true;
}
"""
content = re.sub(pattern_sigil, replacement_sigil, content)

with open('lib/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart', 'w') as f:
    f.write(content)

