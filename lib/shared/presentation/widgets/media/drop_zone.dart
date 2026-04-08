// ignore_for_file: avoid_web_libraries_in_flutter

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:aurogram/utils/theme/app_theme.dart';

import 'package:aurogram/utils/theme/app_dimensions.dart';

// Conditional import for web-specific functionality
import 'package:aurogram/widgets/ui/drop_zone_stub.dart'
    if (dart.library.html) 'package:aurogram/widgets/ui/drop_zone_web.dart'
    as drop_zone_impl;

/// A drop zone widget that accepts file drops on web
/// On non-web platforms, it renders the child directly
class DropZone extends StatefulWidget {
  final Widget child;
  final void Function(Uint8List bytes, String fileName)? onFileDrop;
  final List<String> acceptedMimeTypes;
  final bool enabled;

  const DropZone({
    super.key,
    required this.child,
    this.onFileDrop,
    this.acceptedMimeTypes = const ['video/*'],
    this.enabled = true,
  });

  @override
  State<DropZone> createState() => _DropZoneState();
}

class _DropZoneState extends State<DropZone> {
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    // Only enable drop zone on web
    if (!kIsWeb || !widget.enabled || widget.onFileDrop == null) {
      return widget.child;
    }

    return drop_zone_impl.buildDropZone(
      child: widget.child,
      onFileDrop: widget.onFileDrop!,
      acceptedMimeTypes: widget.acceptedMimeTypes,
      isDragging: _isDragging,
      onDragStateChanged: (isDragging) {
        if (mounted) {
          setState(() => _isDragging = isDragging);
        }
      },
      buildOverlay: () => _buildDragOverlay(),
    );
  }

  Widget _buildDragOverlay() {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: _isDragging ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 150),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            border: Border.all(
              color: AppTheme.primaryColor,
              width: 3,
            ),
            borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.cloud_upload_outlined,
                  size: 64,
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(height: AppDimensions.spacingLg),
                Text(
                  'Drop your video here',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: AppDimensions.spacingSm),
                Text(
                  'Supported formats: MP4, MOV, WebM',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white70 : Colors.black54,
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
