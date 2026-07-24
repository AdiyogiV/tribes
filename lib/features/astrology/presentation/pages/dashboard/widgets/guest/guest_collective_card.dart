import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/core/theme/dashboard_card_theme.dart';
import 'package:aurogram/shared/data/firebase/firestore_refs.dart';
import 'package:aurogram/features/astrology/presentation/pages/dashboard/widgets/guest/guest_atoms.dart';

/// The closing "collective" card — honest, live social proof.
///
/// Shows the REAL number of members on the app (a Firestore aggregate count of
/// the `users` collection, fetched at build) alongside a small stack of animal
/// DP avatars. No fabricated figures.
class GuestCollectiveCard extends StatefulWidget {
  const GuestCollectiveCard({super.key, required this.isDark});

  final bool isDark;

  @override
  State<GuestCollectiveCard> createState() => _GuestCollectiveCardState();
}

class _GuestCollectiveCardState extends State<GuestCollectiveCard> {
  // A handful of DP avatars to hint at real people (kept short + curated).
  static const _sampleAvatars = [
    'tiger',
    'peacock',
    'elephant',
    'cobra',
    'eagle',
    'stag',
  ];

  late final Future<int?> _memberCount = _fetchMemberCount();

  Future<int?> _fetchMemberCount() async {
    try {
      final snap = await FirestoreRefs.users.count().get();
      return snap.count;
    } catch (_) {
      // Rules / offline / permission — degrade gracefully to no number.
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = DashboardCardPalette.forBrightness(widget.isDark);

    return DashboardCard(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 52),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          GuestEyebrow(text: 'THE COLLECTIVE', color: palette.fgMuted),
          const SizedBox(height: 28),

          // Overlapping stack of real DP avatars.
          _AvatarStack(isDark: widget.isDark, animals: _sampleAvatars),
          const SizedBox(height: 32),

          // The live number.
          FutureBuilder<int?>(
            future: _memberCount,
            builder: (context, snap) {
              final count = snap.data;
              return _CountBlock(
                count: count,
                loading: snap.connectionState == ConnectionState.waiting,
                palette: palette,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CountBlock extends StatelessWidget {
  const _CountBlock({
    required this.count,
    required this.loading,
    required this.palette,
  });

  final int? count;
  final bool loading;
  final DashboardCardPalette palette;

  @override
  Widget build(BuildContext context) {
    // Headline number (or a graceful fallback when the count is unavailable).
    final Widget headline;
    if (loading) {
      headline = SizedBox(
        height: 40,
        width: 40,
        child: Center(
          child: SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: palette.fgFaint,
            ),
          ),
        ),
      );
    } else if (count != null && count! > 0) {
      headline = Text(
        NumberFormat.decimalPattern().format(count),
        style: TextStyle(
          fontFamily: 'Georgia',
          fontSize: 44,
          fontWeight: FontWeight.w400,
          color: palette.fgMain,
          height: 1.0,
          letterSpacing: -0.5,
        ),
      );
    } else {
      headline = Text(
        'A growing collective',
        style: TextStyle(
          fontFamily: 'Georgia',
          fontStyle: FontStyle.italic,
          fontSize: 28,
          color: palette.fgMain,
        ),
      );
    }

    return Column(
      children: [
        headline,
        const SizedBox(height: 10),
        Text(
          count != null && count! > 0
              ? 'souls reading the sky on Aurogram'
              : 'reading the sky on Aurogram',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: palette.fgMuted,
            fontSize: AppTheme.babaTextSize,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

/// A tight overlapping row of DP avatars.
class _AvatarStack extends StatelessWidget {
  const _AvatarStack({required this.isDark, required this.animals});

  final bool isDark;
  final List<String> animals;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final animal in animals)
          Align(
            widthFactor: 0.68, // overlap by ~32%
            child: GuestAnimalAvatar(
              animal: animal,
              size: 48,
              isDark: isDark,
            ),
          ),
      ],
    );
  }
}
