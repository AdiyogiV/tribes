import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:aurogram/utils/theme/app_dimensions.dart';

/// Draggable local video preview (picture-in-picture) widget
class CallLocalVideoPip extends StatelessWidget {
  final RTCVideoRenderer? localRenderer;
  final bool isDesktop;
  final bool isLocalVideoLarge;
  final bool isCameraOff;
  final Offset position;
  final VoidCallback onToggleSize;
  final ValueChanged<Offset> onPositionChanged;

  const CallLocalVideoPip({
    super.key,
    required this.localRenderer,
    required this.isDesktop,
    required this.isLocalVideoLarge,
    required this.isCameraOff,
    required this.position,
    required this.onToggleSize,
    required this.onPositionChanged,
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final topPadding = MediaQuery.of(context).padding.top;

    // Calculate current size
    final width = isDesktop
        ? (isLocalVideoLarge ? 240.0 : 180.0)
        : (isLocalVideoLarge ? 180.0 : 120.0);
    final height = isDesktop
        ? (isLocalVideoLarge ? 320.0 : 240.0)
        : (isLocalVideoLarge ? 240.0 : 160.0);

    // Clamp position to ensure it stays within bounds
    final maxX = screenSize.width - width;
    final maxY = screenSize.height - height;
    const minX = 0.0;
    final minY = topPadding;

    final clampedPosition = Offset(
      position.dx.clamp(minX, maxX),
      position.dy.clamp(minY, maxY),
    );

    return Positioned(
      left: clampedPosition.dx,
      top: clampedPosition.dy,
      child: GestureDetector(
        onTap: onToggleSize,
        onPanUpdate: (details) {
          // Calculate new position
          var newX = clampedPosition.dx + details.delta.dx;
          var newY = clampedPosition.dy + details.delta.dy;

          // Keep within screen bounds
          newX = newX.clamp(minX, maxX);
          newY = newY.clamp(minY, maxY);

          onPositionChanged(Offset(newX, newY));
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDesktop ? 0.6 : 0.5),
                blurRadius: isDesktop ? 20 : 10,
                spreadRadius: isDesktop ? 4 : 2,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMdLg),
            child: (localRenderer != null &&
                    localRenderer!.srcObject != null &&
                    !isCameraOff)
                ? RTCVideoView(
                    localRenderer!,
                    mirror: true,
                    objectFit:
                        RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
                  )
                : Container(
                    color: const Color(0xFF2A2A3E),
                    child: Center(
                      child: Icon(
                        Icons.videocam_off_rounded,
                        color: Colors.white54,
                        size: isDesktop ? 40 : 32,
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
