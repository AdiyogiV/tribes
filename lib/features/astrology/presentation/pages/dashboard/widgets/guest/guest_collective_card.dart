import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:aurogram/core/storage/image_optimizer.dart';
import 'package:aurogram/core/theme/dashboard_card_theme.dart';
import 'package:aurogram/shared/data/firebase/firestore_refs.dart';
import 'package:aurogram/features/astrology/data/utils/yoni_tribe.dart';
import 'package:aurogram/features/astrology/presentation/pages/dashboard/widgets/guest/guest_atoms.dart';

class GuestCollectiveCard extends StatefulWidget {
  const GuestCollectiveCard({
    super.key,
    required this.isDark,
    required this.isWide,
  });

  final bool isDark;
  final bool isWide;

  @override
  State<GuestCollectiveCard> createState() => _GuestCollectiveCardState();
}

class _GuestCollectiveCardState extends State<GuestCollectiveCard> {
  // In-memory caches shared across every mount of this card. Guests hop on and
  // off the dashboard constantly; there's no reason to re-hit Firestore each
  // time. The collective count and member pool barely change second to second.
  static Future<List<String>>? _avatarsCache;
  static Future<int?>? _countCache;

  late final Future<List<String>> _avatars = _avatarsCache ??= _fetchAvatars();
  late final Future<int?> _count = _countCache ??= _fetchCount();

  // The count is a full-collection aggregation — the slowest call — so we run it
  // on its own and never let it gate the avatar pile.
  Future<int?> _fetchCount() async {
    try {
      final countSnap = await FirestoreRefs.users.count().get();
      return countSnap.count;
    } catch (_) {
      return null;
    }
  }

  Future<List<String>> _fetchAvatars() async {
    final candidates = <String>[];
    final seen = <String>{};

    void addFrom(Iterable<dynamic> docs) {
      for (final doc in docs) {
        final data = doc.data() as Map<String, dynamic>?;
        final pic = data?['displayPicture'] as String?;
        if (pic != null && pic.startsWith('http') && seen.add(pic)) {
          candidates.add(pic);
        }
      }
    }

    // Fire both the "latest" and "has a DP" queries in parallel up front instead
    // of awaiting the fallback only after the first returns. One extra read is
    // far cheaper than a second sequential round-trip on a cold card.
    Future<QuerySnapshot?> safeGet(Query query) async {
      try {
        return await query.get();
      } catch (_) {
        return null;
      }
    }

    final results = await Future.wait([
      safeGet(FirestoreRefs.users
          .orderBy('timestamp', descending: true)
          .limit(20)),
      safeGet(FirestoreRefs.users
          .where('displayPicture', isGreaterThan: '')
          .limit(20)),
    ]);

    for (final snap in results) {
      if (snap != null) addFrom(snap.docs);
    }

    // Randomise the order once per session so the pile shows a fresh mix of
    // real members (we always have a healthy pool of ~20). Cached thereafter.
    candidates.shuffle(math.Random());

    return candidates;
  }

