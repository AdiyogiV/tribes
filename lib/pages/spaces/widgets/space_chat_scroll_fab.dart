import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/utils/theme/app_dimensions.dart';

/// Floating action button that scrolls the chat to the newest messages.
///
/// Extracted from space_chat_screen.dart to reduce file size.
class SpaceChatScrollFAB extends StatelessWidget {
  final ScrollController scrollController;

  const SpaceChatScrollFAB({super.key, required this.scrollController});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final Color barBase = isDark ? AppTheme.cardDarkColor : Colors.white;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppDimensions.radiusXxl),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              if (!kIsWeb) HapticFeedback.lightImpact();
              scrollController.animateTo(0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut);
            },
            borderRadius: BorderRadius.circular(AppDimensions.radiusXxl),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppDimensions.radiusXxl),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [
                          barBase.withValues(alpha: 0.75),
                          barBase.withValues(alpha: 0.70),
                        ]
                      : [
                          barBase.withValues(alpha: 0.90),
                          barBase.withValues(alpha: 0.85),
                        ],
                ),
                border: isDark
                    ? Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                        width: 1.0,
                      )
                    : null,
              ),
              child: Icon(Icons.keyboard_arrow_down_rounded,
                  color: theme.colorScheme.primary, size: 28),
            ),
          ),
        ),
      ),
    );
  }
}
