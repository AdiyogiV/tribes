import 'package:aurogram/core/theme/app_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

class AyurvedaDetailsHeader extends StatelessWidget {
  final VoidCallback onBack;
  final bool showMenu;
  final VoidCallback onReset;

  const AyurvedaDetailsHeader({
    super.key,
    required this.onBack,
    required this.showMenu,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Container(
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingLg),
        child: Row(
          children: [
            SizedBox(
              width: 40,
              child: IconButton(
                icon: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 20,
                  color: AppTheme.primaryColor,
                ),
                onPressed: onBack,
                padding: EdgeInsets.zero,
              ),
            ),
            Expanded(
              child: Center(
                child: Text(
                  'ayurveda',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.primaryColor,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
            // Menu button (only if profile exists)
            SizedBox(
              width: 40,
              child: showMenu
                  ? PopupMenuButton<String>(
                      icon: Icon(
                        CupertinoIcons.ellipsis_circle,
                        size: 24,
                        color: AppTheme.primaryColor,
                      ),
                      padding: EdgeInsets.zero,
                      onSelected: (value) {
                        switch (value) {
                          case 'reset':
                            onReset();
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'reset',
                          child: Row(
                            children: [
                              Icon(
                                CupertinoIcons.refresh,
                                size: 20,
                                color: Colors.red,
                              ),
                              const SizedBox(width: AppDimensions.spacingMd),
                              const Text(
                                'Reset & Recalculate',
                                style: TextStyle(color: Colors.red),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
