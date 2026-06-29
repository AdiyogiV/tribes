import re

with open('lib/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart', 'r') as f:
    content = f.read()

# 1. Completely rewrite _buildDataRow
pattern_row = r"  Widget _buildDataRow\(BuildContext context.*?return Padding\(.*?child: Column\([\s\S]*?\]\),\n      \),\n    \);\n  \}"

new_row = """  Widget _buildDataRow(BuildContext context, String label, String subline, String desc, int base, int cur, Color fgMain, Color fgMuted, Color fgFaint, Color lineCol, Color rowColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 32.0),
      child: GestureDetector(
        onTap: () {
          showModalBottomSheet(
            context: context,
            backgroundColor: Colors.transparent,
            builder: (context) => Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF111111) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label.toUpperCase(), style: TextStyle(color: rowColor, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 2.0)),
                    const SizedBox(height: 8),
                    Text(subline, style: TextStyle(color: fgMain, fontSize: 16, fontWeight: FontWeight.w500, letterSpacing: 1.0)),
                    const SizedBox(height: 24),
                    Text(desc, style: TextStyle(color: fgMuted, fontSize: 14, height: 1.6)),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          );
        },
        behavior: HitTestBehavior.opaque,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Left: Ultra-chic Dosha label
            SizedBox(
              width: 70,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: rowColor,
                      fontFamily: 'Georgia',
                      fontStyle: FontStyle.italic,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subline.split('·')[0].trim(), // e.g., 'AIR & SPACE'
                    style: TextStyle(
                      color: fgMuted,
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Right: The Editorial Ruler Visualization
            Expanded(
              child: SizedBox(
                height: 40,
                child: CustomPaint(
                  painter: _EditorialRulerPainter(
                    base: base,
                    cur: cur,
                    color: rowColor,
                    mutedColor: fgMuted,
                    faintColor: lineCol,
                    bgColor: Theme.of(context).scaffoldBackgroundColor,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }"""

content = re.sub(pattern_row, new_row, content, flags=re.DOTALL)

# 2. Append _EditorialRulerPainter class to the end of the file (before the last bracket or just replace EOF)
# To be safe, we'll just append it to the very end of the file since it's a top-level class.

ruler_class = """
class _EditorialRulerPainter extends CustomPainter {
  final int base;
  final int cur;
  final Color color;
  final Color mutedColor;
  final Color faintColor;
  final Color bgColor;

  _EditorialRulerPainter({
    required this.base,
    required this.cur,
    required this.color,
    required this.mutedColor,
    required this.faintColor,
    required this.bgColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final centerY = h / 2 + 6; 

    // Draw minimalist track (faint)
    final trackPaint = Paint()
      ..color = faintColor
      ..strokeWidth = 1.0
      ..isAntiAlias = true;
    canvas.drawLine(Offset(0, centerY), Offset(w, centerY), trackPaint);

    // Draw decile ticks
    for (int i = 0; i <= 10; i++) {
      double x = (w / 10) * i;
      double tickH = (i == 0 || i == 5 || i == 10) ? 3.0 : 1.5;
      canvas.drawLine(Offset(x, centerY - tickH), Offset(x, centerY + tickH), trackPaint);
    }

    double bX = w * (base / 100.0);
    double cX = w * (cur / 100.0);

    // Draw connection path
    if (base != cur) {
      final connectPaint = Paint()
        ..color = color.withAlpha(80)
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke
        ..isAntiAlias = true;
      canvas.drawLine(Offset(bX, centerY), Offset(cX, centerY), connectPaint);
    }

    // Draw Baseline point (hollow ring)
    final baseFill = Paint()..color = bgColor..style = PaintingStyle.fill;
    final baseStroke = Paint()..color = mutedColor.withAlpha(150)..style = PaintingStyle.stroke..strokeWidth = 1.5..isAntiAlias = true;
    canvas.drawCircle(Offset(bX, centerY), 3.5, baseFill);
    canvas.drawCircle(Offset(bX, centerY), 3.5, baseStroke);

    // Draw Current point (solid drop)
    final curPaint = Paint()..color = color..style = PaintingStyle.fill..isAntiAlias = true;
    canvas.drawCircle(Offset(cX, centerY), 4.5, curPaint);

    // Typographic percentage label hovering exactly over the current point
    final textSpan = TextSpan(
      text: '${cur}%',
      style: TextStyle(
        color: color,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    
    // Prevent text from overflowing edges
    double textX = cX - textPainter.width / 2;
    if (textX < 0) textX = 0;
    if (textX + textPainter.width > w) textX = w - textPainter.width;
    
    // Hover text above the track
    textPainter.paint(canvas, Offset(textX, centerY - 22));
  }

  @override
  bool shouldRepaint(covariant _EditorialRulerPainter old) => 
      old.base != base || old.cur != cur || old.color != color;
}
"""

content += ruler_class

with open('lib/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart', 'w') as f:
    f.write(content)

