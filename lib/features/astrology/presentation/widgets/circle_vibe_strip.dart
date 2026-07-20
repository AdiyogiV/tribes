import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:aurogram/features/astrology/domain/circle_vibes_service.dart';
import 'package:aurogram/features/astrology/presentation/widgets/circle_flush_card.dart';
import 'package:aurogram/shared/presentation/widgets/avatars/user_avatar.dart';

/// Your circle — a flush black card (no border, no rounded corners) holding a
/// small-caps eyebrow and a row of grayscale, SQUARE portrait thumbnails.
/// The selected person is full-strength with a Georgia-italic name; the rest
/// recede.
class CircleVibeStrip extends StatefulWidget {
  const CircleVibeStrip({
    super.key,
    required this.selectedUid,
    required this.onSelect,
    required this.selfName,
    this.selfPhoto,
  });

  final String? selectedUid;
  final ValueChanged<CircleVibe?> onSelect;
  final String selfName;
  final String? selfPhoto;

  @override
  State<CircleVibeStrip> createState() => _CircleVibeStripState();
}

class _CircleVibeStripState extends State<CircleVibeStrip> {
  final _service = CircleVibesService();
  List<CircleVibe> _vibes = const [];
  final String? _selfUid = FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // 1) Paint instantly from today's cache (stale-while-revalidate).
    final cached = await _service.cachedVibes();
    if (mounted && cached.isNotEmpty) setState(() => _vibes = cached);
    // 2) Refresh from the network; update only if something actually changed.
    final fresh = await _service.fetchCircleVibes();
    if (mounted && fresh.isNotEmpty) setState(() => _vibes = fresh);
    // 3) Self-heal: if any friend is missing their third-person publicNote
    // (forecast predates the field), enqueue a one-off re-narration. Guarded
    // to fire at most once per day; the note shows up on a later fetch.
    if (fresh.isNotEmpty) await _service.backfillMissingPublicNotes(fresh);
  }

  @override
  Widget build(BuildContext context) {
    final vibes = _vibes;
    if (vibes.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fgMain = isDark ? Colors.white : Colors.black87;
    final fgMuted = isDark ? Colors.white54 : Colors.black54;

    final isWide = kIsWeb && MediaQuery.of(context).size.width >= 820;
    final eyebrowSize = isWide ? 12.0 : 10.0;
    final stripHeight = isWide ? 112.0 : 86.0;
    final photoW = isWide ? 68.0 : 52.0;
    final photoH = isWide ? 80.0 : 62.0;
    final tileW = isWide ? 86.0 : 66.0;
    final nameFontSize = isWide ? 15.0 : 12.0;

    return CircleFlushCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'YOUR CIRCLE',
            style: TextStyle(
              fontSize: eyebrowSize,
              fontWeight: FontWeight.w600,
              letterSpacing: 3.0,
              color: fgMuted,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: stripHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: vibes.length + 1,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                if (i == 0) {
                  return _PortraitTile(
                    uid: _selfUid,
                    name: 'You',
                    photo: widget.selfPhoto,
                    isSelected: widget.selectedUid == null,
                    fgMain: fgMain,
                    fgMuted: fgMuted,
                    photoW: photoW,
                    photoH: photoH,
                    tileW: tileW,
                    nameFontSize: nameFontSize,
                    onTap: () {
                          HapticFeedback.selectionClick();
                          widget.onSelect(null);
                        },
                      );
                    }
                    final vibe = vibes[i - 1];
                    return _PortraitTile(
                      uid: vibe.uid,
                      name: vibe.name,
                      photo: vibe.photo,
                      isSelected: widget.selectedUid == vibe.uid,
                      fgMain: fgMain,
                      fgMuted: fgMuted,
                      photoW: photoW,
                      photoH: photoH,
                      tileW: tileW,
                      nameFontSize: nameFontSize,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        widget.onSelect(vibe);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
  }
}

/// A grayscale, SQUARE portrait thumbnail (no rounded corners, no border) with
/// a Georgia-italic name beneath.
class _PortraitTile extends StatelessWidget {
  const _PortraitTile({
    this.uid,
    required this.name,
    required this.photo,
    required this.isSelected,
    required this.fgMain,
    required this.fgMuted,
    required this.onTap,
    this.photoW = 52.0,
    this.photoH = 62.0,
    this.tileW = 66.0,
    this.nameFontSize = 12.0,
  });

  final String? uid;
  final String name;
  final String? photo;
  final bool isSelected;
  final Color fgMain;
  final Color fgMuted;
  final VoidCallback onTap;
  final double photoW;
  final double photoH;
  final double tileW;
  final double nameFontSize;

  @override
  Widget build(BuildContext context) {
    Widget photoWidget = UserAvatar(
      userId: uid,
      imageUrl: photo,
      size: photoW,
      borderRadius: BorderRadius.zero,
      nameInitials: name.trim().isEmpty ? null : name.trim()[0],
      showBorder: false,
    );

    // Selected = full colour + full strength. Others recede into grayscale.
    if (!isSelected) {
      photoWidget = ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0,      0,      0,      1, 0,
        ]),
        child: photoWidget,
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: tileW,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedOpacity(
              duration: const Duration(milliseconds: 220),
              opacity: isSelected ? 1.0 : 0.4,
              child: SizedBox(
                width: photoW,
                height: photoH,
                child: photoWidget,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Georgia',
                fontStyle: FontStyle.italic,
                fontSize: nameFontSize,
                height: 1.0,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? fgMain : fgMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

}
