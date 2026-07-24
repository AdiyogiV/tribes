import 'dart:async';

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

    try {
      final countSnap = await FirestoreRefs.users.count().get();
      count = countSnap.count;
    } catch (_) {/* rules / offline — degrade gracefully */}

    // Collect candidate DPs, latest-joined first, deduped. We over-fetch on
    // purpose: many users have no photo and some DPs are HEIC/HEVC that this
    // device can't decode — both get dropped later, so we need spares.
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

    // 1. Latest-joined members that have a DP (users are stamped with
    //    `timestamp` at registration).
    try {
      final latest = await FirestoreRefs.users
          .orderBy('timestamp', descending: true)
          .limit(160)
          .get();
      addFrom(latest.docs);
    } catch (_) {/* ignore */}

    // 2. Backfill with ANY users that have a DP — covers older accounts created
    //    before the `timestamp` field existed (which orderBy(timestamp) skips),
    //    so the wall stays full of real photos, not animals, when the newest
    //    signups happen to be photo-less.
    try {
      final withDp = await FirestoreRefs.users
          .where('displayPicture', isGreaterThan: '')
          .limit(80)
          .get();
      addFrom(withDp.docs);
    } catch (_) {/* ignore */}

    // Keep ONLY the DPs that actually decode on this device. Anything the
    // platform image decoder rejects (unsupported HEIC/HEVC/corrupt) is
    // discarded so it's never rendered as a blank tile. Validating also warms
    // the image cache, so the subsequent render is instant.
    final working = await _decodableUrls(candidates, want: _DpWall.target);

    return _CollectiveData(count: count, dpUrls: working);
  }

  /// Returns up to [want] urls from [urls] that successfully decode into an
  /// image on this device, preserving the original order.
  Future<List<String>> _decodableUrls(
    List<String> urls, {
    required int want,
  }) async {
    final results = await Future.wait(urls.map(_canDecode));
    final ok = <String>[];
    for (var i = 0; i < urls.length; i++) {
      if (results[i]) {
        ok.add(urls[i]);
        if (ok.length >= want) break;
      }
    }
    return ok;
  }

  /// Attempts to resolve [url] into a decoded frame. Completes false on any
  /// decode/network error or after a timeout — mirrors the exact decode path
  /// the avatar will use, so a pass here guarantees the tile won't be blank.
  Future<bool> _canDecode(String url) {
    final completer = Completer<bool>();
    final stream = NetworkImage(url).resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;
    void done(bool ok) {
      if (!completer.isCompleted) completer.complete(ok);
      stream.removeListener(listener);
    }

    listener = ImageStreamListener(
      (info, _) => done(true),
      onError: (_, __) => done(false),
    );
    stream.addListener(listener);
    return completer.future.timeout(
      const Duration(seconds: 8),
      onTimeout: () {
        stream.removeListener(listener);
        return false;
      },
    );
  }

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
    // Compose the final url list: real DPs first, animal DPs as filler.
    final urls = <String>[...dpUrls.take(target)];
    if (urls.length < target) {
      final animals = YoniTribeData.all;
      var i = 0;
      while (urls.length < target) {
        urls.add(guestAnimalUrl(animals[i % animals.length].animal));
        i++;
      }
    }

    return Wrap(
      alignment: WrapAlignment.center,
      runSpacing: 10,
      children: [
        for (final url in urls)
          Align(
            widthFactor: 0.74, // tight overlap
            alignment: Alignment.centerLeft,
            child: GuestUrlAvatar(
              url: url,
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
