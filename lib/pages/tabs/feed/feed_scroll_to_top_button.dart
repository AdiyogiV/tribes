import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:aurogram/utils/theme/app_theme.dart';

/// Scroll-to-top floating button with blur effect.
class FeedScrollToTopButton extends StatelessWidget {
  final bool isDark;
  final ValueNotifier<bool> showNotifier;
  final VoidCallback onTap;

  const FeedScrollToTopButton({
    super.key,
    required this.isDark,
    required this.showNotifier,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color barBase = isDark ? AppTheme.cardDarkColor : Colors.white;
    return ValueListenableBuilder<bool>(
      valueListenable: showNotifier,
      builder: (context, show, _) {
        return AnimatedSlide(
          duration: const Duration(milliseconds: 300),
          offset: show ? Offset.zero : const Offset(0, 2),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: show ? 1.0 : 0.0,
            child: IgnorePointer(
              ignoring: !show,
              child: GestureDetector(
                onTap: onTap,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: onTap,
                        borderRadius: BorderRadius.circular(18),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
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
                          child: Icon(
                            CupertinoIcons.chevron_up,
                            color: theme.colorScheme.primary,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
