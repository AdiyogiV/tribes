import 'package:flutter/material.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

/// The one and only surface for every Circle (friends) card.
///
/// Flush card — pure black in dark mode, white in light mode, with NO border,
/// NO gradient, and NO rounded corners (borderRadius ZERO) — so it melts into
/// the dashboard exactly like the other cards. Every friends widget builds on
/// this so they can never drift apart again.
class CircleFlushCard extends StatelessWidget {
  const CircleFlushCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppDimensions.paddingXl),
    this.onTap,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF000000) : Colors.white;

    return Material(
      color: cardColor,
      elevation: 0,
      borderRadius: BorderRadius.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
