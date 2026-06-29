with open('lib/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart', 'r') as f:
    content = f.read()

painter = """
class _VerticalGaugePainter extends CustomPainter {
  final int base;
  final int cur;
  final Color color;
  final Color bgColor;
  final Color baselineColor;

  _VerticalGaugePainter({
    required this.base,
    required this.cur,
    required this.color,
    required this.bgColor,
    required this.baselineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final radius = Radius.circular(w / 2);

    final bgRect = RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w, h), radius);
    canvas.drawRRect(bgRect, Paint()..color = bgColor..isAntiAlias = true);

    final curRatio = (cur / 100.0).clamp(0.0, 1.0);
    final fillH = h * curRatio;
    final fillRect = RRect.fromRectAndRadius(Rect.fromLTWH(0, h - fillH, w, fillH), radius);
    canvas.drawRRect(fillRect, Paint()..color = color..isAntiAlias = true);

    final baseRatio = (base / 100.0).clamp(0.0, 1.0);
    final baseY = h - (h * baseRatio);
    
    final basePaint = Paint()
      ..color = baselineColor
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
      
    canvas.drawLine(Offset(-6, baseY), Offset(w + 6, baseY), basePaint);
  }

  @override
  bool shouldRepaint(covariant _VerticalGaugePainter old) => true;
}
"""

content += painter

with open('lib/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart', 'w') as f:
    f.write(content)
