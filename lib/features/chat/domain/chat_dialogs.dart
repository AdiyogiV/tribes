import 'package:aurogram/core/theme/app_dimensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/features/ai_chat/domain/ai_chat_provider.dart';

class ChatDialogs {
  static Future<void> showClearHistoryDialog(BuildContext context) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Clear Chat History'),
          content: const Text(
            'Are you sure you want to clear all chat history? This action cannot be undone.',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Clear'),
              onPressed: () async {
                try {
                  final provider =
                      Provider.of<AiChatProvider>(context, listen: false);
                  await provider.clearHistory();

                  if (context.mounted) {
                    Navigator.of(context).pop();
                    // History cleared silently - no intrusive feedback needed
                    HapticFeedback.mediumImpact();
                  }
                } catch (e) {
                  AppLogger.e('Error clearing history: $e');

                  if (context.mounted) {
                    Navigator.of(context).pop();
                    // Error logged - no intrusive snackbar needed
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  /// Show dialog to clear ALL AI conversation history
  /// This deletes all past conversations from Firestore
  static Future<void> showClearAllConversationsDialog(
      BuildContext context) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Clear All Conversations'),
          content: const Text(
            'Are you sure you want to delete all your Aurobhatt conversation history? This will permanently remove all past conversations and cannot be undone.',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('Delete All'),
              onPressed: () async {
                try {
                  final provider =
                      Provider.of<AiChatProvider>(context, listen: false);
                  await provider.clearAllConversations();

                  if (context.mounted) {
                    Navigator.of(context).pop();
                    HapticFeedback.mediumImpact();
                  }
                } catch (e) {
                  AppLogger.e('Error clearing all conversations: $e');

                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  static Future<void> showChatSettings(BuildContext context) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Chat Settings'),
          content: const SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Chat settings will be available soon.'),
                SizedBox(height: AppDimensions.spacingLg),
                Text('Features coming:'),
                Text('• Export chat history'),
                Text('• Change AI model'),
                Text('• Adjust response length'),
                Text('• Custom prompts'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}
