import 'package:flutter/material.dart';
import 'package:aurogram/core/theme/app_theme.dart';

/// Stateless presentational pieces for the minimal birth-details form.
///
/// Kept separate from ImmersiveSetupPage purely for cohesion / file size: these
/// are dumb widgets driven entirely by params + callbacks, no state of their own.
class BirthFormWidgets {
  BirthFormWidgets._();

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static String monthAbbr(int m) => _months[(m - 1).clamp(0, 11)];

  /// The "let Aurobhatt fill it" mic banner.
  static Widget assistBanner({
    required ThemeData theme,
    required Color primary,
    required bool active,
    required String hint,
    required VoidCallback onTap,
  }) {
    return Material(
      color: primary.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: active ? primary : primary.withValues(alpha: 0.18),
                ),
                child: Icon(active ? Icons.stop_rounded : Icons.mic_rounded,
                    color: active ? Colors.white : primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(hint,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// A tappable field row (date / time / place).
  static Widget field({
    required ThemeData theme,
    required IconData icon,
    required String label,
    required String? value,
    required String placeholder,
    required VoidCallback onTap,
  }) {
    final filled = value != null && value.isNotEmpty;
    return Material(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Icon(icon, size: 20, color: theme.hintColor),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: theme.hintColor)),
                    const SizedBox(height: 2),
                    Text(
                      filled ? value : placeholder,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: filled
                            ? theme.textTheme.bodyLarge?.color
                            : theme.hintColor,
                        fontWeight: filled ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: theme.hintColor),
            ],
          ),
        ),
      ),
    );
  }

  /// The primary submit ("Reveal my chart") button.
  static Widget submitButton({
    required Color primary,
    required bool enabled,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 54,
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: primary.withValues(alpha: 0.3),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: const Text('Reveal my chart',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      ),
    );
  }

  /// Bottom-sheet scaffold used to host a wheel picker + Done button.
  static Future<void> pickerSheet({
    required BuildContext context,
    required String title,
    required Widget child,
    required VoidCallback onDone,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title,
                style: Theme.of(ctx)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            child,
            const SizedBox(height: 16),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  onDone();
                  Navigator.of(ctx).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Done',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
