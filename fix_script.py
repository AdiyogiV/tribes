import re

with open('lib/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart', 'r') as f:
    content = f.read()

# Increase the SizedBox wrapping the _DoshaSigilPainter from 24x24 to 56x56
content = re.sub(
    r'width: 24,\s*height: 24,\s*child: CustomPaint\(\s*painter: _DoshaSigilPainter',
    r'width: 56,\n                  height: 56,\n                  child: CustomPaint(\n                    painter: _DoshaSigilPainter',
    content
)

painter_replacement = """class _DoshaSigilPainter extends CustomPainter {
  final String dosha;
  final Color color;

  _DoshaSigilPainter({required this.dosha, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;
      
    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final w = size.width;
    final h = size.height;
    final c = Offset(w / 2, h / 2);
    final padding = w * 0.05;

    if (dosha == 'vata') {
      // The Merkaba (Hexagram) - Air & Space
      double r = w / 2 - padding;
      
      Path upTriangle = Path();
      for (int i = 0; i < 3; i++) {
         double angle = -math.pi / 2 + i * 2 * math.pi / 3;
         Offset pt = Offset(c.dx + r * math.cos(angle), c.dy + r * math.sin(angle));
         if (i == 0) {
           upTriangle.moveTo(pt.dx, pt.dy);
         } else {
           upTriangle.lineTo(pt.dx, pt.dy);
         }
      }
      upTriangle.close();
      
      Path downTriangle = Path();
      for (int i = 0; i < 3; i++) {
         double angle = math.pi / 2 + i * 2 * math.pi / 3;
         Offset pt = Offset(c.dx + r * math.cos(angle), c.dy + r * math.sin(angle));
         if (i == 0) {
           downTriangle.moveTo(pt.dx, pt.dy);
         } else {
           downTriangle.lineTo(pt.dx, pt.dy);
         }
      }
      downTriangle.close();

      canvas.drawPath(upTriangle, strokePaint);
      canvas.drawPath(downTriangle, strokePaint);
      canvas.drawCircle(c, 2.5, fillPaint);

    } else if (dosha == 'pitta') {
      // Sri Yantra Fragment
      Path outerTri = Path()
        ..moveTo(w / 2, padding)
        ..lineTo(w - padding, h - padding)
        ..lineTo(padding, h - padding)
        ..close();
        
      Path innerInvertedTri = Path()
        ..moveTo(padding * 2, h * 0.6)
        ..lineTo(w - padding * 2, h * 0.6)
        ..lineTo(w / 2, h - padding)
        ..close();

      canvas.drawPath(outerTri, strokePaint);
      canvas.drawPath(innerInvertedTri, strokePaint);
      
      canvas.drawCircle(Offset(w / 2, h * 0.35), 2.5, fillPaint);

    } else if (dosha == 'kapha') {
      // The Sacred Chalice
      Path diamond = Path()
        ..moveTo(w / 2, padding)
        ..lineTo(w - padding, h / 2)
        ..lineTo(w / 2, h - padding)
        ..lineTo(padding, h / 2)
        ..close();
        
      Path basin = Path()
        ..moveTo(padding, h / 2)
        ..lineTo(w - padding, h / 2)
        ..lineTo(w / 2, h - padding)
        ..close();

      canvas.drawPath(diamond, strokePaint);
      canvas.drawPath(basin, strokePaint);
      
      double groundW = w * 0.15;
      canvas.drawLine(Offset(w / 2 - groundW, h - padding * 1.5), Offset(w / 2 + groundW, h - padding * 1.5), strokePaint);
      canvas.drawLine(Offset(w / 2 - groundW / 2, h - padding * 0.5), Offset(w / 2 + groundW / 2, h - padding * 0.5), strokePaint);

    } else {
      // Balanced
      double outerR = w / 2 - padding;
      double innerR = w / 4;
      canvas.drawCircle(c, outerR, strokePaint);
      canvas.drawCircle(c, innerR, strokePaint);
      
      for (int i = 0; i < 8; i++) {
         double angle = i * math.pi / 4;
         canvas.drawLine(
           Offset(c.dx + innerR * math.cos(angle), c.dy + innerR * math.sin(angle)),
           Offset(c.dx + outerR * math.cos(angle), c.dy + outerR * math.sin(angle)),
           strokePaint
         );
      }
      canvas.drawCircle(c, 2.5, fillPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _DoshaSigilPainter oldDelegate) => 
      oldDelegate.dosha != dosha || oldDelegate.color != color;
}"""

content = re.sub(r'class _DoshaSigilPainter extends CustomPainter \{.*', painter_replacement, content, flags=re.DOTALL)

with open('lib/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart', 'w') as f:
    f.write(content)

