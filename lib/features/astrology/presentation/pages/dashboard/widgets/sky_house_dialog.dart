import 'package:flutter/material.dart';
import 'package:aurogram/features/astrology/data/utils/chart_utils.dart';
import 'package:aurogram/features/astrology/presentation/widgets/dialogs/house_details_dialog.dart';
import 'package:aurogram/shared/models/astrology_profile.dart';

/// Map each current-sky planet to the user's house number (1..12), relative to
/// [lagnaSignIndex]. Ascendant is skipped (it's the frame, not a transit).
/// Returns house -> list of planet names occupying it right now.
Map<int, List<String>> occupantsByHouse(
  Map<String, dynamic> currentPositions,
  int lagnaSignIndex,
) {
  final byHouse = <int, List<String>>{};
  currentPositions.forEach((planet, data) {
    if (data is! Map) return;
    if (planet.toLowerCase() == 'ascendant') return;

    final m =
        Map<String, dynamic>.from(data.map((k, v) => MapEntry(k.toString(), v)));
    final sign = (m['sign'] as String?)?.toLowerCase() ?? '';
    int? signIndex = ChartConstants.signToIndex[sign];
    if (signIndex == null) {
      final lon = m['longitude'];
      if (lon is num) signIndex = (lon / 30).floor() % 12;
    }
    if (signIndex == null) return;

    final h = ((signIndex - lagnaSignIndex + 12) % 12) + 1;
    (byHouse[h] ??= <String>[]).add(planet);
  });
  return byHouse;
}

/// Read the biweekly/monthly sky reading stored on [profile] for [house].
SkyHouseReading? _skyReadingFor(AstrologyProfile? profile, int house) {
  final houses = profile?.skyHouseReadings?['houses'];
  if (houses is! Map) return null;
  final raw = houses['$house'] ?? houses[house];
  if (raw is! Map) return null;
  return SkyHouseReading(
    headline: (raw['headline'] as String?)?.trim(),
    reading: (raw['reading'] as String?)?.trim(),
    focus: (raw['focus'] as String?)?.trim(),
    watch: (raw['watch'] as String?)?.trim(),
  );
}

/// Build the ranked list of ALL twelve houses for the Current-Sky gochara
/// list, sorted by [gocharaScore] (heaviest / most-occupied transits first).
/// Quiet (untransited) houses score 0 and fall to the bottom.
List<HouseInfo> buildRankedGocharaHouses(
  AstrologyProfile? profile,
  Map<String, dynamic> currentPositions,
) {
  final lagnaSignIndex = ChartUtils.getLagnaSignIndex(profile?.birthChartData);
  final byHouse = occupantsByHouse(currentPositions, lagnaSignIndex);
  final cycleEndDate = profile?.skyHouseReadings?['cycleEndDate'] as String?;

  final infos = List.generate(12, (i) {
    final house = i + 1;
    final planets = byHouse[house] ?? const <String>[];
    final zodiacSign =
        HouseSignifications.getSignForHouse(house, lagnaSignIndex);
    return HouseInfo(
      houseNumber: house,
      zodiacSign: zodiacSign,
      signLord: HouseSignifications.getSignLord(zodiacSign),
      planets: planets,
      skyReading: _skyReadingFor(profile, house),
      cycleEndDate: cycleEndDate,
    );
  });

  infos.sort((a, b) {
    final byScore = gocharaScore(b.planets).compareTo(gocharaScore(a.planets));
    if (byScore != 0) return byScore;
    return a.houseNumber.compareTo(b.houseNumber);
  });
  return infos;
}

/// Build and show the per-house current-state popup for a tap on the
/// Current Sky chart. [tappedSignPosition] is the geometric sign position
/// (1=Aries .. 12=Pisces) from the sign-fixed wheel; it's converted to the
/// user's actual house number here.
void showSkyHouseDialog(
  BuildContext context,
  AstrologyProfile? profile,
  int tappedSignPosition,
  Map<String, dynamic> currentPositions,
  bool isDark,
) {
  final lagnaSignIndex = ChartUtils.getLagnaSignIndex(profile?.birthChartData);
  final tappedSignIndex = tappedSignPosition - 1; // 0-based (0=Aries)
  final actualHouse = ((tappedSignIndex - lagnaSignIndex + 12) % 12) + 1;

  final planets =
      occupantsByHouse(currentPositions, lagnaSignIndex)[actualHouse] ??
          const <String>[];

  final zodiacSign =
      HouseSignifications.getSignForHouse(actualHouse, lagnaSignIndex);

  showHouseDetails(
    context,
    HouseInfo(
      houseNumber: actualHouse,
      zodiacSign: zodiacSign,
      signLord: HouseSignifications.getSignLord(zodiacSign),
      planets: planets,
      skyReading: _skyReadingFor(profile, actualHouse),
      cycleEndDate: profile?.skyHouseReadings?['cycleEndDate'] as String?,
    ),
    isDark,
  );
}

/// Thin wrapper so callers use one entry point for the (redesigned) dialog.
void showHouseDetails(BuildContext context, HouseInfo info, bool isDark) =>
    HouseDetailsDialog.show(context, info, isDark);
