import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/shared/presentation/widgets/universal/transparent_toolbox.dart';

/// Reusable card/tile builders for the settings page.
class SettingsTiles {
  SettingsTiles._();

  /// Get responsive card padding
  static EdgeInsets getCardPadding(bool isDesktop) => EdgeInsets.symmetric(
        horizontal: isDesktop ? 20 : 16,
        vertical: isDesktop ? 16 : 14,
      );

  /// Get responsive card margin
  static EdgeInsets getCardMargin(bool isDesktop) => EdgeInsets.symmetric(
        horizontal: isDesktop ? 20 : 16,
      );

  /// Build a toggle card with hover effect for web
  static Widget buildToggleCard({
    required BuildContext context,
    required bool isDesktop,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final primaryColor = AppTheme.primaryColor;

    return HoverableCard(
      isDesktop: isDesktop,
      child: TransparentToolbox.buildCard(
        context: context,
        padding: getCardPadding(isDesktop),
        margin: getCardMargin(isDesktop),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(isDesktop ? 12 : 10),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(isDesktop ? 14 : 12),
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: isDesktop ? 24 : 22,
              ),
            ),
            SizedBox(width: isDesktop ? 16 : 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: isDesktop ? 16 : 15,
                      fontWeight: FontWeight.w600,
                      color: primaryColor,
                    ),
                  ),
                  SizedBox(height: isDesktop ? 4 : 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: isDesktop ? 13 : 12,
                      color: primaryColor.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: CupertinoSwitch(
                value: value,
                activeTrackColor: primaryColor,
                onChanged: onChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build a tappable settings tile with chevron
  static Widget buildSettingsTile({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required bool isDesktop,
    bool isDestructive = false,
  }) {
    final primaryColor = AppTheme.primaryColor;

    return HoverableCard(
      isDesktop: isDesktop,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: TransparentToolbox.buildCard(
          context: context,
          padding: getCardPadding(isDesktop),
          margin: getCardMargin(isDesktop),
          onTap: () {
            if (!kIsWeb) HapticFeedback.lightImpact();
            onTap();
          },
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(isDesktop ? 12 : 10),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(isDesktop ? 14 : 12),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: isDesktop ? 24 : 22,
                ),
              ),
              SizedBox(width: isDesktop ? 16 : 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: isDesktop ? 16 : 15,
                        fontWeight: FontWeight.w600,
                        color:
                            isDestructive ? AppTheme.errorColor : primaryColor,
                      ),
                    ),
                    SizedBox(height: isDesktop ? 4 : 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: isDesktop ? 13 : 12,
                        color: primaryColor.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: primaryColor.withValues(alpha: 0.4),
                size: isDesktop ? 22 : 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A wrapper widget that adds hover effect for web.
/// On mobile, it's a no-op wrapper.
class HoverableCard extends StatefulWidget {
  final Widget child;
  final bool isDesktop;

  const HoverableCard({
    super.key,
    required this.child,
    required this.isDesktop,
  });

  @override
  State<HoverableCard> createState() => _HoverableCardState();
}

class _HoverableCardState extends State<HoverableCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    // Only apply hover effect on web/desktop
    if (!kIsWeb || !widget.isDesktop) {
      return widget.child;
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        transform: Matrix4.identity()..scale(_isHovered ? 1.01 : 1.0),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: _isHovered ? 0.9 : 1.0,
          child: widget.child,
        ),
      ),
    );
  }
}
