import 'package:aurogram/utils/theme/app_dimensions.dart';
import 'package:flutter/material.dart';
import 'package:aurogram/utils/theme/app_theme.dart';

/// Custom painter for pulse animation effect
class PulsePainter extends CustomPainter {
  final double pulseValue;
  final bool isLoading;

  PulsePainter({
    required this.pulseValue,
    this.isLoading = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 3;
    
    // Draw pulsing circles
    for (int i = 0; i < 3; i++) {
      final radius = maxRadius * (0.3 + (pulseValue + i * 0.3) % 1.0);
      final opacity = (1.0 - ((pulseValue + i * 0.3) % 1.0)).clamp(0.0, 1.0);
      
      final paint = Paint()
        ..color = AppTheme.primaryColor.withValues(alpha: opacity * 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      
      canvas.drawCircle(center, radius, paint);
    }
    
    // Draw center dot
    final centerPaint = Paint()
      ..color = AppTheme.primaryColor
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(center, 10, centerPaint);
  }

  @override
  bool shouldRepaint(PulsePainter oldDelegate) {
    return oldDelegate.pulseValue != pulseValue;
  }
}

/// A simple upload indicator widget that shows a pulsing dot with text
/// Used only when content is actively uploading
class UploadIndicator extends StatefulWidget {
  final String? text;
  final Color? color;

  const UploadIndicator({
    super.key,
    this.text = 'Uploading...',
    this.color,
  });

  @override
  State<UploadIndicator> createState() => _UploadIndicatorState();
}

class _UploadIndicatorState extends State<UploadIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _animation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? AppTheme.successColor;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: _animation.value),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.4 * _animation.value),
                      blurRadius: 6,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
              if (widget.text != null) ...[
                const SizedBox(width: AppDimensions.spacingSm),
                Text(
                  widget.text!,
                  style: TextStyle(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
