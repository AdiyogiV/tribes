import 'package:flutter/material.dart';
import 'package:aurogram/features/astrology/domain/circle_vibes_service.dart';
import 'package:aurogram/features/astrology/presentation/widgets/circle_vibe_strip.dart';
import 'package:aurogram/features/astrology/presentation/widgets/friend_day_view.dart';
import 'package:aurogram/features/baba/domain/baba_context.dart';

/// Builds the dashboard content given the selector [stripSlot] and an optional
/// [bodyOverride] (the friend view). The parent (dashboard) wires these into
/// [AstroDashboardContent] so the common date card stays on top for everyone, the
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
/// The date card is rendered by [AstroDashboardContent] ABOVE the strip, so it's
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

  /// Make Aurobhatt ambiently aware of who the user is looking at + the bond,
  /// so an unqualified "what do you think?" is answered from the live screen
  /// (silent awareness — no proactive narration).
  void _publishSelectionToBaba(CircleVibe? vibe) {
    if (vibe == null) {
      BabaContext.instance.clearDetail();
      return;
    }
    final t = vibe.together;
    final buf = StringBuffer('Viewing ${vibe.name} in the circle. ');
    buf.write("Their vibe today: ${vibe.vibe}. ");
    if (t != null) {
      buf.write('Together today: ${t.label} ${t.score}%.');
      if (t.connection.isNotEmpty) {
        buf.write(' ${t.connection.first.phrase(vibe.name)}.');
      }
    }
    BabaContext.instance.publish(buf.toString(), speak: false);
  }

  @override
  void dispose() {
    // Don't leave a stale friend line on Aurobhatt's screen awareness.
    BabaContext.instance.clearDetail();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strip = CircleVibeStrip(
      selectedUid: _selected?.uid,
      selfName: widget.selfName,
      selfPhoto: widget.selfPhoto,
      onSelect: (vibe) {
        setState(() => _selected = vibe);
        _publishSelectionToBaba(vibe);
      },
    );

    return widget.contentBuilder(
      context,
      stripSlot: strip,
      bodyOverride: _selected == null ? null : FriendCosmicView(vibe: _selected!),
    );
  }
}
