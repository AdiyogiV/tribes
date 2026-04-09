import 'package:flutter/material.dart';
import 'package:aurogram/shared/models/call.dart';

/// Stub CallScreen for web — calling is not supported on web
class CallScreen extends StatelessWidget {
  final String calleeId;
  final String calleeName;
  final String? calleeAvatar;
  final CallType callType;
  final bool isIncoming;

  const CallScreen({
    super.key,
    required this.calleeId,
    required this.calleeName,
    this.calleeAvatar,
    this.callType = CallType.voice,
    this.isIncoming = false,
  });

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Calling is not available on web')),
    );
  }
}
