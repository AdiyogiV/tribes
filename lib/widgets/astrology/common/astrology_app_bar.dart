import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:aurogram/utils/theme/app_theme.dart';

/// Shared app bar component for astrology pages
/// Provides consistent styling with optional gradient background
class AstrologyAppBar extends StatelessWidget {
  final String title;
  final VoidCallback? onBack;
  final List<Widget>? actions;
  final bool showGradient;
  final Color? customColor;

  const AstrologyAppBar({
    super.key,
    required this.title,
    this.onBack,
    this.actions,
    this.showGradient = false,
    this.customColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = customColor ?? AppTheme.astroBrown(isDark);

    Widget content = SafeArea(
      bottom: false,
      child: Container(
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              color: accentColor,
              onPressed: onBack ?? () => Navigator.of(context).pop(),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Center(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: accentColor,
                  ),
                ),
              ),
            ),
            if (actions != null && actions!.isNotEmpty)
              Row(children: actions!)
            else
              const SizedBox(width: 40), // Balance for centered title
          ],
        ),
      ),
    );

    if (showGradient) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              accentColor.withOpacity(0.15),
              accentColor.withOpacity(0.08),
              accentColor.withOpacity(0.04),
              Colors.transparent,
            ],
            stops: const [0.0, 0.3, 0.6, 1.0],
          ),
        ),
        child: content,
      );
    }

    return content;
  }
}

/// Sliver version of AstrologyAppBar for use in CustomScrollView
class SliverAstrologyAppBar extends StatelessWidget {
  final String title;
  final bool floating;
  final bool snap;
  final bool pinned;
  final Color? customColor;

  const SliverAstrologyAppBar({
    super.key,
    required this.title,
    this.floating = true,
    this.snap = true,
    this.pinned = false,
    this.customColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = customColor ?? AppTheme.primaryColor;

    return SliverAppBar(
      floating: floating,
      snap: snap,
      pinned: pinned,
      expandedHeight: 70,
      toolbarHeight: 60,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      backgroundColor: Colors.transparent,
      shadowColor: Colors.transparent,
      titleSpacing: 0,
      automaticallyImplyLeading: false,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      ),
      title: _buildHeaderContent(context, accentColor),
    );
  }

  Widget _buildHeaderContent(BuildContext context, Color accentColor) {
    const double sideWidth = 82.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: sideWidth,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                color: accentColor,
                onPressed: () => Navigator.of(context).pop(),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                iconSize: 20,
              ),
            ),
          ),
        ),
        Expanded(
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                color: accentColor,
              ),
            ),
          ),
        ),
        const SizedBox(width: sideWidth),
      ],
    );
  }
}




