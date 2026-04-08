import 'package:flutter/material.dart';
import 'package:aurogram/utils/theme/app_dimensions.dart';

/// Banner widget displayed when camera/microphone permissions are denied
class CallPermissionBanner extends StatelessWidget {
  final String errorMessage;
  final VoidCallback onDismiss;

  const CallPermissionBanner({
    super.key,
    required this.errorMessage,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.all(AppDimensions.paddingMd),
        padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingLg, vertical: AppDimensions.paddingMd),
        decoration: BoxDecoration(
          color: Colors.orange.shade700,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: Colors.white, size: 24),
            const SizedBox(width: AppDimensions.spacingMd),
            Expanded(
              child: Text(
                errorMessage,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: AppDimensions.spacingSm),
            IconButton(
              icon: const Icon(Icons.close_rounded,
                  color: Colors.white, size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: 32,
                minHeight: 32,
              ),
              onPressed: onDismiss,
            ),
          ],
        ),
      ),
    );
  }
}
