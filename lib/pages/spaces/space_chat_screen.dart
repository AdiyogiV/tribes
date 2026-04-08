import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:aurogram/models/space.dart';
import 'package:aurogram/services/chat/space_chat_service.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/utils/logging/app_logger.dart';
import 'package:aurogram/services/chat/chat_notification_service.dart';
import 'package:aurogram/widgets/call/active_call_banner.dart';
import 'package:aurogram/utils/responsive.dart';
import 'package:aurogram/utils/dependency_injection.dart';
import 'package:aurogram/services/user_service.dart';
import 'package:aurogram/widgets/common/snack_bar_service.dart';

// Extracted widgets
import 'widgets/space_chat_input.dart';
import 'widgets/space_chat_dialogs.dart';
import 'widgets/space_chat_overlays.dart';
import 'widgets/space_chat_message_list.dart';
import 'widgets/space_chat_app_bar.dart';
import 'widgets/space_chat_scroll_fab.dart';
import 'widgets/space_chat_message_tile_builder.dart';
import 'widgets/space_chat_actions.dart';
import 'widgets/space_chat_header_row.dart';
import 'widgets/space_chat_dedup.dart';

class SpaceChatScreen extends StatefulWidget {
  final String spaceId;
  final Space? space;
  final String? otherUserId;

  /// Optional initial text for the message field (e.g. "Replying to your story").
  final String? initialMessage;

  const SpaceChatScreen({
    super.key,
    required this.spaceId,
    this.space,
    this.otherUserId,
    this.initialMessage,
  });

  @override
  SpaceChatScreenState createState() => SpaceChatScreenState();
}

