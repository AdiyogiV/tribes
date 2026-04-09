import 'package:flutter/material.dart';

/// Stub IncomingCallScreen for web — calling is not supported on web
class IncomingCallScreen extends StatelessWidget {
  final dynamic call;

  const IncomingCallScreen({super.key, this.call});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Calling is not available on web')),
    );
  }
}
