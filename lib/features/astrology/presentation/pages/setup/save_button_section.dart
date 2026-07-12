import 'package:flutter/material.dart';
import 'package:aurogram/shared/presentation/widgets/loaders/skeleton_widgets.dart';

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
    final c = primaryColor;

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(
          32,
          16,
          32,
          MediaQuery.of(context).padding.bottom + 24,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0),
              Theme.of(context).scaffoldBackgroundColor,
            ],
            stops: const [0.0, 0.3],
          ),
        ),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: canSave && !saving ? onSave : null,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: saving
                ? PulsingDots(color: c, size: 6)
                : Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    decoration: BoxDecoration(
                      color: canSave ? c : c.withValues(alpha: 0.1),
                    ),
                    child: Text(
                      (hasExisting ? 'SAVE CHANGES' : 'CALCULATE').toUpperCase(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: canSave ? (dark ? Colors.black : Colors.white) : c.withValues(alpha: 0.3),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2.0,
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
    final c = primaryColor;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: canSave && !saving ? onSave : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: saving
              ? PulsingDots(color: c, size: 6)
              : Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  decoration: BoxDecoration(
                    color: canSave ? c : c.withValues(alpha: 0.1),
                  ),
                  child: Text(
                    (hasExisting ? 'SAVE CHANGES' : 'CALCULATE').toUpperCase(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: canSave ? (dark ? Colors.black : Colors.white) : c.withValues(alpha: 0.3),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2.0,
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
