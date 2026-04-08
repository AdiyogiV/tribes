import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:aurogram/shared/presentation/widgets/media/common_widgets.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:aurogram/features/anonymous_messages/anonymous_message_service.dart';
import 'package:aurogram/shared/services/share/share_media.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/shared/utils/time_display.dart';
import 'package:aurogram/features/anonymous_messages/widgets/message_card.dart';
import 'package:aurogram/features/anonymous_messages/widgets/share_card_builder.dart';
import 'package:aurogram/shared/presentation/widgets/dialogs/login_bottom_sheet.dart';
import 'package:aurogram/features/anonymous_messages/pages/get_link_screen.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';
import 'package:aurogram/shared/presentation/widgets/feedback/snack_bar_service.dart';

class SecretMessagesInboxScreen extends StatefulWidget {
  final bool embedded;

  const SecretMessagesInboxScreen({super.key, this.embedded = false});

  @override
  State<SecretMessagesInboxScreen> createState() =>
      _SecretMessagesInboxScreenState();
}

class _SecretMessagesInboxScreenState extends State<SecretMessagesInboxScreen> {
  final _service = AnonymousMessageService();
  String? _shareLink;

  @override
  void initState() {
    super.initState();
    _loadShareLink();
  }

  Future<void> _loadShareLink() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final slug = await _service.getOrCreateSlug();
      setState(() {
        _shareLink = _service.buildShareLink(slug);
      });
    } catch (e) {
      _service.logError('Failed to load share link', e);
    }
  }

  Future<void> _shareMessage(String message) async {
    final shareLink = _shareLink;
    if (shareLink == null) return;

    final card = SecretMessageShareCard(
      message: message,
      shareLink: shareLink,
    );

    await ShareMedia.shareWidgetAsImage(
      context: context,
      card: card,
      filePrefix: 'secret_message',
      shareText: _service.buildSharePrefill(),
      logLabel: 'secret_message_share',
    );
  }

  Future<void> _reportMessage(String messageId) async {
    // Show dialog to get reason
    final reason = await showDialog<String>(
      context: context,
      builder: (context) {
        final textController = TextEditingController();
        return AlertDialog(
          title: const Text('Report Message'),
          content: TextField(
            controller: textController,
            decoration: const InputDecoration(
              hintText: 'Why are you reporting this message?',
            ),
            maxLines: 3,
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context, textController.text.trim());
              },
              child: const Text('Report'),
            ),
          ],
        );
      },
    );

    if (reason == null || reason.isEmpty) return;

    // Report to reports collection (for App Store compliance)
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('reports').add({
          'messageId': messageId,
          'messageType': 'anonymous',
          'reportedBy': user.uid,
          'reason': reason,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      // Log error but continue
    }

    // Also hide the message
    await _service.updateMessageStatus(messageId, 'hidden');
    if (!mounted) return;
    showCustomSnackBar(context, message: 'Message reported. It will be reviewed within 24 hours.', backgroundColor: AppTheme.primaryColor);
  }

  Future<void> _blockMessage(String messageId) async {
    await _service.updateMessageStatus(messageId, 'blocked');
    if (!mounted) return;
    showCustomSnackBar(context, message: 'Message blocked', backgroundColor: AppTheme.primaryColor);
  }

  Future<void> _deleteMessage(String messageId) async {
    try {
      await FirebaseFirestore.instance
          .collection('anonymousMessages')
          .doc(messageId)
          .delete();
    } catch (e) {
      _service.logError('Failed to delete message', e);
      if (!mounted) return;
      showCustomSnackBar(context, message: 'Could not delete message');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (widget.embedded) {
        return Center(
          child: ElevatedButton(
            onPressed: () => showLoginBottomSheet(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
            child: const Text('Sign in to view inbox'),
          ),
        );
      }
      return Scaffold(
        backgroundColor: AppTheme.scaffoldColor,
        appBar: AppBar(
          title: const Text('Anonymous messages'),
          backgroundColor: AppTheme.scaffoldColor,
          elevation: 0,
        ),
        body: Center(
          child: ElevatedButton(
            onPressed: () => showLoginBottomSheet(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
            child: const Text('Sign in to view inbox'),
          ),
        ),
      );
    }

    final content = StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _service.inboxStream(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AppLoadingIndicator();
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.builder(
          padding: const EdgeInsets.all(AppDimensions.paddingLg),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data();
            final messageId = docs[index].id;
            final text = data['text'] as String? ?? '';
            final timestamp = data['createdAt'];
            final dateTime = timestamp is Timestamp
                ? timestamp.toDate()
                : DateTime.now();
            final timeLabel = TimeDisplay.getCompactTimestamp(dateTime);

            return SecretMessageCard(
              message: text,
              timeLabel: timeLabel,
              onShare: () => _shareMessage(text),
              onDelete: () => _deleteMessage(messageId),
              onReport: () => _reportMessage(messageId),
              onBlock: () => _blockMessage(messageId),
            );
          },
        );
      },
    );

    if (widget.embedded) {
      return content;
    }

    return Scaffold(
      backgroundColor: AppTheme.scaffoldColor,
      appBar: AppBar(
        title: const Text('Anonymous messages'),
        backgroundColor: AppTheme.scaffoldColor,
        elevation: 0,
      ),
      body: SafeArea(child: content),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingXxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.mark_email_unread_outlined,
              size: 60,
              color: AppTheme.textSecondaryColor,
            ),
            const SizedBox(height: AppDimensions.spacingLg),
            Text(
              'No messages yet.',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.textColor,
              ),
            ),
            const SizedBox(height: AppDimensions.spacingSmMd),
            Text(
              'Share your link to get your first one.',
              style: TextStyle(color: AppTheme.textSecondaryColor),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.spacingLg),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const SecretMessagesGetLinkScreen(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
              ),
              child: const Text('Get your link'),
            ),
          ],
        ),
      ),
    );
  }
}
