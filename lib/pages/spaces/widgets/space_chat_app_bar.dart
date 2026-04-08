import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/utils/responsive.dart';

/// Frosted-glass app bar used by [SpaceChatScreen].
///
/// Extracted from space_chat_screen.dart to reduce file size.
class SpaceChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget headerContent;

  const SpaceChatAppBar({super.key, required this.headerContent});

  @override
  Size get preferredSize => const Size.fromHeight(54);

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color headerBase = isDark ? AppTheme.cardDarkColor : Colors.white;
    final bool isDesktop = Responsive.isDesktop(context);

    return PreferredSize(
      preferredSize: preferredSize,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isDesktop ? 700 : double.infinity,
          ),
          child: Material(
            color: Colors.transparent,
            elevation: 0,
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        headerBase.withValues(alpha: isDark ? 0.85 : 0.90),
                        headerBase.withValues(alpha: isDark ? 0.80 : 0.85),
                      ],
                    ),
                    border: Border(
                      bottom: BorderSide(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.10)
                            : headerBase.withValues(alpha: 0.32),
                        width: 0.5,
                      ),
                    ),
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: SizedBox(height: 54, child: headerContent),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
