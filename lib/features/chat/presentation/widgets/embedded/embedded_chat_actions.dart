import 'package:aurogram/core/theme/app_dimensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:aurogram/features/chat/domain/space_chat_service.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/core/di/injection.dart';
import 'package:aurogram/features/profile/domain/user_service.dart';
import 'package:aurogram/shared/data/repositories/user_repository.dart';
import 'package:aurogram/features/profile/domain/namaste_service.dart';
import 'package:aurogram/shared/presentation/widgets/feedback/snack_bar_service.dart';

/// Mixin that provides messaging actions, deduplication, and user-name
/// resolution for the embedded chat view.
///
/// The host state must expose the abstract getters/setters defined here.
mixin EmbeddedChatActionsMixin<T extends StatefulWidget> on State<T> {
  // ------- Abstract accessors the host must provide -------

  SpaceChatService get chatService;
  TextEditingController get messageController;
  FocusNode get textFieldFocusNode;
  String? get currentUserId;
  String get spaceId;
  bool get isDMConversation;
  String? get otherUserId;
  bool get isAtBottom;

  List<ChatMessage> get sendingMessages;
  ChatMessage? get replyingTo;
  set replyingTo(ChatMessage? value);
  bool get namasteSentThisSession;
  set namasteSentThisSession(bool value);

  void scrollToBottomInstant();

  // ------- Sender-name cache (shared across instances) -------

  static final Map<String, String> _senderNameCache = {};

  Future<String> getUserName(String userId) async {
    if (_senderNameCache.containsKey(userId)) {
      final cachedName = _senderNameCache[userId]!;
      if (cachedName != 'Deleted User') {
        try {
          final userDoc = await locator<UserRepository>().getUser(userId);
          if (userDoc.exists) {
            return cachedName;
          }
        } catch (_) {
          // Fall through to full check
        }
      } else {
        return cachedName;
      }
    }

    try {
      final userService = locator<UserService>();
      final name = await userService.getUserDisplayName(userId);
      _senderNameCache[userId] = name;
      return name;
    } catch (e) {
      AppLogger.e('Error fetching user name',
          category: LogCategory.ui,
          data: {'userId': userId, 'error': e.toString()});
      return 'Unknown User';
    }
  }

  // ------- Send text message -------

  Future<void> sendMessage() async {
    final message = messageController.text.trim();
    if (message.isEmpty) return;

    final replyToId = replyingTo?.id;
    final tempId = 'sending_${DateTime.now().millisecondsSinceEpoch}';
    final sendingMessage = ChatMessage(
      id: tempId,
      spaceId: spaceId,
      senderId: currentUserId ?? '',
      senderName: await getUserName(currentUserId ?? ''),
      senderAvatar: null,
      content: message,
      messageType: 'text',
      replyTo: replyToId,
      reactions: {},
      readBy: [],
      timestamp: DateTime.now(),
      status: MessageStatus.sending,
    );

    messageController.clear();
    setState(() {
      sendingMessages.add(sendingMessage);
      replyingTo = null;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (isAtBottom) scrollToBottomInstant();
    });

    try {
      await chatService.sendTextMessage(spaceId, message,
          replyTo: replyToId);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (isAtBottom) scrollToBottomInstant();
      });
    } catch (e) {
      setState(() => sendingMessages.removeWhere((m) => m.id == tempId));
      if (mounted) {
        showCustomSnackBar(context, message: 'Failed to send message', backgroundColor: AppTheme.errorColor, duration: const Duration(seconds: 2));
      }
    }
  }

  // ------- Voice message helpers -------

  void addOptimisticVoiceMessage(ChatMessage message) {
    setState(() {
      sendingMessages.add(message);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (isAtBottom) scrollToBottomInstant();
    });
  }

  void updateVoiceMessageStatus(String messageId, MessageStatus status) {
    setState(() {
      // Placeholder for future retry-button support.
    });
  }

  // ------- Namaste -------

  Future<void> sendNamaste() async {
    if (!isDMConversation || otherUserId == null) return;

    final result = await NamasteService()
        .sendNamaste(otherUserId!, dmId: spaceId);

    if (!mounted) return;

    if (result.success) {
      setState(() => namasteSentThisSession = true);
      final points = result.senderPointsAwarded ?? 0;
      if (points > 0 && mounted) {
        showCustomSnackBar(context, message: '+$points Auro for sending Namaste!', backgroundColor: AppTheme.primaryColor, behavior: SnackBarBehavior.floating);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (isAtBottom) scrollToBottomInstant();
      });
    } else {
      String msg;
      if (result.quotaExceeded) {
        msg = 'Daily limit reached. You can send 3 namastes per day.';
      } else if (result.alreadySentToday) {
        msg = 'Already sent namaste to this person today.';
      } else if (result.blocked) {
        msg = 'Unable to send namaste to this user.';
      } else {
        msg = 'Failed to send Namaste. Please try again.';
      }

      showCustomSnackBar(context, message: msg, backgroundColor: result.quotaExceeded || result.alreadySentToday
              ? AppTheme.primaryColor
              : AppTheme.errorColor, behavior: SnackBarBehavior.floating);
    }
  }

  // ------- Reply / react / time -------

  void startReply(ChatMessage message) {
    HapticFeedback.lightImpact();
    setState(() => replyingTo = message);
    textFieldFocusNode.requestFocus();
  }

  void cancelReply() {
    setState(() => replyingTo = null);
  }

  void quickReact(ChatMessage message) {
    HapticFeedback.mediumImpact();
    chatService.addReaction(message.id, '\u2764\uFE0F');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('\u2764\uFE0F', style: TextStyle(fontSize: 16)),
            SizedBox(width: AppDimensions.spacingSm),
            Text('Reacted'),
          ],
        ),
        backgroundColor: AppTheme.primaryColor,
        duration: const Duration(milliseconds: 800),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 100, left: 80, right: 80),
      ),
    );
  }

  void showExactTime(ChatMessage message) {
    final exactTime = DateFormat('EEEE, MMM d, yyyy \u2022 h:mm a')
        .format(message.timestamp);
    ScaffoldMessenger.of(context).clearSnackBars();
    showCustomSnackBar(context, message: exactTime, backgroundColor: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.9), duration: const Duration(seconds: 2), behavior: SnackBarBehavior.floating);
  }

  // ------- Deduplication -------

  List<ChatMessage> deduplicateMessages(List<ChatMessage> messages) {
    final Map<String, ChatMessage> messageMap = {};
    final Set<String> usedRealMessageIds = {};

    for (final sending in sendingMessages) {
      final realMessage = messages.firstWhere(
        (real) => _isMatchingMessage(real, sending),
        orElse: () => sending,
      );

      if (realMessage != sending) {
        usedRealMessageIds.add(realMessage.id);
        messageMap[realMessage.id] = realMessage;
      } else {
        messageMap[sending.id] = sending;
      }
    }

    for (final message in messages) {
      if (!usedRealMessageIds.contains(message.id) &&
          !message.id.startsWith('sending_')) {
        messageMap[message.id] = message;
      }
    }

    sendingMessages.removeWhere(
        (sending) => messages.any((real) => _isMatchingMessage(real, sending)));

    final result = messageMap.values.toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return result;
  }

  bool _isMatchingMessage(ChatMessage real, ChatMessage sending) {
    if (real.senderId != sending.senderId) return false;
    if (real.messageType != sending.messageType) return false;

    final timeDiff =
        real.timestamp.difference(sending.timestamp).inSeconds.abs();
    if (timeDiff > 30) return false;

    if (sending.messageType == 'audio') {
      return real.fileSize == sending.fileSize;
    }

    return real.content == sending.content;
  }
}
