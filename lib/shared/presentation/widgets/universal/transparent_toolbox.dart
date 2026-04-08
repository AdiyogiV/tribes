import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:ui';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/core/theme/header_style.dart';
import 'package:aurogram/shared/presentation/widgets/loaders/skeleton_widgets.dart';
import 'package:aurogram/shared/presentation/widgets/universal/toolbox/search_content.dart';
import 'package:aurogram/shared/presentation/widgets/universal/toolbox/chat_content.dart';
import 'package:aurogram/shared/presentation/widgets/universal/toolbox/astro_chat_content.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

// Re-export sub-widgets so existing imports continue to work
export 'package:aurogram/shared/presentation/widgets/universal/toolbox/toolbox_exports.dart';

/// Universal transparent toolbox with glass blur effect.
/// Matches the tab bar styling for consistency across the app.
///
/// Use this widget for all bottom toolbar/input needs:
/// - TransparentToolbox.search() for search fields
/// - TransparentToolbox.chat() for chat input
/// - TransparentToolbox.astroChat() for astrology chat with cow icon
/// - TransparentToolbox.actions() for action buttons
/// - TransparentToolbox.button() for action buttons like Save/Continue
/// - TransparentToolbox.input() for text input fields like name/phone entry
/// - TransparentToolbox.simple() for simple text/icon content
/// - TransparentToolbox(content: ...) for fully custom content
///
/// For cards that match this style, use TransparentToolbox.buildCard() helper.
class TransparentToolbox extends StatelessWidget {
  final Widget content;
  final EdgeInsets padding;
  final double height;

  const TransparentToolbox({
    super.key,
    required this.content,
    this.padding = const EdgeInsets.fromLTRB(16, 0, 16, 10),
    this.height = 70,
  });

  // ============================================
  // LAYOUT CONSTANTS
  // ============================================

  /// Standard horizontal padding inside toolbox
  static const double toolboxHorizontalPadding = 16.0;

  /// Standard card content padding
  static const EdgeInsets cardContentPadding =
      EdgeInsets.symmetric(horizontal: 20, vertical: 16);

  /// Standard border radius for all toolbox-style widgets (same as cards)
  static double get borderRadius => AppHeaderStyle.cardBorderRadius;

  /// Creates a search toolbox with search icon and text input
  static Widget search({
    required TextEditingController searchController,
    required FocusNode focusNode,
    required Function(String) onSearchChanged,
    String hintText = 'Search',
  }) {
    return TransparentToolbox(
      content: SearchContent(
        searchController: searchController,
        focusNode: focusNode,
        onSearchChanged: onSearchChanged,
        hintText: hintText,
      ),
    );
  }

  /// Creates a chat input toolbox with text field and send button
  /// Optionally includes a namaste button for DM conversations
  static Widget chat({
    required TextEditingController messageController,
    required FocusNode focusNode,
    required VoidCallback onSend,
    required Function(String) onChanged,
    String hintText = 'Type message',
    bool canSend = false,
    // Namaste button support for DM chats
    VoidCallback? onNamaste,
    bool showNamasteButton = false,
  }) {
    return TransparentToolbox(
      content: ChatContent(
        messageController: messageController,
        focusNode: focusNode,
        onSend: onSend,
        onChanged: onChanged,
        hintText: hintText,
        canSend: canSend,
        onNamaste: onNamaste,
        showNamasteButton: showNamasteButton,
      ),
    );
  }

  /// Creates an astrology-themed chat input with cow icon
  /// Supports optional voice input when [enableVoice] is true
  static Widget astroChat({
    required TextEditingController messageController,
    required FocusNode focusNode,
    required VoidCallback onSend,
    String hintText = 'Ask anything',
    bool enableVoice = false,
    VoidCallback? onMicPressed,
  }) {
    return TransparentToolbox(
      content: AstroChatContent(
        messageController: messageController,
        focusNode: focusNode,
        onSend: onSend,
        hintText: hintText,
        enableVoice: enableVoice,
        onMicPressed: onMicPressed,
      ),
    );
  }

  /// Creates a toolbox with custom action buttons
  static Widget actions({
    required List<Widget> actions,
    MainAxisAlignment alignment = MainAxisAlignment.spaceEvenly,
  }) {
    return TransparentToolbox(
      content: Row(
        mainAxisAlignment: alignment,
        children: actions,
      ),
    );
  }

