import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:aurogram/utils/theme/app_theme.dart';

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double? height;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final double blurSigma;
  final Color? baseColor;

  const GlassContainer({
    super.key,
    required this.child,
    this.height,
    required this.padding,
    this.borderRadius = 20,
    this.blurSigma = 3,
    this.baseColor,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color barBase =
        baseColor ?? (isDark ? AppTheme.cardDarkColor : Colors.white);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        elevation: 4,
        color: Colors.transparent,
        shadowColor: Colors.black.withValues(alpha: 0.04),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        clipBehavior: Clip.antiAlias,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Container(
            height: height,
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  barBase.withValues(alpha: isDark ? 0.85 : 0.90),
                  barBase.withValues(alpha: isDark ? 0.80 : 0.85),
                ],
              ),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.10)
                    : barBase.withValues(alpha: 0.32),
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
