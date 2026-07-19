import 'package:flutter/material.dart';
import 'package:aurogram/features/astrology/domain/circle_vibes_service.dart';
import 'package:aurogram/features/astrology/presentation/widgets/circle_vibe_strip.dart';
import 'package:aurogram/features/astrology/presentation/widgets/friend_day_view.dart';

/// Builds the dashboard content given the selector [stripSlot] and an optional
/// [bodyOverride] (the friend view). The parent (dashboard) wires these into
/// [BabaCosmicContent] so the common date card stays on top for everyone, the
/// strip sits directly below it, and only the body swaps.
typedef CircleContentBuilder = Widget Function(
  BuildContext context, {
  Widget? stripSlot,
  Widget? bodyOverride,
});

/// Owns the "who am I viewing" selection and swaps the dashboard body IN PLACE
/// (no popups):
///   - selected == you  → your full cosmic dashboard.
///   - selected == friend → the purpose-built [FriendCosmicView].
///
/// The date card is rendered by [BabaCosmicContent] ABOVE the strip, so it's
/// common to both views. State lives here so it survives stream-driven rebuilds.
class CircleDashboardSwitcher extends StatefulWidget {
  const CircleDashboardSwitcher({
    super.key,
    required this.selfName,
    this.selfPhoto,
    required this.contentBuilder,
  });

  final String selfName;
  final String? selfPhoto;
  final CircleContentBuilder contentBuilder;

  @override
  State<CircleDashboardSwitcher> createState() =>
      _CircleDashboardSwitcherState();
}

class _CircleDashboardSwitcherState extends State<CircleDashboardSwitcher> {
  CircleVibe? _selected;

  @override
  Widget build(BuildContext context) {
    final strip = CircleVibeStrip(
      selectedUid: _selected?.uid,
      selfName: widget.selfName,
      selfPhoto: widget.selfPhoto,
      onSelect: (vibe) => setState(() => _selected = vibe),
    );

    return widget.contentBuilder(
      context,
      stripSlot: strip,
      bodyOverride: _selected == null ? null : FriendCosmicView(vibe: _selected!),
    );
  }
}
