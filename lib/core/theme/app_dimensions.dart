/// Centralized dimensions, spacing, and sizing constants.
///
/// USAGE: Replace hardcoded numeric values in widgets with these constants.
/// Before: `EdgeInsets.all(16)` → After: `EdgeInsets.all(AppDimensions.paddingMd)`
/// Before: `SizedBox(height: 8)` → After: `SizedBox(height: AppDimensions.spacingSm)`
/// Before: `BorderRadius.circular(12)` → After: `BorderRadius.circular(AppDimensions.radiusMd)`
///
/// WHY: 500+ magic numbers across the codebase make visual consistency
/// impossible and theme changes painful. Centralizing them here means
/// one change updates the entire app.
class AppDimensions {
  AppDimensions._();

  // ============================================
  // SPACING — gaps between elements (SizedBox, Padding)
  // ============================================

  /// 2.0 — Hairline gap (between icon and label inline)
  static const double spacingXxs = 2;

  /// 3.0 — Hairline-plus gap
  static const double spacingXxxs = 3;

  /// 4.0 — Tight gap (between closely related elements)
  static const double spacingXs = 4;

  /// 6.0 — Small-medium gap (between label and value)
  static const double spacingSmMd = 6;

  /// 8.0 — Small gap (list item internal padding)
  static const double spacingSm = 8;

  /// 10.0 — Medium gap (compact list items)
  static const double spacingMdSm = 10;

  /// 12.0 — Medium-small gap (card internal sections)
  static const double spacingMd = 12;

  /// 14.0 — Medium-large gap
  static const double spacingMdLg = 14;

  /// 16.0 — Standard gap (between cards, section padding)
  static const double spacingLg = 16;

  /// 20.0 — Large gap (between major sections)
  static const double spacingXl = 20;

  /// 24.0 — Extra large gap (page top/bottom margins)
  static const double spacingXxl = 24;

  /// 32.0 — Section divider (between unrelated content blocks)
  static const double spacingSection = 32;

  /// 40.0 — Large section gap
  static const double spacingLargeSection = 40;

  /// 48.0 — Major separator (between page sections)
  static const double spacingPage = 48;

  /// 60.0 — Extra large section
  static const double spacingHero = 60;

  // ============================================
  // PADDING — container internal padding
  // ============================================

  /// 4.0
  static const double paddingXs = 4;

  /// 8.0
  static const double paddingSm = 8;

  /// 12.0
  static const double paddingMd = 12;

  /// 14.0
  static const double paddingMdLg = 14;

  /// 16.0 — Most common padding for cards and containers
  static const double paddingLg = 16;

  /// 20.0
  static const double paddingXl = 20;

  /// 24.0
  static const double paddingXxl = 24;

  // ============================================
  // BORDER RADIUS
  // ============================================

  /// 4.0 — Subtle rounding (chips, tags)
  static const double radiusXs = 4;

  /// 6.0 — Small-medium rounding
  static const double radiusSmMd = 6;

  /// 8.0 — Small rounding (input fields, small cards)
  static const double radiusSm = 8;

  /// 10.0 — Medium rounding (buttons, inputs)
  static const double radiusMdSm = 10;

  /// 12.0 — Medium rounding (cards, dialogs)
  static const double radiusMd = 12;

  /// 14.0 — Medium-large rounding
  static const double radiusMdLg = 14;

  /// 16.0 — Large rounding (bottom sheets, modals)
  static const double radiusLg = 16;

  /// 20.0 — Extra large rounding (floating cards)
  static const double radiusXl = 20;

  /// 24.0 — Pill-like rounding (buttons, badges)
  static const double radiusXxl = 24;

  /// 999.0 — Full circle (avatars, FABs)
  static const double radiusFull = 999;

  // ============================================
  // ICON SIZES
  // ============================================

  /// 16.0 — Tiny icon (inline with small text)
  static const double iconXs = 16;

  /// 20.0 — Small icon (list item leading)
  static const double iconSm = 20;

  /// 24.0 — Standard icon (toolbar, navigation)
  static const double iconMd = 24;

  /// 28.0 — Medium-large icon
  static const double iconLg = 28;

  /// 32.0 — Large icon (empty state, feature icons)
  static const double iconXl = 32;

