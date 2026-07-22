import 'package:flutter/material.dart';
import 'package:aurogram/features/astrology/data/utils/chart_utils.dart';
import 'package:aurogram/features/astrology/presentation/widgets/dialogs/house_details_dialog.dart';
import 'package:aurogram/shared/models/astrology_profile.dart';

/// Build and show the per-house current-state popup for a tap on the
/// Current Sky chart. Combines transiting planets (from [currentPositions])
/// with the user's natal interpretation and the biweekly sky reading
/// stored on [profile].
///
/// Pure presentation helper extracted from AstroDashboardContent — it touches
/// no widget state, only its arguments.
void showSkyHouseDialog(
  BuildContext context,
  AstrologyProfile? profile,
  int houseNumber,
  Map<String, dynamic> currentPositions,
  bool isDark,
) {
  final lagnaSignIndex = ChartUtils.getLagnaSignIndex(profile?.birthChartData);

  // In the sign-fixed Current Sky chart the geometric tap position maps
  // directly to a zodiac sign (1=Aries, 2=Taurus, ...), NOT to the user's
  // house number.  Convert sign position -> actual house number so every
  // lookup below (natal interpretation, sky reading, planet filter) uses
  // the correct house.
  final tappedSignIndex = houseNumber - 1; // 0-based (0=Aries)
  final actualHouse = ((tappedSignIndex - lagnaSignIndex + 12) % 12) + 1;

  final zodiacSign =
      HouseSignifications.getSignForHouse(actualHouse, lagnaSignIndex);
  final signLord = HouseSignifications.getSignLord(zodiacSign);

  // Walk current sky positions and pick those whose sign maps to this house.
  final planets = <String>[];
  currentPositions.forEach((planet, data) {
    if (data is! Map) return;
    if (planet.toLowerCase() == 'ascendant') return;

    final m = Map<String, dynamic>.from(
        data.map((k, v) => MapEntry(k.toString(), v)));
    final sign = (m['sign'] as String?)?.toLowerCase() ?? '';
    int? signIndex = ChartConstants.signToIndex[sign];
    if (signIndex == null) {
      final lon = m['longitude'];
      if (lon is num) signIndex = (lon / 30).floor() % 12;
    }
    if (signIndex == null) return;

    final h = ((signIndex - lagnaSignIndex + 12) % 12) + 1;
    if (h == actualHouse) planets.add(planet);
  });

  // Current Sky context — sky reading only, no natal interpretation.
  SkyHouseReading? skyReading;
  String? cycleEndDate;
  final houses = profile?.skyHouseReadings?['houses'];
  if (houses is Map) {
    final raw = houses['$actualHouse'] ?? houses[actualHouse];
    if (raw is Map) {
      skyReading = SkyHouseReading(
        headline: (raw['headline'] as String?)?.trim(),
        reading: (raw['reading'] as String?)?.trim(),
        focus: (raw['focus'] as String?)?.trim(),
        watch: (raw['watch'] as String?)?.trim(),
      );
    }
    cycleEndDate = profile?.skyHouseReadings?['cycleEndDate'] as String?;
  }

  HouseDetailsDialog.show(
    context,
    HouseInfo(
      houseNumber: actualHouse,
      zodiacSign: zodiacSign,
      signLord: signLord,
      planets: planets,
      skyReading: skyReading,
      cycleEndDate: cycleEndDate,
    ),
    isDark,
  );
}
