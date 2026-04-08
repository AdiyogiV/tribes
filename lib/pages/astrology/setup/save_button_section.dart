import 'package:flutter/material.dart';
import 'package:aurogram/widgets/ui/skeleton_widgets.dart';
import 'package:aurogram/utils/theme/app_dimensions.dart';

/// Positioned save button for mobile layout.
class SetupSaveButton extends StatelessWidget {
  final Color primaryColor;
  final bool dark;
  final bool canSave;
  final bool saving;
  final bool hasExisting;
  final VoidCallback? onSave;

  const SetupSaveButton({
    super.key,
    required this.primaryColor,
    required this.dark,
    required this.canSave,
    required this.saving,
    required this.hasExisting,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor =
        dark ? Theme.of(context).colorScheme.surface : Colors.white;
    final c = primaryColor;

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          MediaQuery.of(context).padding.bottom + 16,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0),
              Theme.of(context).scaffoldBackgroundColor,
            ],
          ),
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          child: Material(
            color: cardColor,
            elevation: canSave ? 2 : 0,
            shadowColor: Colors.black.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
            child: InkWell(
              onTap: canSave && !saving ? onSave : null,
              borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: saving
                      ? PulsingDots(color: c, size: 6)
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              hasExisting
                                  ? Icons.save_rounded
                                  : Icons.auto_awesome_rounded,
                              size: 20,
                              color: canSave ? c : c.withValues(alpha: 0.4),
                            ),
                            const SizedBox(width: AppDimensions.spacingMdSm),
                            Text(
                              hasExisting
                                  ? 'Save Changes'
                                  : 'Calculate Birth Chart',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: canSave ? c : c.withValues(alpha: 0.4),
                              ),
                            ),
                          ],
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

/// Save button for wide layout (in flow, not positioned).
class SetupSaveButtonWide extends StatelessWidget {
  final Color primaryColor;
  final bool dark;
  final bool canSave;
  final bool saving;
  final bool hasExisting;
  final VoidCallback? onSave;

  const SetupSaveButtonWide({
    super.key,
    required this.primaryColor,
    required this.dark,
    required this.canSave,
    required this.saving,
    required this.hasExisting,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor =
        dark ? Theme.of(context).colorScheme.surface : Colors.white;
    final c = primaryColor;

    return Material(
      color: cardColor,
      elevation: canSave ? 2 : 0,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
      child: InkWell(
        onTap: canSave && !saving ? onSave : null,
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: saving
                ? PulsingDots(color: c, size: 6)
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        hasExisting
                            ? Icons.save_rounded
                            : Icons.auto_awesome_rounded,
                        size: 22,
                        color: canSave ? c : c.withValues(alpha: 0.4),
                      ),
                      const SizedBox(width: AppDimensions.spacingMd),
                      Text(
                        hasExisting
                            ? 'Save Changes'
                            : 'Calculate Birth Chart',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: canSave ? c : c.withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