  /// Creates a simple toolbox with text and optional trailing widget
  static Widget simple({
    String? text,
    Widget? leading,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return TransparentToolbox(
      content: GestureDetector(
        onTap: onTap,
        child: Row(
          children: [
            if (leading != null) ...[
              leading,
              const SizedBox(width: AppDimensions.spacingMd),
            ],
            if (text != null)
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    color: AppTheme.primaryColor.withValues(alpha: 0.85),
                    fontSize: AppTheme.holyCowTextSize,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            if (trailing != null) ...[
              const SizedBox(width: AppDimensions.spacingMd),
              trailing,
            ],
          ],
        ),
      ),
    );
  }

  /// Creates a button-style toolbox (for Save, Continue, Send, etc.)
  /// [leadingIcon] - optional icon to show before the text
  /// [leadingIconColor] - custom color for the leading icon
  static Widget button({
    required String text,
    required VoidCallback? onTap,
    IconData? icon,
    IconData? leadingIcon,
    Color? leadingIconColor,
    bool isLoading = false,
    bool enabled = true,
  }) {
    final isEnabled = enabled && !isLoading && onTap != null;

    return GestureDetector(
      onTap: isEnabled ? onTap : null,
      child: TransparentToolbox(
        content: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (leadingIcon != null) ...[
              Icon(
                leadingIcon,
                color: leadingIconColor ?? AppTheme.primaryColor,
                size: 20,
              ),
              const SizedBox(width: AppDimensions.spacingMd),
            ],
            Expanded(
              child: Text(
                isLoading ? '${text.replaceAll('...', '')}...' : text,
                style: TextStyle(
                  color: isEnabled
                      ? AppTheme.primaryColor.withValues(alpha: 0.85)
                      : AppTheme.primaryColor.withValues(alpha: 0.4),
                  fontSize: AppTheme.holyCowTextSize,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (isLoading)
              const InlineShimmerLoader(size: 20)
            else
              Icon(
                icon ?? CupertinoIcons.arrow_right,
                color: isEnabled
                    ? AppTheme.primaryColor
                    : AppTheme.primaryColor.withValues(alpha: 0.4),
                size: 22,
              ),
          ],
        ),
      ),
    );
  }

  /// Creates an input-style toolbox (for name entry, phone entry, etc.)
  static Widget input({
    required TextEditingController controller,
    required FocusNode focusNode,
    required IconData icon,
    String hintText = '',
    TextInputType keyboardType = TextInputType.text,
    TextInputAction textInputAction = TextInputAction.done,
    Function(String)? onChanged,
    VoidCallback? onSubmitted,
    int maxLines = 1,
  }) {
    return TransparentToolbox(
      content: Row(
        children: [
          Icon(
            icon,
            color: AppTheme.primaryColor.withValues(alpha: 0.85),
            size: 22,
          ),
          const SizedBox(width: AppDimensions.spacingMd),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              keyboardType: keyboardType,
              textInputAction: textInputAction,
              maxLines: maxLines,
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: hintTextStyle,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: inputContentPadding,
                isDense: true,
              ),
              style: inputTextStyle,
              onChanged: onChanged,
              onSubmitted: onSubmitted != null ? (_) => onSubmitted() : null,
            ),
          ),
        ],
      ),
    );
  }

  /// Builds a card widget matching TransparentToolbox style.
  /// Use this for profile cards, settings cards, etc.
  static Widget buildCard({
    required BuildContext context,
    required Widget child,
    EdgeInsets padding = cardContentPadding,
    EdgeInsets? margin,
    VoidCallback? onTap,
  }) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color barBase =
        isDark ? Theme.of(context).colorScheme.surface : Colors.white;

    Widget card = RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppHeaderStyle.cardBorderRadius),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: AppHeaderStyle.cardGradientColors(isDark, barBase),
          ),
          boxShadow: AppHeaderStyle.cardBoxShadow(isDark),
          border: AppHeaderStyle.cardBorder(isDark),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppHeaderStyle.cardBorderRadius),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius:
                  BorderRadius.circular(AppHeaderStyle.cardBorderRadius),
              child: Padding(
                padding: padding,
                child: child,
              ),
            ),
          ),
        ),
      ),
    );

    if (margin != null) {
      return Padding(padding: margin, child: card);
    }
    return card;
  }

  /// Consistent text style constants for all transparent toolbox inputs
  static TextStyle get inputTextStyle => TextStyle(
        color: AppTheme.primaryColor.withValues(alpha: 0.85),
        fontSize: AppTheme.holyCowTextSize,
        fontWeight: FontWeight.w500,
      );

  static TextStyle get hintTextStyle => TextStyle(
        color: AppTheme.primaryColor.withValues(alpha: 0.6),
        fontSize: AppTheme.holyCowTextSize,
        fontWeight: FontWeight.w500,
      );

  /// Consistent content padding for text fields
  static const EdgeInsets inputContentPadding =
      EdgeInsets.symmetric(horizontal: 4, vertical: 0);

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color barBase = isDark ? AppTheme.cardDarkColor : Colors.white;

    return SafeArea(
      child: Padding(
        padding: padding,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
            boxShadow: isDark
                // Dark mode: subtle glow effect for elevation
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.08),
                      blurRadius: 8,
                      spreadRadius: 1,
                      offset: const Offset(0, 0),
                    ),
                  ]
                // Light mode: subtle shadows
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
          ),
          child: Material(
            elevation: isDark ? 8 : 4,
            color: Colors.transparent,
            shadowColor: isDark
                ? Colors.black.withValues(alpha: 0.3)
                : Colors.black.withValues(alpha: 0.04),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
            ),
            clipBehavior: Clip.antiAlias,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
              child: Container(
                height: height,
                padding: const EdgeInsets.only(left: 16, right: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        // Dark mode: more transparent with border for definition
                        ? [
                            barBase.withValues(alpha: 0.75),
                            barBase.withValues(alpha: 0.70),
                          ]
                        : [
                            barBase.withValues(alpha: 0.90),
                            barBase.withValues(alpha: 0.85),
                          ],
                  ),
                  // Dark mode: subtle border for definition
                  border: isDark
                      ? Border.all(
                          color: Colors.white.withValues(alpha: 0.12),
                          width: 1.0,
                        )
                      : null,
                ),
                child: content,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
