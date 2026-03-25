import 'package:flutter/material.dart';
import 'package:aurogram/utils/theme/app_theme.dart';

/// A gradient line separator that fades on both ends.
/// Used as a visual divider between sections/posts.
class GradientSeparator extends StatelessWidget {
  final double height;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  const GradientSeparator({
    super.key,
    this.height = 0.2,
    this.maxWidth = 500,
    this.padding = const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Padding(
      padding: padding,
      child: Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: maxWidth),
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                isDark
                    ? AppTheme.primaryColor.withValues(alpha: 0.4)
                    : AppTheme.primaryColor.withValues(alpha: 0.25),
                isDark
                    ? AppTheme.primaryColor.withValues(alpha: 0.4)
                    : AppTheme.primaryColor.withValues(alpha: 0.25),
                Colors.transparent,
              ],
              stops: const [0.0, 0.15, 0.85, 1.0],
            ),
          ),
        ),
      ),
    );
  }
}







