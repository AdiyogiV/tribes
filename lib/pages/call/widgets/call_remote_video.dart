import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:aurogram/utils/logging/app_logger.dart';

// Agent debug logging: only in debug mode
void _agentDebugLog(String location, String message, Map<String, dynamic> data,
    String hypothesisId) {
  if (!kDebugMode) return;
  AppLogger.d('CallRemoteVideo[$location]: $message',
      category: LogCategory.general,
      data: {...data, 'hypothesisId': hypothesisId});
}

/// Builds a remote video view with Key and explicit size.
/// Shows RTCVideoView when we have a remote stream (on renderer or pending
/// from service) so the native view exists before attach.
class CallRemoteVideo extends StatelessWidget {
  final RTCVideoRenderer? remoteRenderer;
  final bool hasStreamFromService;
  final RTCVideoViewObjectFit objectFit;
  final Widget avatar;

  const CallRemoteVideo({
    super.key,
    required this.remoteRenderer,
    required this.hasStreamFromService,
    required this.objectFit,
    required this.avatar,
  });

  @override
  Widget build(BuildContext context) {
    final hasStreamOnRenderer = remoteRenderer?.srcObject != null;
    final showRtcView =
        remoteRenderer != null && (hasStreamOnRenderer || hasStreamFromService);
    // #region agent log
    _agentDebugLog(
        'call_remote_video.dart:build',
        'placeholder choice',
        {
          'showRtcView': showRtcView,
          'hasStreamOnRenderer': hasStreamOnRenderer,
          'hasStreamFromService': hasStreamFromService,
          'remoteRendererNull': remoteRenderer == null,
        },
        'H3');
    // #endregion
    if (showRtcView) {
      // Stable key so same native view is kept when we attach stream in post-frame
      return SizedBox.expand(
        child: RTCVideoView(
          remoteRenderer!,
          key: const ValueKey<String>('remote_video'),
          objectFit: objectFit,
        ),
      );
    }
    return avatar;
  }
}