class SpaceChatScreenState extends State<SpaceChatScreen>
    with SpaceChatActionsMixin {
  final SpaceChatService _chatService = SpaceChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _textFieldFocusNode = FocusNode();
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  // Cache for sender names
  static final Map<String, String> _senderNameCache = {};

  // State
  String? _displayName;
  bool _isLoadingName = false;
  final List<ChatMessage> _sendingMessages = [];
  bool _isAtBottom = true;
  final bool _isConnected = true;
  List<TypingUser> _typingUsers = [];
  bool _isTyping = false;
  Timer? _typingTimer;
  StreamSubscription? _typingSubscription;
  ChatMessage? _replyingTo;
  final Map<String, ChatMessage> _repliedMessagesCache = {};
  List<ChatMessage> _allMessages = [];
  bool _isOtherUserOnline = false;
  DateTime? _otherUserLastSeen;
  StreamSubscription? _onlineStatusSubscription;
  bool _namasteSentThisSession = false;

  /// Instagram-style: swipe left to reveal timestamps on the right.
  double _timestampRevealOffset = 0.0;
  static const double _kTimestampRevealStripWidth = 80.0;
  bool _isDraggingReveal = false;
  double _totalDragDx = 0;
  double _totalDragDy = 0;

  // Conversation status tracking (for message requests)
  String? _conversationStatus;
  String? _requestedBy;
  bool get _isDMConversation => widget.spaceId.startsWith('dm_');
  bool get _isPendingRequest =>
      _isDMConversation &&
      _conversationStatus == 'pending' &&
      _requestedBy != _currentUser?.uid;

  // ─── Mixin interface ────────────────────────────────────────────────

  @override
  String get actionSpaceId => widget.spaceId;
  @override
  String? get actionOtherUserId => widget.otherUserId;
  @override
  String? get actionDisplayName => _displayName;
  @override
  bool get actionIsDMConversation => _isDMConversation;
  @override
  SpaceChatService get actionChatService => _chatService;
  @override
  String? get actionCurrentUserId => _currentUser?.uid;
  @override
  String? get actionSpaceName => widget.space?.name;
  @override
  void actionSetNamasteSent() => setState(() => _namasteSentThisSession = true);
  @override
  void actionSetReplyingTo(ChatMessage? m) => setState(() => _replyingTo = m);
  @override
  FocusNode get actionTextFieldFocusNode => _textFieldFocusNode;
  @override
  bool get actionIsAtBottom => _isAtBottom;
  @override
  void actionScrollToBottomInstant() => _scrollToBottomInstant();
  @override
  void actionScrollToMessage(String id) => _scrollToMessage(id);

  // ─── Lifecycle ──────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    ChatNotificationService.setActiveChat(widget.spaceId);
    _scrollController.addListener(_onScroll);
    _textFieldFocusNode.addListener(_onFocusChange);

    if (_isDMConversation && widget.otherUserId != null) {
      _loadDisplayName();
      _listenToOnlineStatus();
    } else {
      _displayName = widget.space?.name ?? 'Chat';
    }

    if (widget.initialMessage != null && widget.initialMessage!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _messageController.text = widget.initialMessage!;
          setState(() {});
        }
      });
    }

    _listenToTypingUsers();

    if (_isDMConversation) {
      _listenToConversationStatus();
    }
  }

  @override
  void dispose() {
    ChatNotificationService.clearActiveChat();
    _scrollController.removeListener(_onScroll);
    _messageController.dispose();
    _scrollController.dispose();
    _onlineStatusSubscription?.cancel();
    _typingSubscription?.cancel();
    _typingTimer?.cancel();
    _chatService.setTyping(widget.spaceId, false);
    _textFieldFocusNode.dispose();
    super.dispose();
  }

  // ─── Listeners & data loading ───────────────────────────────────────

  void _listenToConversationStatus() {
    FirebaseFirestore.instance
        .collection('dmConversations')
        .doc(widget.spaceId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && mounted) {
        final data = snapshot.data();
        setState(() {
          _conversationStatus = data?['status'] as String?;
          _requestedBy = data?['requestedBy'] as String?;
        });
      }
    });
  }

  void _listenToTypingUsers() {
    _typingSubscription = _chatService.getTypingUsers(widget.spaceId).listen(
      (users) {
        if (mounted) setState(() => _typingUsers = users);
      },
      onError: (e) {
        AppLogger.w('Error listening to typing users',
            category: LogCategory.ui, data: {'error': e.toString()});
      },
    );
  }

  void _listenToOnlineStatus() {
    if (widget.otherUserId == null) return;
    _onlineStatusSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.otherUserId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && mounted) {
        final data = snapshot.data();
        setState(() {
          _isOtherUserOnline = data?['isOnline'] as bool? ?? false;
          _otherUserLastSeen = (data?['lastSeen'] as Timestamp?)?.toDate();
        });
      }
    });
  }

  Future<void> _loadDisplayName() async {
    if (widget.otherUserId == null) {
      _displayName = widget.space?.name ?? 'Chat';
      return;
    }

    setState(() => _isLoadingName = true);

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.otherUserId!)
          .get();

      if (userDoc.exists && mounted) {
        final userData = userDoc.data();
        final name = userData?['name'] as String? ??
            userData?['nickname'] as String? ??
            widget.space?.name ??
            'Chat';
        setState(() {
          _displayName = name;
          _isLoadingName = false;
        });
        return;
      }
    } catch (e) {
      AppLogger.w('Error loading display name',
          category: LogCategory.ui, data: {'error': e.toString()});
    }

    if (mounted) {
      setState(() {
        _displayName = widget.space?.name ?? 'Chat';
        _isLoadingName = false;
      });
    }
  }

  Future<String> _getUserName(String userId) async {
    if (_senderNameCache.containsKey(userId)) {
      final cachedName = _senderNameCache[userId]!;
      if (cachedName != 'Deleted User') {
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .get();
          if (userDoc.exists) return cachedName;
        } catch (_) {}
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

  // ─── Scroll helpers ─────────────────────────────────────────────────

  void _onScroll() {
    if (_scrollController.hasClients) {
      final wasAtBottom = _isAtBottom;
      _isAtBottom = _scrollController.offset <= 100;
      if (wasAtBottom != _isAtBottom) setState(() {});
    }
  }

  void _onFocusChange() {
    if (_textFieldFocusNode.hasFocus) {
      _forceScrollToBottom();
      for (int delay in [50, 150, 300, 500]) {
        Future.delayed(Duration(milliseconds: delay), () {
          if (mounted) _forceScrollToBottom();
        });
      }
    }
  }

  void _scrollToBottomInstant() {
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
  }

  void _forceScrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scrollController.hasClients) {
        _scrollController.animateTo(0,
            duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  void _scrollToMessage(String messageId) {
    final index = _allMessages.indexWhere((m) => m.id == messageId);
    if (index == -1) return;

    if (!kIsWeb) HapticFeedback.lightImpact();
    final reversedIndex = _allMessages.length - 1 - index;
    final estimatedPosition = reversedIndex * 85.0;

    _scrollController.animateTo(
      estimatedPosition.clamp(0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  // ─── Typing ─────────────────────────────────────────────────────────

  void _onTextChanged(String text) {
    if (text.trim().isNotEmpty && !_isTyping) {
      setState(() => _isTyping = true);
      _chatService.setTyping(widget.spaceId, true);
    }
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      if (mounted && _isTyping) {
        setState(() => _isTyping = false);
        _chatService.setTyping(widget.spaceId, false);
      }
    });
  }

  // ─── Message sending ────────────────────────────────────────────────

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    final replyToId = _replyingTo?.id;
    final tempId = 'sending_${DateTime.now().millisecondsSinceEpoch}';
    final sendingMessage = ChatMessage(
      id: tempId,
      spaceId: widget.spaceId,
      senderId: _currentUser?.uid ?? '',
      senderName: await _getUserName(_currentUser?.uid ?? ''),
      senderAvatar: null,
      content: message,
      messageType: 'text',
      replyTo: replyToId,
      reactions: {},
      readBy: [],
      timestamp: DateTime.now(),
      status: MessageStatus.sending,
    );

    _messageController.clear();
    setState(() {
      _sendingMessages.add(sendingMessage);
      _replyingTo = null;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isAtBottom) _scrollToBottomInstant();
    });

    try {
      List<String>? mentionedUserIds;
      if (message.contains('@')) {
        try {
          final users = await _chatService.getMentionableUsers(widget.spaceId);
          mentionedUserIds = _extractMentionedUserIds(message, users);
        } catch (e) {
          // Ignore mention extraction errors
        }
      }

      await _chatService.sendTextMessage(widget.spaceId, message,
          replyTo: replyToId, mentionedUserIds: mentionedUserIds);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_isAtBottom) _scrollToBottomInstant();
      });
    } catch (e) {
      setState(() => _sendingMessages.removeWhere((m) => m.id == tempId));
      if (mounted) {
        showCustomSnackBar(context, message: 'Failed to send message', backgroundColor: AppTheme.errorColor, duration: const Duration(seconds: 2));
      }
    }
  }

  List<String> _extractMentionedUserIds(
      String text, List<MentionableUser> users) {
    final mentionedIds = <String>[];
    final mentionPattern = RegExp(r'@(\w+)');

    for (final match in mentionPattern.allMatches(text)) {
      final name = match.group(1)?.toLowerCase();
      if (name != null) {
        for (final user in users) {
          if (user.name.toLowerCase() == name &&
              !mentionedIds.contains(user.userId)) {
            mentionedIds.add(user.userId);
            break;
          }
        }
      }
    }

    return mentionedIds;
  }

  void _addOptimisticVoiceMessage(ChatMessage message) {
    setState(() => _sendingMessages.add(message));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isAtBottom) _scrollToBottomInstant();
    });
  }

  void _updateVoiceMessageStatus(String messageId, MessageStatus status) {
    setState(() {
      // Keep the message in sending state; future: show retry button
    });
  }

  List<ChatMessage> _deduplicateMessages(List<ChatMessage> messages) =>
      SpaceChatDedup.deduplicateMessages(messages, _sendingMessages);

  // ─── Build ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color scaffoldColor =
        isDark ? AppTheme.scaffoldDarkColor : AppTheme.scaffoldLightColor;
    final bool isDesktop = Responsive.isDesktop(context);

    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      appBar: SpaceChatAppBar(headerContent: _buildHeader()),
      backgroundColor: scaffoldColor,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final contentPadding =
                Responsive.horizontalPaddingFor(constraints.maxWidth, 700);
            return Stack(
              children: [
                Positioned.fill(
                    child: _buildMessagesList(contentPadding)),
                if (_isPendingRequest)
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 54,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: isDesktop ? 700 : double.infinity,
                        ),
                        child: ChatRequestBanner(
                          isDark: isDark,
                          displayName: _displayName,
                          onAccept: acceptRequest,
                          onDecline: declineRequest,
                        ),
                      ),
                    ),
                  ),
                if (!_isDMConversation)
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 54,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: isDesktop ? 700 : double.infinity,
                        ),
                        child: ActiveCallBanner(
                          spaceId: widget.spaceId,
                          spaceName: widget.space?.name ?? 'Group Call',
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: isDesktop ? 700 : double.infinity,
                      ),
                      child: SpaceChatInputArea(
                        key: ValueKey('chat_input_${widget.spaceId}'),
                        messageController: _messageController,
                        textFieldFocusNode: _textFieldFocusNode,
                        replyingTo: _replyingTo,
                        isDMConversation: _isDMConversation,
                        namasteSentThisSession: _namasteSentThisSession,
                        spaceId: widget.spaceId,
                        onSendMessage: _sendMessage,
                        onSendNamaste: sendNamaste,
                        onCancelReply: cancelReply,
                        onTextChanged: _onTextChanged,
                        onOptimisticVoiceMessage: _addOptimisticVoiceMessage,
                        onVoiceMessageStatusUpdate: _updateVoiceMessageStatus,
                        isPendingRequest: _isPendingRequest,
                      ),
                    ),
                  ),
                ),
                if (!_isAtBottom)
                  Positioned(
                    bottom: 140,
                    right: 16 + contentPadding,
                    child: _buildScrollToBottomFAB(),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() => SpaceChatHeaderRow(
        displayName: _displayName,
        otherUserId: widget.otherUserId,
        spaceId: widget.spaceId,
        isDMConversation: _isDMConversation,
        isLoadingName: _isLoadingName,
        isOtherUserOnline: _isOtherUserOnline,
        otherUserLastSeen: _otherUserLastSeen,
        space: widget.space,
        onNavigateToHeader: navigateToHeader,
        onConversationOptions: openConversationOptions,
        onGalleryTap: openMediaGallery,
        onSearchTap: openMessageSearch,
      );

  Widget _buildScrollToBottomFAB() =>
      SpaceChatScrollFAB(scrollController: _scrollController);

  Widget _buildMessagesList(double horizontalPadding) {
    return SpaceChatMessageList(
      scrollController: _scrollController,
      chatService: _chatService,
      spaceId: widget.spaceId,
      horizontalPadding: horizontalPadding,
      isConnected: _isConnected,
      typingUsers: _typingUsers,
      sendingMessages: _sendingMessages,
      repliedMessagesCache: _repliedMessagesCache,
      isDMConversation: _isDMConversation,
      currentUserId: _currentUser?.uid,
      timestampRevealOffset: _timestampRevealOffset,
      isDraggingReveal: _isDraggingReveal,
      onPointerDown: (_) {
        setState(() {
          _totalDragDx = 0;
          _totalDragDy = 0;
        });
      },
      onPointerMove: (e) {
        _totalDragDx += e.delta.dx;
        _totalDragDy += e.delta.dy;
        final absDx = _totalDragDx.abs();
        final absDy = _totalDragDy.abs();
        if (!_isDraggingReveal &&
            (absDx > 8 || absDy > 8) &&
            absDx > absDy) {
          setState(() => _isDraggingReveal = true);
        }
        if (_isDraggingReveal) {
          setState(() {
            _timestampRevealOffset =
                (_timestampRevealOffset - e.delta.dx)
                    .clamp(0.0, _kTimestampRevealStripWidth);
          });
        }
      },
      onPointerUp: (_) {
        setState(() {
          _isDraggingReveal = false;
          _timestampRevealOffset = 0.0;
        });
      },
      onPointerCancel: (_) {
        setState(() {
          _isDraggingReveal = false;
          _timestampRevealOffset = 0.0;
        });
      },
      deduplicateMessages: _deduplicateMessages,
      onMessagesUpdated: (allMessages) {
        _allMessages = allMessages;
        for (final msg in allMessages) {
          _repliedMessagesCache[msg.id] = msg;
        }
      },
      buildMessageTile: _buildMessageTile,
      onReply: startReply,
      onQuickReact: quickReact,
      onShowTime: showExactTime,
      onLongPress: showMessageOptions,
      onShowReactions: showReactionsSheet,
      onForward: (msg) => SpaceChatDialogs.forwardMessage(context,
          message: msg, chatService: _chatService),
      onScrollToMessage: _scrollToMessage,
    );
  }

  late final _tileBuilder = SpaceChatMessageTileBuilder(
    currentUserId: _currentUser?.uid,
    otherUserId: widget.otherUserId,
    displayName: _displayName,
    isDMConversation: _isDMConversation,
    chatService: _chatService,
    repliedMessagesCache: _repliedMessagesCache,
    onStartReply: startReply,
    onQuickReact: quickReact,
    onShowExactTime: showExactTime,
    onShowMessageOptions: showMessageOptions,
    onShowReactionsSheet: showReactionsSheet,
    onScrollToMessage: _scrollToMessage,
    onCallBack: callBack,
  );

  Widget _buildMessageTile(ChatMessage message, bool isOwnMessage,
      bool isPending, bool isFirstInGroup, bool isLastInGroup) {
    return _tileBuilder.build(
        context, message, isOwnMessage, isPending, isFirstInGroup, isLastInGroup);
  }
}
