import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:aurogram/features/astrology/domain/circle_vibes_service.dart';
import 'package:aurogram/features/astrology/presentation/widgets/circle_flush_card.dart';

/// "Today Together" — the transit cosmic-weather for the two of you today.
///
/// A dedicated flush card rendering the privacy-safe [TodayTogether] block the
/// backend derives from both people's full natal charts vs today's sky. Shows a
/// score meter, a name-aware reason or two, and taps through to a full
/// breakdown. Same flush/square surface + typography as the rest of the UI.
class FriendTogetherCard extends StatelessWidget {
  const FriendTogetherCard({
    super.key,
    required this.together,
    required this.friendName,
  });

  final TodayTogether together;
  final String friendName;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fgMain = isDark ? Colors.white : Colors.black87;
    final fgMuted = isDark ? Colors.white54 : Colors.black54;

    final hasDetail = together.connection.isNotEmpty;
    // Show the two strongest CONNECTION reasons on the card; rest in the sheet.
    final preview = <TogetherReason>[
      ...together.favorable.take(1),
      ...together.unfavorable.take(1),
    ];

    return CircleFlushCard(
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
      onTap: hasDetail
          ? () {
              HapticFeedback.selectionClick();
              _showDetail(context, isDark);
            }
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                'TODAY TOGETHER',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 3.0,
                  color: fgMuted,
                ),
              ),
              const Spacer(),
              if (hasDetail)
                Icon(Icons.chevron_right_rounded, size: 16, color: fgMuted),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  together.label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.4,
                    letterSpacing: 3.0,
                    fontWeight: FontWeight.w800,
                    color: fgMain,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${together.score}%',
                style: TextStyle(
                  fontSize: 16,
                  height: 1.4,
                  letterSpacing: 1.0,
                  fontWeight: FontWeight.w300,
                  color: fgMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _ScoreMeter(score: together.score, fgMain: fgMain, fgMuted: fgMuted),
          if (preview.isNotEmpty) ...[
            const SizedBox(height: 16),
            ...preview.map((r) => _ReasonLine(
                  text: r.phrase(friendName),
                  good: r.benefic,
                  fgMuted: fgMuted,
                )),
          ],
        ],
      ),
    );
  }

  void _showDetail(BuildContext context, bool isDark) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: isDark ? const Color(0xFF000000) : Colors.white,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _TogetherDetailSheet(
        together: together,
        friendName: friendName,
      ),
    );
  }
}

/// Thin monochrome gauge: a full-width track with a fill from 0 → score and a
/// marker dot at the score position. Left = "Lay Low", right = "In Flow".
class _ScoreMeter extends StatelessWidget {
  const _ScoreMeter({
    required this.score,
    required this.fgMain,
    required this.fgMuted,
  });

  final int score;
  final Color fgMain;
  final Color fgMuted;

  @override
  Widget build(BuildContext context) {
    final f = (score.clamp(0, 100)) / 100.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 6,
          child: LayoutBuilder(
            builder: (context, c) {
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  // Track
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      height: 2,
                      width: c.maxWidth,
                      color: fgMain.withValues(alpha: 0.12),
                    ),
                  ),
                  // Fill
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      height: 2,
                      width: c.maxWidth * f,
                      color: fgMain.withValues(alpha: 0.7),
                    ),
                  ),
                  // Marker dot
                  Positioned(
                    left: (c.maxWidth * f - 3).clamp(0.0, c.maxWidth - 6),
                    top: 0,
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: fgMain,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('LAY LOW', style: _endLabel(fgMuted)),
            Text('IN FLOW', style: _endLabel(fgMuted)),
          ],
        ),
      ],
    );
  }

  TextStyle _endLabel(Color c) => TextStyle(
        fontSize: 8,
        fontWeight: FontWeight.w600,
        letterSpacing: 2.0,
        color: c.withValues(alpha: 0.7),
      );
}

/// One classical reason line: a subtle up/down marker + Georgia-italic text.
class _ReasonLine extends StatelessWidget {
  const _ReasonLine({
    required this.text,
    required this.good,
    required this.fgMuted,
  });

  final String text;
  final bool good;
  final Color fgMuted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Icon(
              good ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
              size: 12,
              color: fgMuted,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
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
    );
  }
}

/// Full breakdown: every classical activation, grouped favourable/friction.
class _TogetherDetailSheet extends StatelessWidget {
  const _TogetherDetailSheet({required this.together, required this.friendName});

  final TodayTogether together;
  final String friendName;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fgMain = isDark ? Colors.white : Colors.black87;
    final fgMuted = isDark ? Colors.white54 : Colors.black54;

    final good = together.connection.where((a) => a.benefic).toList();
    final friction = together.connection.where((a) => !a.benefic).toList();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'TODAY TOGETHER',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 3.0,
                color: fgMuted,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  together.label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 20,
                    letterSpacing: 3.0,
                    fontWeight: FontWeight.w800,
                    color: fgMain,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${together.score}%',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w300,
                    color: fgMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (good.isNotEmpty) ...[
                      _SectionLabel('WHAT LIFTS YOU', fgMuted),
                      const SizedBox(height: 10),
                      ...good.map((a) => _ReasonLine(
                            text: a.phrase(friendName),
                            good: true,
                            fgMuted: fgMuted,
                          )),
                      const SizedBox(height: 18),
                    ],
                    if (friction.isNotEmpty) ...[
                      _SectionLabel('WHAT TO WATCH', fgMuted),
                      const SizedBox(height: 10),
                      ...friction.map((a) => _ReasonLine(
                            text: a.phrase(friendName),
                            good: false,
                            fgMuted: fgMuted,
                          )),
                    ],
                    if (good.isEmpty && friction.isEmpty)
                      Text(
                        'A quiet, neutral day between you.',
                        style: TextStyle(
                          fontFamily: 'Georgia',
                          fontStyle: FontStyle.italic,
                          fontSize: 15,
                          color: fgMuted,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, this.fgMuted);
  final String text;
  final Color fgMuted;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 2.5,
          color: fgMuted,
        ),
      );
}
