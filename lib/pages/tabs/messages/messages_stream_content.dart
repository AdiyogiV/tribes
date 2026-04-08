import 'package:aurogram/utils/theme/app_dimensions.dart';
import 'package:flutter/material.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/widgets/ui/skeleton_widgets.dart';

/// Error state widget for the messages stream, with smart error categorization.
class MessagesStreamErrorState extends StatelessWidget {
  final Object? error;
  final bool isRefreshing;
  final VoidCallback onRetry;

  const MessagesStreamErrorState({
    super.key,
    required this.error,
    required this.isRefreshing,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    String errorMessage = 'Error loading messages';
    String errorDetails = 'Pull to refresh or try again';

    final errorText = error.toString().toLowerCase();
    if (errorText.contains('timeout') || errorText.contains('connection')) {
      errorMessage = 'Connection timeout';
      errorDetails = 'Please check your internet connection and try again';
    } else if (errorText.contains('permission') ||
        errorText.contains('denied')) {
      errorMessage = 'Permission denied';
      errorDetails = 'Please check your account permissions';
    } else if (errorText.contains('index') ||
        errorText.contains('requires an index')) {
      errorMessage = 'Database index missing';
      errorDetails = 'Please contact support or try again later';
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off, size: 64, color: Colors.orange[400]),
          SizedBox(height: AppDimensions.spacingLg),
          Text(
            errorMessage,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontSize: 18,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.8),
                ),
          ),
          SizedBox(height: AppDimensions.spacingSm),
          Text(
            errorDetails,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.7),
                ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: AppDimensions.spacingLg),
          ElevatedButton(
            onPressed: isRefreshing ? null : onRetry,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
            child: isRefreshing
                ? PulsingDots(color: Colors.white, size: 6)
                : Text('Retry', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

/// Not-logged-in state for messages page.
class MessagesNotLoggedInState extends StatelessWidget {
  final VoidCallback onLogin;

  const MessagesNotLoggedInState({
    super.key,
    required this.onLogin,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.message_outlined,
            size: 64,
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.4),
          ),
          SizedBox(height: AppDimensions.spacingLg),
          Text(
            'Please log in to view messages',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontSize: 18,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.7),
                ),
          ),
          SizedBox(height: AppDimensions.spacingLg),
          ElevatedButton(
            onPressed: onLogin,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
            child: Text('Log In'),
          ),
        ],
      ),
    );
  }
}
