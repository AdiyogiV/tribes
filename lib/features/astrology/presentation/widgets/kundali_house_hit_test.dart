/// Pure hit-test math for the North Indian kundali diamond layout.
///
/// Both [KundaliChartWidget] (natal) and [CosmicSkyChartCard] (current sky)
/// render the same diamond-shaped chart and need to map a tap into a house
/// number 1..12. This file exists so that math lives in exactly one place.
library;

/// Returns the house (1..12) hit by [nx],[ny] in normalized chart space
/// (-1..1 on both axes, origin = chart centre, +y = down).
///
/// Returns `null` if the tap is clearly outside the chart bounds.
///
/// North Indian house layout:
///   - Houses 1, 4, 7, 10 = central diamond triangles (top, left, bottom, right)
///   - Houses 2, 6, 8, 12 = outer corner squares
///   - Houses 3, 5, 9, 11 = outer edge triangles
int? houseFromNormalizedTap(double nx, double ny) {
  if (nx.abs() > 1.1 || ny.abs() > 1.1) return null;

  // Inside the diamond (|x|+|y| <= 1) → one of the cardinal houses.
  if (nx.abs() + ny.abs() <= 1.0) {
    if (ny < 0 && nx.abs() <= ny.abs()) return 1; // top
    if (nx < 0 && ny.abs() <= nx.abs()) return 4; // left
    if (ny > 0 && nx.abs() <= ny.abs()) return 7; // bottom
    return 10; // right
  }

  // Outside the diamond → split each quadrant by its diagonal.
  final isTop = ny < 0;
  final isLeft = nx < 0;

  if (isTop && isLeft) return (ny < nx) ? 2 : 3;
  if (isTop && !isLeft) return (ny < -nx) ? 12 : 11;
  if (!isTop && isLeft) return (ny > -nx) ? 6 : 5;
  return (ny > nx) ? 8 : 9;
}

/// Convenience wrapper: convert a raw local tap (in pixels, relative to the
/// chart's outermost container) into a house number, accounting for padding,
/// uniform scale, and the kundali_chart package's own internal 0.8 inset.
///
/// Pass [scaleX]/[scaleY] separately for charts that stretch (e.g. the natal
/// chart uses anisotropic scaling); pass equal values for square charts.
int? houseFromLocalTap({
  required double localX,
  required double localY,
  required double containerWidth,
  required double containerHeight,
  required double padding,
  required double scaleX,
  required double scaleY,
}) {
  final innerHeight = containerHeight - (padding * 2);
  final cx = containerWidth / 2;
  final cy = containerHeight / 2;

  // Reverse the Transform.scale to get pre-scale chart coordinates.
  final tapX = (localX - cx) / scaleX;
  final tapY = (localY - cy) / scaleY;

  // The kundali_chart package draws the diamond at 0.8 of the available box.
  final halfSize = (innerHeight * 0.8) / 2;
  if (halfSize <= 0) return null;

  return houseFromNormalizedTap(tapX / halfSize, tapY / halfSize);
}
