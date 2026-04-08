import 'package:flutter/material.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

/// A consistent loading indicator used across the app.
///
/// Provides a centered [CircularProgressIndicator] with optional size and color.
/// Use instead of raw `CircularProgressIndicator()` for consistent appearance.
class AppLoadingIndicator extends StatelessWidget {
  final double size;
  final Color? color;
  final double strokeWidth;

  const AppLoadingIndicator({
    super.key,
    this.size = 24,
    this.color,
    this.strokeWidth = 2.5,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: size,
        height: size,
        child: CircularProgressIndicator(
          strokeWidth: strokeWidth,
          valueColor: AlwaysStoppedAnimation<Color>(
            color ?? AppTheme.primaryColor,
          ),
        ),
      ),
    );
  }
}

/// A generic empty state widget for "No results" / "Nothing here" patterns.
///
/// Use when a list or grid has no data to show. Provides a consistent
/// visual treatment with icon, title, and optional subtitle.
class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;
  final double iconSize;

  /// Optional override for the icon color (defaults to muted theme color).
  final Color? iconColor;

  /// Optional padding override (defaults to symmetric h:32, v:24).
  final EdgeInsetsGeometry? padding;

  const EmptyStateWidget({
    super.key,
    this.icon = Icons.inbox_outlined,
    this.title = 'Nothing here yet',
    this.subtitle,
    this.action,
    this.iconSize = 48,
    this.iconColor,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedColor = isDark ? Colors.white38 : Colors.black38;

    return Center(
      child: Padding(
        padding:
            padding ?? const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: iconSize, color: iconColor ?? mutedColor),
            const SizedBox(height: AppDimensions.spacingMd),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: AppDimensions.spacingSmMd),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: mutedColor,
                ),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: AppDimensions.spacingLg),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Styled section header used in settings, profile, and detail pages.
///
/// Renders title in uppercase with primary color accent and consistent spacing.
class SectionHeader extends StatelessWidget {
  final String title;
  final bool isDesktop;
  final EdgeInsetsGeometry? padding;

  const SectionHeader({
    super.key,
    required this.title,
    this.isDesktop = false,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ??
          EdgeInsets.fromLTRB(
            isDesktop ? 24 : 20,
            isDesktop ? 12 : 8,
            isDesktop ? 24 : 20,
            isDesktop ? 8 : 4,
          ),
      child: Center(
        child: Text(
          title.toUpperCase(),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: isDesktop ? 12 : 11,
            fontWeight: FontWeight.w600,
            color: AppTheme.primaryColor,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}

/// Standard bottom sheet wrapper with rounded top corners and theme-aware colors.
///
/// Use instead of raw `showModalBottomSheet` for consistent appearance.
/// ```dart
/// AppBottomSheet.show(context, child: MyContent());
/// ```
class AppBottomSheet extends StatelessWidget {
  final Widget child;
  final double maxHeightFraction;

  const AppBottomSheet({
    super.key,
    required this.child,
    this.maxHeightFraction = 0.9,
  });

  /// Show this bottom sheet modally.
  static Future<T?> show<T>(
    BuildContext context, {
    required Widget child,
    double maxHeightFraction = 0.9,
    bool isDismissible = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      isDismissible: isDismissible,
      builder: (ctx) => AppBottomSheet(
        maxHeightFraction: maxHeightFraction,
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * maxHeightFraction,
      ),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Flexible(child: child),
          ],
        ),
      ),
    );
  }
}

/// A reusable user row showing avatar, name, and optional subtitle.
///
/// Common pattern across chat lists, search results, and member lists.
class UserRow extends StatelessWidget {
  final String? avatarUrl;
  final String name;
  final String? subtitle;
  final double avatarSize;
  final VoidCallback? onTap;
  final Widget? trailing;

  const UserRow({
    super.key,
    this.avatarUrl,
    required this.name,
    this.subtitle,
    this.avatarSize = 40,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingLg, vertical: AppDimensions.paddingSm),
        child: Row(
          children: [
            CircleAvatar(
              radius: avatarSize / 2,
              backgroundImage:
                  avatarUrl != null ? NetworkImage(avatarUrl!) : null,
              backgroundColor: isDark ? Colors.white12 : Colors.grey[200],
              child: avatarUrl == null
                  ? Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: TextStyle(
                        fontSize: avatarSize * 0.4,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: AppDimensions.spacingMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}
