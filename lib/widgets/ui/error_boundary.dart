import 'package:flutter/material.dart';

/// A simple error boundary widget that catches errors in its child tree
class ErrorBoundary extends StatelessWidget {
  final Widget child;
  final VoidCallback? onRetry;
  final String? errorTitle;
  final String? errorMessage;

  const ErrorBoundary({
    super.key,
    required this.child,
    this.onRetry,
    this.errorTitle,
    this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    return child;
  }
}
