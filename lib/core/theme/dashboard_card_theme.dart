import 'package:flutter/material.dart';
import 'package:aurogram/core/theme/app_theme.dart';

/// Width (of the card itself) at/above which a dashboard card switches to its
/// wide, two-column editorial layout. Single source of truth — every dashboard
/// card and the layout that hosts them should reference this instead of a bare
/// `820` literal sprinkled through the tree.
const double kDashboardDesktopBreak = 820.0;

/// Corner radius for the floating dashboard cards.
const double kDashboardCardRadius = 28.0;

/// Generous, consistent inner padding for the dashboard cards.
const EdgeInsets kDashboardCardPadding =
    EdgeInsets.symmetric(horizontal: 28, vertical: 30);

/// Shared max bounding size (square) for each card's hero visual — the
/// nakshatra wheel, the dosha orb, and the sky chart. Keeping one cap makes
/// all three visuals read as the same size instead of the wheel dwarfing the
/// orb. Each visual sizes to `min(availableWidth, kDashboardVisualSize)`.
const double kDashboardVisualSize = 300.0;

/// The shared palette for the three home-dashboard cards (Energy, Balance,
/// Current Sky). These cards all share one look: a stark surface (night-black
/// in dark, clean white in light) with a small ramp of foreground tones.
///
/// Extracted so the exact same `isDark ? ... : ...` block isn't hand-copied
/// into every card (it was, three times) — one place to tune, one place to
/// keep contrast honest.
///
/// Contrast (WCAG 2.2 AA needs 4.5:1 for body text):
///   • [fgMain]  — ~white / near-black: passes comfortably.
///   • [fgMuted] — white54 / black54 (~5:1 on the card surface): passes for
///     labels & secondary text. **Do not** further reduce its alpha for text.
///   • [fgFaint] — decorative only (hairlines, ghost serifs). NOT for text.
@immutable
class DashboardCardPalette {
  final Color surface;
  final Color fgMain;
  final Color fgMuted;
  final Color fgFaint;

  const DashboardCardPalette({
    required this.surface,
    required this.fgMain,
    required this.fgMuted,
    required this.fgFaint,
  });

  factory DashboardCardPalette.of(BuildContext context) =>
      DashboardCardPalette.forBrightness(
          Theme.of(context).brightness == Brightness.dark);

  factory DashboardCardPalette.forBrightness(bool isDark) {
    return DashboardCardPalette(
      surface: isDark ? const Color(0xFF000000) : Colors.white,
      fgMain: isDark ? Colors.white : const Color(0xFF1A1A1C),
      fgMuted: isDark ? Colors.white54 : Colors.black54,
      fgFaint: isDark ? Colors.white24 : Colors.black26,
    );
  }

  /// The accent (gold/brown) used for the leading word of editorial titles.
  Color get accent => AppTheme.primaryColor;
}

/// The shared "chrome" for the three home-dashboard cards: a floating panel
/// with soft rounded corners, a hairline edge, a gentle shadow, and generous
/// interior padding. Centralising it means all three cards read as one elegant
/// set instead of flat full-bleed bands, and there's a single place to tune the
/// premium look.
class DashboardCard extends StatelessWidget {
  const DashboardCard({
    super.key,
    required this.child,
    this.padding = kDashboardCardPadding,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = DashboardCardPalette.forBrightness(isDark);

    return Container(
      width: double.infinity,
      padding: padding,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(kDashboardCardRadius),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.45)
                : Colors.black.withValues(alpha: 0.07),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// The editorial two-tone title shared by every dashboard card, e.g.
/// *"Current Sky."* or *"Vata elevated."* — accent leading word, muted-weight
/// trailing word, with an optional italic subtitle beneath.
///
/// Announced to screen readers as a single header node (fixes the a11y gap
/// where these titles were plain [Text]/[RichText] with no [Semantics]).
class EditorialCardHeader extends StatelessWidget {
  const EditorialCardHeader({
    super.key,
    required this.leading,
    required this.trailing,
    required this.palette,
    this.leadingColor,
    this.subtitle,
    this.titleSize = 32,
    this.subtitleSize = 14,
  });

  /// Accent-coloured leading segment (e.g. "Current ", "Vata").
  final String leading;

  /// Main-coloured, light-weight trailing segment (e.g. "Sky.", " elevated.").
  final String trailing;

  final DashboardCardPalette palette;

  /// Overrides the leading colour (defaults to [DashboardCardPalette.accent]).
  final Color? leadingColor;

  /// Optional italic subtitle rendered beneath the title.
  final String? subtitle;

  final double titleSize;
  final double subtitleSize;

  @override
  Widget build(BuildContext context) {
    final hasSubtitle = subtitle != null && subtitle!.trim().isNotEmpty;
    return Semantics(
      header: true,
      label: '$leading$trailing'.trim(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: leading,
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontStyle: FontStyle.italic,
                    color: leadingColor ?? palette.accent,
                    fontSize: titleSize,
                    letterSpacing: -1.2,
                  ),
                ),
                TextSpan(
                  text: trailing,
                  style: TextStyle(
                    fontFamily: 'Georgia',
                    fontStyle: FontStyle.italic,
                    color: palette.fgMain,
                    fontSize: titleSize,
                    fontWeight: FontWeight.w300,
                    letterSpacing: -1.2,
                  ),
                ),
              ],
            ),
          ),
          if (hasSubtitle) ...[
            const SizedBox(height: 8),
            Text(
              subtitle!,
              style: TextStyle(
                color: palette.fgMuted,
                fontSize: subtitleSize,
                height: 1.4,
                fontFamily: 'Georgia',
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
