import 'package:flutter/material.dart';

/// A responsive spacer component that provides consistent spacing
/// throughout the app and adapts to different screen sizes
class ResponsiveSpacer extends StatelessWidget {
  /// Vertical space in logical pixels
  final double? height;

  /// Horizontal space in logical pixels
  final double? width;

  /// When true, the spacer will adjust its size based on screen size
  final bool responsive;

  /// Factor to multiply the spacing by when responsive is true
  /// Larger screens get more spacing
  final double factor;

  /// Creates a vertical spacing
  const ResponsiveSpacer.vertical(
    double space, {
    super.key,
    this.responsive = true,
    this.factor = 1.0,
  })  : height = space,
        width = null;

  /// Creates a horizontal spacing
  const ResponsiveSpacer.horizontal(
    double space, {
    super.key,
    this.responsive = true,
    this.factor = 1.0,
  })  : width = space,
        height = null;

  /// Creates both vertical and horizontal spacing
  const ResponsiveSpacer({
    super.key,
    this.height,
    this.width,
    this.responsive = true,
    this.factor = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate responsive scaling based on screen size
    final double responsiveFactor =
        responsive ? _calculateResponsiveFactor(context) * factor : factor;

    return SizedBox(
      height: height != null ? height! * responsiveFactor : null,
      width: width != null ? width! * responsiveFactor : null,
    );
  }

  /// Calculate a responsive factor based on the screen width
  double _calculateResponsiveFactor(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;

    // Base size for phone - no adjustment needed
    if (screenWidth < 600) return 1.0;

    // Tablet gets slightly more spacing
    if (screenWidth < 960) return 1.25;

    // Desktop gets more spacing
    return 1.5;
  }
}

// Preset spacers for common use cases
class Spacing {
  /// Extra small vertical space (4)
  static const Widget verySmall = ResponsiveSpacer.vertical(4);

  /// Small vertical space (8)
  static const Widget small = ResponsiveSpacer.vertical(8);

  /// Medium vertical space (16)
  static const Widget medium = ResponsiveSpacer.vertical(16);

  /// Large vertical space (24)
  static const Widget large = ResponsiveSpacer.vertical(24);

  /// Extra large vertical space (32)
  static const Widget extraLarge = ResponsiveSpacer.vertical(32);

  /// XXL vertical space (48)
  static const Widget xxl = ResponsiveSpacer.vertical(48);

  /// Small horizontal space (8)
  static const Widget horizontalSmall = ResponsiveSpacer.horizontal(8);

  /// Medium horizontal space (16)
  static const Widget horizontalMedium = ResponsiveSpacer.horizontal(16);

  /// Large horizontal space (24)
  static const Widget horizontalLarge = ResponsiveSpacer.horizontal(24);
}