  @override
  Widget build(BuildContext context) {
    final palette = DashboardCardPalette.forBrightness(widget.isDark);

    return DashboardCard(
      padding: EdgeInsets.zero,
      child: FutureBuilder<List<String>>(
        future: _avatars,
        builder: (context, snap) {
          final dpUrls = snap.data ?? const <String>[];

          return Padding(
            padding: EdgeInsets.symmetric(
              horizontal: widget.isWide ? 48 : 28,
              vertical: widget.isWide ? 64 : 52,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                GuestEyebrow(text: 'THE COLLECTIVE', color: palette.accent),
                const SizedBox(height: 40),

                // The hero: a tossed pile of member photos, fashion-app style.
                // Rendered instantly with nakshatra-animal fallbacks; real
                // member DPs swap in as the Firestore query resolves. No
                // spinner, no blocking on the network.
                _AvatarPile(
                  isDark: widget.isDark,
                  dpUrls: dpUrls,
                  isWide: widget.isWide,
                ),

                const SizedBox(height: 44),

                // Editorial stat line — the number is the star. It rides its own
                // future so the slow full-collection count never holds up the
                // rest of the card.
                FutureBuilder<int?>(
                  future: _count,
                  builder: (context, countSnap) => _CollectiveStat(
                    count: countSnap.data,
                    palette: palette,
                    isWide: widget.isWide,
                  ),
                ),
                const SizedBox(height: 18),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 340),
                  child: Text(
                    'Every face is a chart in motion — real people reading the '
                    'same sky, at the very same moment as you.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: palette.fgMuted,
                      fontSize: 14.5,
                      height: 1.6,
                      letterSpacing: -0.1,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// The editorial number + label, centred. The count is the visual anchor.
class _CollectiveStat extends StatelessWidget {
  const _CollectiveStat({
    required this.count,
    required this.palette,
    required this.isWide,
  });

  final int? count;
  final DashboardCardPalette palette;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final hasCount = count != null && count! > 0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            children: [
              TextSpan(
                text: hasCount
                    ? NumberFormat.decimalPattern().format(count)
                    : 'A living',
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontStyle: FontStyle.italic,
                  fontSize: isWide ? 60 : 48,
                  fontWeight: FontWeight.w400,
                  color: palette.fgMain,
                  letterSpacing: -1.5,
                  height: 1.0,
                ),
              ),
              TextSpan(
                text: hasCount ? ' souls' : ' sky',
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontStyle: FontStyle.italic,
                  fontSize: isWide ? 60 : 48,
                  fontWeight: FontWeight.w300,
                  color: palette.fgMuted,
                  letterSpacing: -1.5,
                  height: 1.0,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'MAPPING THE SKY, RIGHT NOW',
          style: TextStyle(
            color: palette.accent,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 3.0,
          ),
        ),
      ],
    );
  }
}

/// A tossed "pile" of member photos — overlapping rounded-square tiles fanned
/// with subtle rotation and depth, the way modern fashion/social apps show a
/// crowd. Center tile sits highest & on top.
class _AvatarPile extends StatelessWidget {
  const _AvatarPile({
    required this.isDark,
    required this.dpUrls,
    required this.isWide,
  });

  final bool isDark;
  final List<String> dpUrls;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final n = isWide ? 13 : 11;
    final animals = YoniTribeData.all;

    String fallback(int i) =>
        guestAnimalUrl(animals[i % animals.length].animal);
    String urlAt(int i) => i < dpUrls.length ? dpUrls[i] : fallback(i);

    const overlapFrac = 0.62; // step as a fraction of tile size
    const arcRise = 10.0; // how much the outer tiles lift
    const rotUnit = 4.0; // degrees per step from centre
    final maxSize = isWide ? 74.0 : 58.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Fit all n tiles into the available width: totalWidth grows with tile
        // size, so shrink the tiles until the whole pile fits, capped so it
        // still looks chunky on roomy screens.
        final avail = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : maxSize * (overlapFrac * (n - 1) + 1);
        final denom = overlapFrac * (n - 1) + 1;
        final size = math.min(maxSize, avail / denom);
        final step = size * overlapFrac;

        final mid = (n - 1) / 2.0;
        final totalWidth = step * (n - 1) + size;
        final topRoom = arcRise * mid;

        // Build tiles, then order so the centre paints last (sits on top).
        final order = List<int>.generate(n, (i) => i)
          ..sort((a, b) => (b - mid).abs().compareTo((a - mid).abs()));

        final children = <Widget>[];
        for (final i in order) {
          final offset = i - mid;
          final left = i * step;
          final top = topRoom - (offset.abs() * arcRise);
          final rot = offset * rotUnit * math.pi / 180.0;
          // Centre tile a touch larger for a curated focal point.
          final scale = i == mid ? 1.14 : 1.0;
          final tileSize = size * scale;
          final dx = left - (tileSize - size) / 2;
          final dy = top - (tileSize - size) / 2;

          children.add(Positioned(
            left: dx,
            top: dy,
            child: Transform.rotate(
              angle: rot,
              child: _PileTile(
                url: urlAt(i),
                fallbackUrl: fallback(i),
                size: tileSize,
                isDark: isDark,
              ),
            ),
          ));
        }

        return SizedBox(
          width: totalWidth,
          height: size * 1.14 + topRoom,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: children,
          ),
        );
      },
    );
  }
}

/// A single edge-to-edge square photo tile: no border, no rounding, no inset.
/// Just a subtle drop shadow so overlapping tiles read as stacked.
class _PileTile extends StatelessWidget {
  const _PileTile({
    required this.url,
    required this.fallbackUrl,
    required this.size,
    required this.isDark,
  });

  final String url;
  final String fallbackUrl;
  final double size;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : Colors.black12,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.18),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ImageOptimizer.buildOptimizedImage(
        url: url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorWidget: ImageOptimizer.buildOptimizedImage(
          url: fallbackUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
