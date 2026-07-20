import 'package:flutter/material.dart';
import 'package:aurogram/core/theme/app_colors.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// Aurogram Web Design System — shared tokens for the premium desktop UI.
///
/// This is the single source of truth for the web/wide redesign: glass fills,
/// borders, blur, gutters, tile radii and the accent color. Every web surface
/// (rail, tiles, Aurobhatt orb, overlays) pulls from here so the language stays
/// consistent and DRY. NONE of this touches the mobile layout — it is only
/// consumed by widgets rendered on the wide/web path.
///
/// Both dark-cosmic and light-airy are first-class: every getter takes
/// [isDark] and returns a value tuned for that canvas.
/// ─────────────────────────────────────────────────────────────────────────
class WebStyle {
  WebStyle._();

  // ── Layout rhythm ──────────────────────────────────────────────────────
  /// Outer page padding around the whole dashboard canvas.
  static const double pagePadding = 40;

  /// Gap between bento tiles (both axes).
  static const double gutter = 28;

  /// Standard tile corner radius — large & soft.
  static const double tileRadius = 24;

  /// Inner padding inside a glass tile.
  static const double tilePadding = 24;

  /// Collapsed width of the floating nav rail.
  static const double railWidth = 84;

  /// Expanded (hover) width of the nav rail overlay.
  static const double railExpandedWidth = 256;

  /// Backdrop blur sigma for frosted glass.
  static const double blurSigma = 22;

  // ── Accent ─────────────────────────────────────────────────────────────
  /// The warm signature accent. Gold in dark (reads on near-black), deep
  /// brown in light. Independent of AppColors.primaryColor (which is pure
  /// white in dark mode and too flat for accents).
  static Color accent(bool isDark) =>
      isDark ? AppColors.sunGold : AppColors.primaryBrandColor;

  /// A softer secondary accent for glows and gradients.
  static Color accentSoft(bool isDark) =>
      isDark ? AppColors.honeyAmber : AppColors.primaryLightColor;

  // ── Glass surfaces ─────────────────────────────────────────────────────
  /// Translucent fill for a glass tile.
  static Color glassFill(bool isDark) => isDark
      ? Colors.white.withValues(alpha: 0.045)
      : Colors.white.withValues(alpha: 0.58);

  /// Slightly stronger fill for raised / hovered glass.
  static Color glassFillRaised(bool isDark) => isDark
      ? Colors.white.withValues(alpha: 0.075)
      : Colors.white.withValues(alpha: 0.72);

  /// Hairline border that gives glass its crisp edge.
  static Color glassBorder(bool isDark) => isDark
      ? Colors.white.withValues(alpha: 0.09)
      : Colors.white.withValues(alpha: 0.75);

  /// Border on hover — a touch of accent warmth.
  static Color glassBorderHover(bool isDark) =>
      accent(isDark).withValues(alpha: isDark ? 0.35 : 0.30);

  /// Soft ambient shadow beneath a tile.
  static List<BoxShadow> tileShadow(bool isDark) => [
        BoxShadow(
          color: isDark
              ? Colors.black.withValues(alpha: 0.35)
              : AppColors.primaryBrandColor.withValues(alpha: 0.08),
          blurRadius: 32,
          spreadRadius: -8,
          offset: const Offset(0, 14),
        ),
      ];

  /// Stronger shadow when a tile lifts on hover.
  static List<BoxShadow> tileShadowHover(bool isDark) => [
        BoxShadow(
          color: isDark
              ? Colors.black.withValues(alpha: 0.50)
              : AppColors.primaryBrandColor.withValues(alpha: 0.14),
          blurRadius: 44,
          spreadRadius: -6,
          offset: const Offset(0, 20),
        ),
      ];

  // ── Text ───────────────────────────────────────────────────────────────
  /// Primary text on glass.
  static Color textPrimary(bool isDark) =>
      isDark ? AppColors.textDarkColor : AppColors.textLightColor;

  /// Muted secondary text on glass.
  static Color textSecondary(bool isDark) =>
      isDark ? AppColors.textSecondaryDarkColor : AppColors.textSecondaryLightColor;

  // ── Motion ─────────────────────────────────────────────────────────────
  /// Slow, expensive easing used app-wide on the web surfaces.
  static const Curve ease = Curves.easeOutCubic;
  static const Duration hover = Duration(milliseconds: 180);
  static const Duration expand = Duration(milliseconds: 260);
}
