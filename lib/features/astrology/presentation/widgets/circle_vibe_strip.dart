import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';
import 'package:aurogram/features/astrology/domain/circle_vibes_service.dart';

/// "Friends Today" — a horizontal strip of your mutual-follows with each
/// friend's vibe word for today (the Co-Star social hook).
///
/// Deliberately minimal: a face + a word, nothing else. No number, no ring.
/// Tapping a friend opens their profile (which already surfaces the full
/// compatibility funnel). Hides itself entirely when there's nothing to show,
/// so it never leaves an empty hole on the dashboard.
class CircleVibeStrip extends StatefulWidget {
  const CircleVibeStrip({super.key});

  @override
  State<CircleVibeStrip> createState() => _CircleVibeStripState();
}

class _CircleVibeStripState extends State<CircleVibeStrip> {
  late Future<List<CircleVibe>> _future;

  @override
  void initState() {
    super.initState();
    _future = CircleVibesService().fetchCircleVibes();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CircleVibe>>(
      future: _future,
      builder: (context, snapshot) {
        final vibes = snapshot.data ?? const <CircleVibe>[];
        // Silent until we have something worth showing — no spinner, no
        // empty-state clutter on the dashboard.
        if (vibes.isEmpty) return const SizedBox.shrink();
        return _buildStrip(context, vibes);
      },
    );
  }

  Widget _buildStrip(BuildContext context, List<CircleVibe> vibes) {
    final brown = AppTheme.primaryColor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: AppDimensions.paddingXs,
            bottom: AppDimensions.spacingSm,
          ),
          child: Text(
            'IN YOUR ORBIT',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
              color: brown.withValues(alpha: 0.55),
            ),
          ),
        ),
        SizedBox(
          height: 116,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.paddingXs),
            itemCount: vibes.length,
            separatorBuilder: (_, __) =>
                const SizedBox(width: AppDimensions.spacingMd),
            itemBuilder: (_, i) => _VibeFace(vibe: vibes[i], accent: brown),
          ),
        ),
        const SizedBox(height: AppDimensions.spacingMd),
      ],
    );
  }
}

/// One friend: avatar, name, and their vibe word.
class _VibeFace extends StatelessWidget {
  const _VibeFace({required this.vibe, required this.accent});

  final CircleVibe vibe;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = vibe.photo != null && vibe.photo!.isNotEmpty;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => context.push('/user/${vibe.uid}'),
      child: SizedBox(
        width: 76,
        child: Column(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: accent.withValues(alpha: 0.12),
              backgroundImage:
                  hasPhoto ? CachedNetworkImageProvider(vibe.photo!) : null,
              child: hasPhoto
                  ? null
                  : Text(
                      _initial(vibe.name),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: accent,
                      ),
                    ),
            ),
            const SizedBox(height: AppDimensions.spacingXs),
            Text(
              vibe.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: accent,
              ),
            ),
            Text(
              vibe.vibe,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                height: 1.15,
                color: accent.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _initial(String name) {
    final trimmed = name.trim();
    return trimmed.isEmpty ? '?' : trimmed[0].toUpperCase();
  }
}