  /// 48.0 — Extra large icon (hero, onboarding)
  static const double iconXxl = 48;

  // ============================================
  // AVATAR SIZES
  // ============================================

  /// 24.0 — Tiny avatar (inline mentions)
  static const double avatarXs = 24;

  /// 32.0 — Small avatar (comment replies)
  static const double avatarSm = 32;

  /// 40.0 — Standard avatar (list items, chat)
  static const double avatarMd = 40;

  /// 48.0 — Medium-large avatar (post headers)
  static const double avatarLg = 48;

  /// 56.0 — Large avatar (profile cards)
  static const double avatarXl = 56;

  /// 80.0 — Extra large avatar (profile page header)
  static const double avatarXxl = 80;

  /// 120.0 — Hero avatar (profile edit, onboarding)
  static const double avatarHero = 120;

  // ============================================
  // COMPONENT HEIGHTS
  // ============================================

  /// 36.0 — Compact button
  static const double buttonHeightSm = 36;

  /// 44.0 — Standard button / input field
  static const double buttonHeightMd = 44;

  /// 52.0 — Large button (primary CTA)
  static const double buttonHeightLg = 52;

  /// 48.0 — Standard app bar / toolbar height
  static const double toolbarHeight = 48;

  /// 56.0 — Bottom nav bar height
  static const double bottomNavHeight = 56;

  // ============================================
  // ELEVATION
  // ============================================

  /// 0.0 — Flat (no shadow)
  static const double elevationNone = 0;

  /// 1.0 — Subtle lift (cards at rest)
  static const double elevationSm = 1;

  /// 2.0 — Standard card elevation
  static const double elevationMd = 2;

  /// 4.0 — Raised element (floating buttons)
  static const double elevationLg = 4;

  /// 8.0 — High elevation (dialogs, modals)
  static const double elevationXl = 8;

  // ============================================
  // LAYOUT CONSTRAINTS
  // ============================================

  /// 600.0 — Max width for content on tablets/web
  static const double maxContentWidth = 600;

  /// 400.0 — Max width for dialogs
  static const double maxDialogWidth = 400;

  /// 300.0 — Min width for cards in grid layouts
  static const double minCardWidth = 300;
}

/// Font size constants — complements [AppTheme.babaTextSize]
/// for pages other than Baba.
///
/// USAGE:
/// Before: `TextStyle(fontSize: 12)` → After: `TextStyle(fontSize: AppFontSizes.sm)`
class AppFontSizes {
  AppFontSizes._();

  /// 10.0 — Caption, timestamp, badge count
  static const double xs = 10;

  /// 11.0 — Small caption, helper text
  static const double sm = 11;

  /// 12.0 — Secondary text, subtitles
  static const double md = 12;

  /// 13.0 — Body small
  static const double body = 13;

  /// 14.0 — Body standard (most readable text)
  static const double bodyLg = 14;

  /// 15.0 — Body large (matches babaTextSize)
  static const double bodyXl = 15;

  /// 16.0 — Subtitle, section header
  static const double subtitle = 16;

  /// 18.0 — Title, card header
  static const double title = 18;

  /// 20.0 — Large title
  static const double titleLg = 20;

  /// 22.0 — Page title
  static const double headline = 22;

  /// 24.0 — Hero text
  static const double headlineLg = 24;

  /// 28.0 — Display small
  static const double display = 28;

  /// 32.0 — Display large
  static const double displayLg = 32;

  /// 48.0 — Jumbo (onboarding hero, empty states)
  static const double jumbo = 48;
}

/// Animation duration constants.
class AppDurations {
  AppDurations._();

  /// 100ms — Micro interaction (opacity, color change)
  static const Duration fast = Duration(milliseconds: 100);

  /// 200ms — Standard transition (fade, slide)
  static const Duration normal = Duration(milliseconds: 200);

  /// 300ms — Medium transition (expand, collapse)
  static const Duration medium = Duration(milliseconds: 300);

  /// 500ms — Slow transition (page, dialog)
  static const Duration slow = Duration(milliseconds: 500);

  /// 800ms — Very slow (onboarding animations)
  static const Duration slower = Duration(milliseconds: 800);
}
