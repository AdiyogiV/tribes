import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:aurogram/features/astrology/domain/circle_vibes_service.dart';
import 'package:aurogram/features/astrology/presentation/widgets/circle_flush_card.dart';
import 'package:aurogram/features/astrology/presentation/widgets/friend_together_card.dart';
import 'package:aurogram/features/profile/domain/namaste_service.dart';

/// The in-place friend view — what the dashboard swaps to when you select a
/// friend in the strip. Friend day card + compatibility + view-profile link.
class FriendCosmicView extends StatelessWidget {
  const FriendCosmicView({super.key, required this.vibe});

  final CircleVibe vibe;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? Colors.white54 : Colors.black54;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FriendDayCard(vibe: vibe),
        const SizedBox(height: 16),
        // Current (daily transit) cosmic weather for the two of you.
        if (vibe.together != null) ...[
          FriendTogetherCard(together: vibe.together!, friendName: vibe.name),
          const SizedBox(height: 16),
        ],
        Center(
          child: TextButton(
            onPressed: () => context.push('/user/${vibe.uid}'),
            child: Text(
              'VIEW FULL PROFILE',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w500,
                letterSpacing: 3.0,
                color: muted,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Purpose-built friend day card: pure editorial typography on the flush card
/// surface. Georgia-italic hero, small-caps eyebrow, arrow-link action.
class FriendDayCard extends StatefulWidget {
  const FriendDayCard({super.key, required this.vibe});

  final CircleVibe vibe;

  @override
  State<FriendDayCard> createState() => _FriendDayCardState();
}

class _FriendDayCardState extends State<FriendDayCard> {
  bool _sending = false;
  bool _sent = false;

  Future<void> _sendNamaste() async {
    if (_sending || _sent) return;
    setState(() => _sending = true);
    HapticFeedback.lightImpact();

    final result = await NamasteService().sendNamaste(widget.vibe.uid);
    if (!mounted) return;

    final ok = result.success || result.alreadySentToday;
    setState(() {
      _sending = false;
      _sent = ok;
    });

    String msg;
    if (result.success) {
      msg = 'Energy sent to ${widget.vibe.name}';
      HapticFeedback.mediumImpact();
    } else if (result.alreadySentToday) {
      msg = 'Already sent energy to ${widget.vibe.name} today';
    } else if (result.quotaExceeded) {
      msg = "You're out of energy sends for today";
    } else {
      msg = 'Could not send energy';
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fgMain = isDark ? Colors.white : Colors.black87;
    final fgMuted = isDark ? Colors.white54 : Colors.black54;
    final hasNote =
        widget.vibe.publicNote != null && widget.vibe.publicNote!.isNotEmpty;

    return CircleFlushCard(
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Eyebrow — "ABHINAV · TODAY", small-caps, wide-tracked.
          Text(
            '${widget.vibe.name.toUpperCase()}  ·  TODAY',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 3.0,
              color: fgMuted,
            ),
          ),
          const SizedBox(height: 18),
          // The hero: the vibe word — matches the user's own Daily Vibe card
          // heading exactly (uppercase, 16px, w800, wide-tracked).
          Text(
            widget.vibe.vibe.toUpperCase(),
            style: TextStyle(
              fontSize: 16,
              height: 1.4,
              letterSpacing: 3.0,
              fontWeight: FontWeight.w800,
              color: fgMain,
            ),
          ),
          if (hasNote) ...[
            const SizedBox(height: 14),
            Text(
              widget.vibe.publicNote!,
              style: TextStyle(
                fontFamily: 'Georgia',
                fontStyle: FontStyle.italic,
                fontSize: 14.5,
                height: 1.5,
                color: fgMuted,
              ),
            ),
          ],
          // The friend's OWN transit weather today (their personal energy).
          if (widget.vibe.energy.isNotEmpty) ...[
            const SizedBox(height: 16),
            ...widget.vibe.energy.take(3).map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Icon(
                          e.benefic
                              ? Icons.arrow_upward_rounded
                              : Icons.arrow_downward_rounded,
                          size: 12,
                          color: fgMuted,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          e.phrase(),
                          style: TextStyle(
                            fontFamily: 'Georgia',
                            fontStyle: FontStyle.italic,
                            fontSize: 14.5,
                            height: 1.4,
                            color: fgMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
          const SizedBox(height: 26),
          _EnergyLink(
            sending: _sending,
            sent: _sent,
            onTap: _sendNamaste,
            fgMain: fgMain,
            fgMuted: fgMuted,
          ),
        ],
      ),
    );
  }
}

/// A chic arrow-link action — purely typographic, no pill, no rounded corners.
class _EnergyLink extends StatelessWidget {
  const _EnergyLink({
    required this.sending,
    required this.sent,
    required this.onTap,
    required this.fgMain,
    required this.fgMuted,
  });

  final bool sending;
  final bool sent;
  final VoidCallback onTap;
  final Color fgMain;
  final Color fgMuted;

  @override
  Widget build(BuildContext context) {
    String label = 'SEND NAMASTE ENERGY';
    IconData icon = Icons.arrow_forward_rounded;
    if (sending) {
      label = 'SENDING';
    } else if (sent) {
      label = 'ENERGY SENT';
      icon = Icons.check_rounded;
    }

    final Color color = sent ? fgMuted : fgMain;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: sending || sent ? null : onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 3.0,
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          Icon(icon, size: 14, color: color),
        ],
      ),
    );
  }
}
