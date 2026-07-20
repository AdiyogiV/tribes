import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:aurogram/features/astrology/domain/circle_vibes_service.dart';
import 'package:aurogram/features/astrology/presentation/widgets/circle_flush_card.dart';

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
  }

  @override
  Widget build(BuildContext context) {
    final vibes = _vibes;
    if (vibes.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fgMain = isDark ? Colors.white : Colors.black87;
    final fgMuted = isDark ? Colors.white54 : Colors.black54;

    return CircleFlushCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'YOUR CIRCLE',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 3.0,
              color: fgMuted,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 86,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: vibes.length + 1,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                if (i == 0) {
                  return _PortraitTile(
                    name: 'You',
                    photo: widget.selfPhoto,
                    isSelected: widget.selectedUid == null,
                    fgMain: fgMain,
                    fgMuted: fgMuted,
                    onTap: () {
                          HapticFeedback.selectionClick();
                          widget.onSelect(null);
                        },
                      );
                    }
                    final vibe = vibes[i - 1];
                    return _PortraitTile(
                      name: vibe.name,
                      photo: vibe.photo,
                      isSelected: widget.selectedUid == vibe.uid,
                      fgMain: fgMain,
                      fgMuted: fgMuted,
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
    required this.name,
    required this.photo,
    required this.isSelected,
    required this.fgMain,
    required this.fgMuted,
    required this.onTap,
  });

  final String name;
  final String? photo;
  final bool isSelected;
  final Color fgMain;
  final Color fgMuted;
  final VoidCallback onTap;

  static const double _w = 52; // photo size
  static const double _h = 62;
  static const double _tileW = 66; // wider than the photo so names don't clip

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photo != null && photo!.isNotEmpty;

    Widget photoWidget = hasPhoto
        ? CachedNetworkImage(
            imageUrl: photo!,
            fit: BoxFit.cover,
            placeholder: (_, __) => _fallback(),
            errorWidget: (_, __, ___) => _fallback(),
          )
        : _fallback();

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
        width: _tileW,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedOpacity(
              duration: const Duration(milliseconds: 220),
              opacity: isSelected ? 1.0 : 0.4,
              child: SizedBox(
                width: _w,
                height: _h,
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
                fontSize: 12,
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

  Widget _fallback() => Container(
        color: fgMain.withValues(alpha: 0.05),
        alignment: Alignment.center,
        child: Text(
          name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase(),
          style: TextStyle(
            fontFamily: 'Georgia',
            fontStyle: FontStyle.italic,
            fontSize: 22,
            color: fgMain.withValues(alpha: 0.55),
          ),
        ),
      );
}
