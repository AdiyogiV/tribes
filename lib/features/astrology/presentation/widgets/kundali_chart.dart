import 'package:flutter/material.dart';
import 'package:kundali_chart/kundali_chart.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/features/astrology/presentation/widgets/dialogs/house_details_dialog.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

/// Professional North Indian Kundali Chart with tappable houses
class KundaliChartWidget extends StatelessWidget {
  final Map<String, dynamic>? birthChartData;
  final Map<String, dynamic>? houseInterpretations;
  final bool enableHouseTap;

  const KundaliChartWidget({
    super.key,
    required this.birthChartData,
    this.houseInterpretations,
    this.enableHouseTap = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (birthChartData == null) return const SizedBox.shrink();

    final houses = _extractHouses();

    // Use LayoutBuilder to get parent constraints instead of full screen width
    return LayoutBuilder(
      builder: (context, constraints) {
        // Use parent width, capped at a reasonable max for readability
        final availableWidth = constraints.maxWidth.isFinite 
            ? constraints.maxWidth 
            : MediaQuery.of(context).size.width;
        // Cap chart size for web - max 500px keeps it readable
        final chartWidth = availableWidth.clamp(200.0, 500.0);
        final chartHeight = chartWidth * 1;

        // Add padding to prevent chart corners from being cut off
        const padding = 8.0;
        final innerWidth = chartWidth - (padding * 2);
        final innerHeight = chartHeight - (padding * 2);

        // Calculate scale factors to make rectangular
        final baseScale = 1.23;
        final aspectRatio = innerWidth / innerHeight;
        final scaleX = baseScale * aspectRatio;
        final scaleY = baseScale;

        return Center(
          child: GestureDetector(
            onTapUp: enableHouseTap
                ? (details) => _handleTap(context, details, chartWidth, chartHeight,
                    padding, scaleX, scaleY, isDark)
                : null,
            child: Container(
              width: chartWidth,
              height: chartHeight,
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.grey.withValues(alpha: 0.15),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.1)
                        : Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(padding),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
                  child: Transform(
                    transform: Matrix4.identity()..scale(scaleX, scaleY),
                    alignment: Alignment.center,
                    child: SizedBox(
                      width: innerHeight,
                      height: innerHeight,
                      child: KundaliChart(
                        houses: houses,
                        strokeColor: isDark
                            ? AppTheme.astroBrown(isDark).withValues(alpha: 0.7)
                            : AppTheme.astroBrown(isDark),
                        houseLabelStyle: TextStyle(
                          fontSize: chartWidth > 350 ? 9 : 7,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.astroBrown(isDark),
                          height: 1.2,
                        ),
                        planetStyle: TextStyle(
                          fontSize: chartWidth > 350 ? 9 : 7,
                          fontWeight: FontWeight.w800,
                          color: isDark
                              ? Colors.amber.shade400
                              : Colors.deepOrange.shade700,
                          height: 1.2,
                          letterSpacing: 0.2,
                        ),
                        lineWidth: 1,
                        houseLabels: _getZodiacLabels(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _handleTap(
    BuildContext context,
    TapUpDetails details,
    double chartWidth,
    double chartHeight,
    double padding,
    double scaleX,
    double scaleY,
    bool isDark,
  ) {
    // Get tap position relative to the container
    final localPosition = details.localPosition;

    // The chart is drawn with 0.8 factor in the painter, centered
    // Account for padding first
    final innerHeight = chartHeight - (padding * 2);

    // Center of the container (accounting for padding)
    final containerCenterX = chartWidth / 2;
    final containerCenterY = chartHeight / 2;

    // Convert tap to coordinates relative to center
    // We need to reverse the scale transform to get actual chart coordinates
    final tapX = (localPosition.dx - containerCenterX) / scaleX;
    final tapY = (localPosition.dy - containerCenterY) / scaleY;

    // The chart uses 0.8 * min(width, height) for its size
    // Since innerHeight is used as the base square size
    final chartSize = innerHeight * 0.8;
    final halfSize = chartSize / 2;

    // Normalize coordinates to -1..1 range
    final nx = tapX / halfSize;
    final ny = tapY / halfSize;

    // Check if tap is within the chart bounds
    if (nx.abs() > 1.1 || ny.abs() > 1.1) {
      return; // Tap outside chart area
    }

    // Determine which house was tapped
    final houseNumber = _getHouseFromTap(nx, ny);

    if (houseNumber > 0) {
      _showHouseDetails(context, houseNumber, isDark);
    }
  }

  /// Determines which house (1-12) was tapped based on normalized coordinates
  /// The North Indian chart has:
  /// - Houses 1, 4, 7, 10 inside the diamond (center triangles)
  /// - Houses 2, 6, 8, 12 in the corners (outside diamond)
  /// - Houses 3, 5, 9, 11 on the edges (outside diamond)
  int _getHouseFromTap(double nx, double ny) {
    // Check if inside the diamond: |x| + |y| <= 1
    final insideDiamond = nx.abs() + ny.abs() <= 1.0;

    if (insideDiamond) {
      // Inside diamond: 4 triangular regions
      // Determine which triangle based on which coordinate dominates
      if (ny < 0 && nx.abs() <= ny.abs()) {
        return 1; // Top center triangle
      } else if (nx < 0 && ny.abs() <= nx.abs()) {
        return 4; // Left center triangle
      } else if (ny > 0 && nx.abs() <= ny.abs()) {
        return 7; // Bottom center triangle
      } else {
        return 10; // Right center triangle
      }
    }

    // Outside diamond: 8 regions divided by the main diagonals
    // Main diagonal: y = x (top-left to bottom-right)
    // Anti-diagonal: y = -x (top-right to bottom-left)

    final isTop = ny < 0;
    final isLeft = nx < 0;

    if (isTop && isLeft) {
      // Top-left quadrant: House 2 (corner) or House 3 (left edge)
      // Diagonal y = x divides them
      return (ny < nx) ? 2 : 3;
    } else if (isTop && !isLeft) {
      // Top-right quadrant: House 12 (corner) or House 11 (right edge)
      // Anti-diagonal y = -x divides them
      return (ny < -nx) ? 12 : 11;
    } else if (!isTop && isLeft) {
      // Bottom-left quadrant: House 6 (corner) or House 5 (left edge)
      // Anti-diagonal y = -x divides them
      return (ny > -nx) ? 6 : 5;
    } else {
      // Bottom-right quadrant: House 8 (corner) or House 9 (right edge)
      // Main diagonal y = x divides them
      return (ny > nx) ? 8 : 9;
    }
  }

  void _showHouseDetails(BuildContext context, int houseNumber, bool isDark) {
    // Get the lagna sign index to calculate which sign is in which house
    final lagnaSignIndex = _getLagnaSignIndex();

    // Get the sign for this house
    final zodiacSign =
        HouseSignifications.getSignForHouse(houseNumber, lagnaSignIndex);
    final signLord = HouseSignifications.getSignLord(zodiacSign);

    // Get planets in this house
    final planetsInHouse = _getPlanetsInHouse(houseNumber);

    // Get AI interpretation if available
    String? interpretation;
    if (houseInterpretations != null) {
      final houseData = houseInterpretations!['$houseNumber'] ??
          houseInterpretations![houseNumber];
      if (houseData is Map) {
        interpretation = houseData['interpretation'] as String?;
      } else if (houseData is String) {
        interpretation = houseData;
      }
    }

    final houseInfo = HouseInfo(
      houseNumber: houseNumber,
      zodiacSign: zodiacSign,
      signLord: signLord,
      planets: planetsInHouse,
      interpretation: interpretation,
    );

    HouseDetailsDialog.show(context, houseInfo, isDark);
  }

  int _getLagnaSignIndex() {
    try {
      final planetsObj = _planetsMap();
      if (planetsObj != null) {
        final ascendant = planetsObj['Ascendant'] ??
            planetsObj['ascendant'] ??
            planetsObj['0'];
        final degree = (ascendant?['fullDegree'] ?? ascendant?['full_degree']);
        if (degree is num) {
          return (degree / 30).floor() % 12;
        }
      }
    } catch (e) {
      // Ignore errors
    }
    return 0;
  }

  List<String> _getPlanetsInHouse(int houseNumber) {
    final List<String> planets = [];
    try {
      final planetsObj = _planetsMap();
      if (planetsObj != null) {
        planetsObj.forEach((key, value) {
          if (value is! Map<String, dynamic>) return;
          final name = (value['name'] ?? key)?.toString();
          final houseNum = value['house_number'] ?? value['houseNumber'];

          if (name != null &&
              name.toLowerCase() != 'ascendant' &&
              houseNum is int &&
              houseNum == houseNumber) {
            planets.add(name);
          }
        });
      }
    } catch (e) {
      // Ignore errors
    }
    return planets;
  }

  Map<String, dynamic>? _planetsMap() {
    final output = birthChartData!['output'];
    if (output is Map<String, dynamic>) {
      return Map<String, dynamic>.from(output);
    }
    if (output is List && output.isNotEmpty) {
      final first = output.first;
      if (first is Map<String, dynamic>) {
        return Map<String, dynamic>.from(first);
      }
    }
    return null;
  }

  List<String> _getZodiacLabels() {
    int lagnaSignIndex = 0;
    try {
      final planetsObj = _planetsMap();
      if (planetsObj != null) {
        final ascendant = planetsObj['Ascendant'] ??
            planetsObj['ascendant'] ??
            planetsObj['0'];
        final degree = (ascendant?['fullDegree'] ?? ascendant?['full_degree']);
        if (degree is num) {
          lagnaSignIndex = (degree / 30).floor() % 12;
        }
      }
    } catch (e, stackTrace) {
      AppLogger.e(
        'Error calculating lagna',
        category: LogCategory.general,
        error: e,
        stackTrace: stackTrace,
      );
    }

    final zodiacAbbrs = _getZodiacAbbreviations();

    return List.generate(12, (index) {
      final signIndex = (lagnaSignIndex + index) % 12;
      final signNum = signIndex + 1; // Zodiac number (1=Aries, 2=Taurus, etc.)
      final abbr = zodiacAbbrs[signIndex];
      return '$signNum $abbr';
    });
  }

  List<String> _getZodiacAbbreviations() {
    return [
      'Ari', // Aries
      'Tau', // Taurus
      'Gem', // Gemini
      'Can', // Cancer
      'Leo', // Leo
      'Vir', // Virgo
      'Lib', // Libra
      'Sco', // Scorpio
      'Sag', // Sagittarius
      'Cap', // Capricorn
      'Aqu', // Aquarius
      'Pis', // Pisces
    ];
  }

  List<List<String>> _extractHouses() {
    final Map<int, List<String>> tempHouses = {};

    try {
      final planetsObj = _planetsMap();
      if (planetsObj != null) {
        planetsObj.forEach((key, value) {
          if (value is! Map<String, dynamic>) return;
          final name = (value['name'] ?? key)?.toString();
          final houseNum = value['house_number'] ?? value['houseNumber'];

          if (name != null &&
              name.toLowerCase() != 'ascendant' &&
              houseNum is int &&
              houseNum >= 1 &&
              houseNum <= 12) {
            tempHouses.putIfAbsent(houseNum, () => []);
            tempHouses[houseNum]!.add(name);
          }
        });
      }
    } catch (e, stackTrace) {
      AppLogger.e(
        'Error extracting houses',
        category: LogCategory.general,
        error: e,
        stackTrace: stackTrace,
      );
    }

    return List.generate(12, (index) {
      final houseNum = index + 1;
      final planetNames = tempHouses[houseNum] ?? [];
      if (planetNames.isEmpty) return [];

      // Line 1: All symbols
      final symbols = planetNames.map((n) => _getPlanetSymbol(n)).join(' ');
      // Line 2: All initials
      final initials = planetNames.map((n) => _getPlanetInitials(n)).join(' ');

      // Return symbols on top, initials below
      return ['\n$symbols\n$initials'];
    });
  }

  String _getPlanetSymbol(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('sun') || lower.contains('surya')) return '❂';
    if (lower.contains('moon') || lower.contains('chandra')) return '☾';
    if (lower.contains('mars') || lower.contains('mangal')) return '✦';
    if (lower.contains('mercury') || lower.contains('budh')) return '☿';
    if (lower.contains('jupiter') ||
        lower.contains('guru') ||
        lower.contains('brihaspati')) {
      return '♃';
    }
    if (lower.contains('venus') || lower.contains('shukra')) return '♀';
    if (lower.contains('saturn') || lower.contains('shani')) return '♄';
    if (lower.contains('rahu')) return '☊';
    if (lower.contains('ketu')) return '☋';
    if (lower.contains('uranus')) return '⛢';
    if (lower.contains('neptune')) return '♆';
    if (lower.contains('pluto')) return '♇';
    return '•';
  }

  String _getPlanetInitials(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('sun') || lower.contains('surya')) return 'Su';
    if (lower.contains('moon') || lower.contains('chandra')) return 'Mo';
    if (lower.contains('mars') || lower.contains('mangal')) return 'Ma';
    if (lower.contains('mercury') || lower.contains('budh')) return 'Me';
    if (lower.contains('jupiter') ||
        lower.contains('guru') ||
        lower.contains('brihaspati')) {
      return 'Ju';
    }
    if (lower.contains('venus') || lower.contains('shukra')) return 'Ve';
    if (lower.contains('saturn') || lower.contains('shani')) return 'Sa';
    if (lower.contains('rahu')) return 'Ra';
    if (lower.contains('ketu')) return 'Ke';
    if (lower.contains('uranus')) return 'Ur';
    if (lower.contains('neptune')) return 'Ne';
    if (lower.contains('pluto')) return 'Pl';
    return name.length >= 2 ? name.substring(0, 2) : name;
  }
}
