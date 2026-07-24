import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/core/theme/dashboard_card_theme.dart';
import 'package:aurogram/shared/data/firebase/firestore_refs.dart';
import 'package:aurogram/features/astrology/data/utils/yoni_tribe.dart';
import 'package:aurogram/features/astrology/presentation/pages/dashboard/widgets/guest/guest_atoms.dart';

/// Live social proof: the REAL member count first, then a wall of real DPs.
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
    if (candidates.length < _DpWall.maxTarget) {
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
  static const _poolSize = 20;
  @override
  Widget build(BuildContext context) {
    final palette = DashboardCardPalette.forBrightness(widget.isDark);

    return DashboardCard(
      padding: EdgeInsets.zero,
      child: FutureBuilder<_CollectiveData>(
        future: _data,
        builder: (context, snap) {
          final data = snap.data;
          final loading = snap.connectionState == ConnectionState.waiting;

          final textSection = Column(
            crossAxisAlignment: widget.isWide
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              GuestEyebrow(text: 'THE COLLECTIVE', color: palette.accent),
              const SizedBox(height: 24),
              _CountHeadline(
                count: data?.count,
                loading: loading,
                palette: palette,
                isWide: widget.isWide,
              ),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Text(
                  'Real people, real charts — a living collective growing every '
                  'day. Your spirit is already waiting among them.',
                  textAlign: widget.isWide ? TextAlign.left : TextAlign.center,
                  style: TextStyle(
                    color: palette.fgMuted,
                    fontSize: AppTheme.babaTextSize + 1,
                    height: 1.55,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          );

          final avatarSection = _DpWall(
            isDark: widget.isDark,
            dpUrls: data?.dpUrls ?? const [],
            totalCount: data?.count,
            isWide: widget.isWide,
          );

          if (widget.isWide) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 64),
              child: Row(
                children: [
                  Expanded(flex: 5, child: textSection),
                  const SizedBox(width: 48),
                  Expanded(
                    flex: 5,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: avatarSection,
                    ),
                  ),
                ],
              ),
            );
          } else {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 52),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  textSection,
                  const SizedBox(height: 48),
                  avatarSection,
                ],
              ),
            );
          }
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
    required this.isWide,
  });

  final int? count;
  final bool loading;
  final DashboardCardPalette palette;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return SizedBox(
        height: 56,
        child: Align(
          alignment: isWide ? Alignment.centerLeft : Alignment.center,
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
      return EditorialCardHeader(
        leading: "Growing ",
        trailing: "collective.",
        palette: palette,
        titleSize: isWide ? 44 : 36,
      );
    }

    return EditorialCardHeader(
      leading: "${NumberFormat.decimalPattern().format(count)} ",
      trailing: "members.",
      palette: palette,
      titleSize: isWide ? 52 : 44,
      subtitle: "AND COUNTING",
      subtitleSize: 10,
    );
  }
}

/// A dense wall of small square DP avatars — real users first, then animal
/// DPs to fill out the grid so it always looks populated.
class _DpWall extends StatelessWidget {
  const _DpWall({
    required this.isDark,
    required this.dpUrls,
    required this.totalCount,
    required this.isWide,
  });

  final bool isDark;
  final List<String> dpUrls;
  final int? totalCount;
  final bool isWide;

  static const maxTarget = 15;

  @override
  Widget build(BuildContext context) {
    final target = isWide ? maxTarget : 10;
    final size = isWide ? 48.0 : 40.0;

    final animals = YoniTribeData.all;

    // Build up to [target] tiles: real DPs first (each with an animal fallback
    // so a photo that fails to decode self-heals instead of going blank), then
    // pure animal tiles fill any remainder so the row always looks populated.
    final tiles = <_Tile>[];
    for (final url in dpUrls.take(target)) {
      final animal = animals[tiles.length % animals.length].animal;
      tiles.add(_Tile(url: url, fallbackUrl: guestAnimalUrl(animal)));
    }
    while (tiles.length < target) {
      final animal = animals[tiles.length % animals.length].animal;
      tiles.add(_Tile(url: guestAnimalUrl(animal)));
    }

    // "+N more" where N is everyone beyond the avatars we show.
    final remaining =
        (totalCount != null && totalCount! > target) ? totalCount! - target : 0;

    return Wrap(
      alignment: isWide ? WrapAlignment.end : WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 12,
      children: [
        for (final tile in tiles)
          Align(
            widthFactor: 0.72, // tight overlap
            alignment: Alignment.centerLeft,
            child: GuestUrlAvatar(
              url: tile.url,
              fallbackUrl: tile.fallbackUrl,
              size: size,
              isDark: isDark,
              borderWidth: 2.5,
              square: false, // Made them circle for a more premium organic look
            ),
          ),
        if (remaining > 0)
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: _MorePill(count: remaining, isDark: isDark, height: size),
          ),
      ],
    );
  }
}

/// A "+N more" chip shown after the avatar row.
class _MorePill extends StatelessWidget {
  const _MorePill({
    required this.count,
    required this.isDark,
    required this.height,
  });

  final int count;
  final bool isDark;
  final double height;

  @override
  Widget build(BuildContext context) {
    final fg = isDark ? Colors.white : Colors.black87;
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(height / 2),
        border: Border.all(
          color: isDark ? Colors.white24 : Colors.black.withValues(alpha: 0.12),
        ),
      ),
      child: Text(
        '+${NumberFormat.decimalPattern().format(count)} more',
        style: TextStyle(
          color: fg,
          fontSize: height > 40 ? 14 : 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _Tile {
  const _Tile({required this.url, this.fallbackUrl});
  final String url;
  final String? fallbackUrl;
}
