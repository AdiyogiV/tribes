import 'package:flutter/material.dart';
import 'package:aurogram/widgets/common/snack_bar_service.dart';

/// Stub for GroupCallScreen on web
/// This screen is never shown on web since group calling is not supported
class GroupCallScreen extends StatelessWidget {
  final String spaceId;
  final String spaceName;

  const GroupCallScreen({
    super.key,
    required this.spaceId,
    required this.spaceName,
  });

  @override
  Widget build(BuildContext context) {
    // This should never be shown on web
    // If somehow navigated here, show a message and go back
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        Navigator.of(context).pop();
        showCustomSnackBar(context, message: 'Group calling is not available on web');
      }
    });

    return const Scaffold(
      body: Center(
        child: Text('Group calling not supported on web'),
      ),
    );
  }
}
