import 'chart_utils.dart';

/// The emotional "character" of a transit→natal connection, used to colour and
/// style its line on the sky chart.
enum SkyConnectionNature {
  /// Harmonious (trine/sextile, or a benefic conjunction). Warm gold.
  supportive,

  /// Frictional (square/opposition, or a malefic conjunction). Hot red.
  tense,

  /// Nodal / karmic (Rahu or Ketu involved). Electric purple.
  wild,
}

/// A single "the sky is touching YOU right now" connection: a transiting planet
/// forming a tight aspect to a natal planet.
///
/// This is deliberately NOT every geometric aspect — only ones tight enough to
/// actually matter (see [computeSkyConnections]). The count rises and falls on
/// its own as the sky moves, which is exactly the drama we want.
class SkyConnection {
  /// Sign index (0=Aries) of the transiting planet — the line's start cell.
  final int fromSign;

  /// Sign index (0=Aries) of the natal planet — the line's end cell.
  final int toSign;

  final String transitPlanet;
  final String natalPlanet;

  final SkyConnectionNature nature;

  /// 0..1, where 1 is a near-exact aspect. Drives brightness/width and picks
  /// the single "hero" line.
  final double tightness;

  /// A plain-English one-liner, e.g. "Saturn is challenging your Moon".
  final String caption;

  const SkyConnection({
    required this.fromSign,
    required this.toSign,
    required this.transitPlanet,
    required this.natalPlanet,
    required this.nature,
    required this.tightness,
    required this.caption,
  });
}

/// Major aspect angles we care about. Conjunction is intentionally excluded —
/// a conjunction sits in the SAME sign cell, so it can't produce a meaningful
/// line; it's already visible from the two planets stacking together.
const Map<String, double> _aspectAngles = {
  'sextile': 60,
  'square': 90,
  'trine': 120,
  'opposition': 180,
};

const Map<String, String> _aspectVerb = {
  'sextile': 'supports',
  'square': 'challenges',
  'trine': 'blesses',
  'opposition': 'opposes',
};

const Set<String> _harmonious = {'sextile', 'trine'};

/// Max orb (degrees) for an aspect to count as "active now". Kept deliberately
/// tight — a loose aspect isn't happening yet. Tighter orb = fewer, more
/// meaningful lines (the count still floats: often 0–2, occasionally more).
const double _maxOrb = 2.0;

double _norm360(double d) {
  var x = d % 360;
  if (x < 0) x += 360;
  return x;
}

/// Angular separation 0..180.
double _separation(double a, double b) {
  final diff = _norm360(a - b).abs();
  return diff > 180 ? 360 - diff : diff;
}

int? _signOf(num? longitude) {
  if (longitude == null) return null;
  return (longitude / 30).floor() % 12;
}

String _titleCase(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();

SkyConnectionNature _natureFor(String aspect, String transit, String natal) {
  final t = transit.toLowerCase();
  final n = natal.toLowerCase();
  if (t.startsWith('ra') || t.startsWith('ke') ||
      n.startsWith('ra') || n.startsWith('ke')) {
    return SkyConnectionNature.wild;
  }
  return _harmonious.contains(aspect)
      ? SkyConnectionNature.supportive
      : SkyConnectionNature.tense;
}

/// Pull a planet-name → ecliptic-longitude map out of the transit positions
/// blob (keys like "Sun", values with a `longitude`).
Map<String, double> _transitLongitudes(Map<String, dynamic> positions) {
  final out = <String, double>{};
  positions.forEach((planet, data) {
    if (data is! Map) return;
    final m = Map<String, dynamic>.from(
        data.map((k, v) => MapEntry(k.toString(), v)));
    final lon = m['longitude'];
    if (lon is num) out[planet.toString()] = lon.toDouble();
  });
  return out;
}

/// Pull natal planet-name → longitude from the birth-chart blob.
Map<String, double> _natalLongitudes(Map<String, dynamic> birthChartData) {
  final out = <String, double>{};
  final planets = ChartUtils.extractPlanetsMap(birthChartData);
  if (planets == null) return out;
  planets.forEach((key, value) {
    if (value is! Map) return;
    final m = Map<String, dynamic>.from(
        value.map((k, v) => MapEntry(k.toString(), v)));
    final name = (m['name'] ?? key).toString();
    final lon = m['fullDegree'] ?? m['full_degree'] ?? m['longitude'];
    if (lon is num) out[name] = lon.toDouble();
  });
  return out;
}

/// Compute the tight transit→natal connections worth drawing right now.
///
/// Meaning gate, not a count cap: we keep every aspect within [_maxOrb] and let
/// the number float (0 on quiet days, several on charged ones). Same-sign
/// results are impossible here because conjunction is excluded.
List<SkyConnection> computeSkyConnections(
  Map<String, dynamic> transitPositions,
  Map<String, dynamic>? birthChartData,
) {
  if (birthChartData == null) return const [];
  final transit = _transitLongitudes(transitPositions);
  final natal = _natalLongitudes(birthChartData);
  if (transit.isEmpty || natal.isEmpty) return const [];

  final connections = <SkyConnection>[];
  transit.forEach((tName, tLon) {
    natal.forEach((nName, nLon) {
      final sep = _separation(tLon, nLon);
      for (final entry in _aspectAngles.entries) {
        final orb = (sep - entry.value).abs();
        if (orb > _maxOrb) continue;
        final fromSign = _signOf(tLon);
        final toSign = _signOf(nLon);
        if (fromSign == null || toSign == null || fromSign == toSign) continue;

        final aspect = entry.key;
        connections.add(SkyConnection(
          fromSign: fromSign,
          toSign: toSign,
          transitPlanet: tName,
          natalPlanet: nName,
          nature: _natureFor(aspect, tName, nName),
          tightness: 1.0 - (orb / _maxOrb),
          caption:
              '${_titleCase(tName)} ${_aspectVerb[aspect]} your ${_titleCase(nName)}',
        ));
        break; // one aspect per planet pair
      }
    });
  });

  // Strongest first, so the painter can treat connections.first as the hero.
  connections.sort((a, b) => b.tightness.compareTo(a.tightness));
  return connections;
}
