import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/core/theme/dashboard_card_theme.dart';
import 'package:aurogram/shared/data/firebase/firestore_refs.dart';
import 'package:aurogram/features/astrology/data/utils/yoni_tribe.dart';
import 'package:aurogram/features/astrology/presentation/pages/dashboard/widgets/guest/guest_atoms.dart';

/// Live social proof: the REAL member count first, then a wall of real DPs.
class GuestCollectiveCard extends StatefulWidget {
  const GuestCollectiveCard({super.key, required this.isDark});

  final bool isDark;

  @override
  State<GuestCollectiveCard> createState() => _GuestCollectiveCardState();
}

class _GuestCollectiveCardState extends State<GuestCollectiveCard> {
  late final Future<_CollectiveData> _data = _fetch();

  Future<_CollectiveData> _fetch() async {
    int? count;
    final candidates = <String>[];
    final seen = <String>{};

    try {
      final countSnap = await FirestoreRefs.users.count().get();
      count = countSnap.count;
    } catch (_) {/* rules / offline — degrade gracefully */}

    void addFrom(Iterable<dynamic> docs) {
      for (final doc in docs) {
        final data = doc.data() as Map<String, dynamic>?;
        final pic = data?['displayPicture'] as String?;
        if (pic != null && pic.startsWith('http') && seen.add(pic)) {
          candidates.add(pic);
        }
      }
    }

    // Latest-joined members that have a DP. We fetch a SMALL pool with a few
    // spares (target + buffer) — not hundreds — to keep Firestore reads and
    // memory tiny. We do NOT pre-download or decode-test here: that blocked the
    // card for seconds and caused bitmap/GC storms. Instead each tile renders
    // immediately and self-heals to an animal if its photo can't decode.
    try {
      final latest = await FirestoreRefs.users
          .orderBy('timestamp', descending: true)
          .limit(_poolSize)
          .get();
      addFrom(latest.docs);
    } catch (_) {/* ignore */}

    // Only if the newest signups are photo-less do we backfill with older
    // accounts that have a DP (these predate the `timestamp` field).
    if (candidates.length < _DpWall.target) {
      try {
        final withDp = await FirestoreRefs.users
            .where('displayPicture', isGreaterThan: '')
            .limit(_poolSize)
            .get();
        addFrom(withDp.docs);
      } catch (_) {/* ignore */}
    }

    return _CollectiveData(count: count, dpUrls: candidates);
  }

  /// Small candidate pool: the target wall size plus a handful of spares so a
  /// few un-decodable photos can be swapped for animals without a re-query.
  static const _poolSize = 40;
  @override
  Widget build(BuildContext context) {
    final palette = DashboardCardPalette.forBrightness(widget.isDark);

    return DashboardCard(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 52),
      child: FutureBuilder<_CollectiveData>(
        future: _data,
        builder: (context, snap) {
          final data = snap.data;
          final loading = snap.connectionState == ConnectionState.waiting;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              GuestEyebrow(text: 'THE COLLECTIVE', color: palette.fgMuted),
              const SizedBox(height: 28),

              // 1. The number FIRST.
              _CountHeadline(
                count: data?.count,
                loading: loading,
                palette: palette,
              ),
              const SizedBox(height: 14),

              // 2. Improved supporting copy.
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Text(
                  'Real people, real charts — a living collective growing every '
                  'day. Your spirit is already waiting among them.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: palette.fgMuted,
                    fontSize: AppTheme.babaTextSize,
                    height: 1.55,
                  ),
                ),
              ),
              const SizedBox(height: 40),

              // 3. The DP wall — real users first, animals as fallback filler.
              _DpWall(isDark: widget.isDark, dpUrls: data?.dpUrls ?? const []),
            ],
          );
        },
      ),
    );
  }
}

class _CollectiveData {
  const _CollectiveData({required this.count, required this.dpUrls});
  final int? count;
  final List<String> dpUrls;
}

class _CountHeadline extends StatelessWidget {
  const _CountHeadline({
    required this.count,
    required this.loading,
    required this.palette,
  });

  final int? count;
  final bool loading;
  final DashboardCardPalette palette;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return SizedBox(
        height: 56,
        child: Center(
          child: SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: palette.fgFaint),
          ),
        ),
      );
    }

    if (count == null || count! <= 0) {
      return Text(
        'A growing collective',
        style: TextStyle(
          fontFamily: 'Georgia',
          fontStyle: FontStyle.italic,
          fontSize: 30,
          color: palette.fgMain,
        ),
      );
    }

    return Column(
      children: [
        Text(
          NumberFormat.decimalPattern().format(count),
          style: TextStyle(
            fontFamily: 'Georgia',
            fontSize: 52,
            fontWeight: FontWeight.w400,
            color: palette.fgMain,
            height: 1.0,
            letterSpacing: -1.0,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'MEMBERS AND COUNTING',
          style: TextStyle(
            color: palette.fgMuted,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.5,
          ),
        ),
      ],
    );
  }
}

/// A dense wall of small square DP avatars — real users first, then animal
/// DPs to fill out the grid so it always looks populated.
class _DpWall extends StatelessWidget {
  const _DpWall({required this.isDark, required this.dpUrls});

  final bool isDark;
  final List<String> dpUrls;

  static const target = 21; // 3 rows of 7-ish when wrapped
  static const _size = 40.0;

  @override
  Widget build(BuildContext context) {
    final animals = YoniTribeData.all;

    // Build the tile list: real DPs first (each with an animal fallback so a
    // photo that fails to decode self-heals instead of going blank), then pure
    // animal tiles fill any remainder so the wall always looks populated.
    final tiles = <_Tile>[];
    for (final url in dpUrls.take(target)) {
      final animal = animals[tiles.length % animals.length].animal;
      tiles.add(_Tile(url: url, fallbackUrl: guestAnimalUrl(animal)));
    }
    while (tiles.length < target) {
      final animal = animals[tiles.length % animals.length].animal;
      tiles.add(_Tile(url: guestAnimalUrl(animal)));
    }

    return Wrap(
      alignment: WrapAlignment.center,
      runSpacing: 10,
      children: [
        for (final tile in tiles)
          Align(
            widthFactor: 0.74, // tight overlap
            alignment: Alignment.centerLeft,
            child: GuestUrlAvatar(
              url: tile.url,
              fallbackUrl: tile.fallbackUrl,
              size: _size,
              isDark: isDark,
              borderWidth: 2,
              square: true,
            ),
          ),
      ],
    );
  }
}

class _Tile {
  const _Tile({required this.url, this.fallbackUrl});
  final String url;
  final String? fallbackUrl;
}
