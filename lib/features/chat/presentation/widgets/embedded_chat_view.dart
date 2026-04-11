import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:aurogram/shared/models/space.dart';
import 'package:aurogram/features/chat/domain/space_chat_service.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/core/di/injection.dart';
import 'package:aurogram/shared/data/repositories/user_repository.dart';
import 'package:go_router/go_router.dart';
import 'package:aurogram/core/routing/route_names.dart';
import 'package:aurogram/features/chat/domain/chat_notification_service.dart';
import 'package:aurogram/features/calling/presentation/widgets/active_call_banner.dart';
import 'package:aurogram/features/spaces/presentation/widgets/space_chat_input.dart';
import 'package:aurogram/features/chat/presentation/widgets/message_search_sheet.dart';
import 'package:aurogram/features/chat/presentation/widgets/embedded/embedded.dart';

/// An embeddable chat view that can be used inside a master-detail layout.
/// Unlike SpaceChatScreen, this doesn't use its own Scaffold and is designed
/// to be embedded within another widget tree.
class EmbeddedChatView extends StatefulWidget {
  final String spaceId;
  final Space? space;
  final String? otherUserId;

  /// Optional callback when back is pressed (for desktop, may want to deselect)
  final VoidCallback? onBack;

  /// Whether to show the header (can hide if parent provides header)
  final bool showHeader;

  const EmbeddedChatView({
    super.key,
    required this.spaceId,
    this.space,
    this.otherUserId,
    this.onBack,
    this.showHeader = true,
  });

  @override
  EmbeddedChatViewState createState() => EmbeddedChatViewState();
}

class EmbeddedChatViewState extends State<EmbeddedChatView>
    with EmbeddedChatActionsMixin {
  final SpaceChatService _chatService = SpaceChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _textFieldFocusNode = FocusNode();
  final User? _currentUser = FirebaseAuth.instance.currentUser;

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

  // ------- Mixin accessors -------

  @override
  SpaceChatService get chatService => _chatService;
  @override
  TextEditingController get messageController => _messageController;
  @override
  FocusNode get textFieldFocusNode => _textFieldFocusNode;
  @override
  String? get currentUserId => _currentUser?.uid;
  @override
  String get spaceId => widget.spaceId;
  @override
  bool get isDMConversation => widget.spaceId.startsWith('dm_');
  @override
  String? get otherUserId => widget.otherUserId;
  @override
  bool get isAtBottom => _isAtBottom;
  @override
  List<ChatMessage> get sendingMessages => _sendingMessages;
  @override
  ChatMessage? get replyingTo => _replyingTo;
  @override
  set replyingTo(ChatMessage? value) => _replyingTo = value;
  @override
  bool get namasteSentThisSession => _namasteSentThisSession;
  @override
  set namasteSentThisSession(bool value) => _namasteSentThisSession = value;
  @override
  void scrollToBottomInstant() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(_bottomScrollOffset);
    }
  }

  // ------- Lifecycle -------

  @override
  void initState() {
    super.initState();
    ChatNotificationService.setActiveChat(widget.spaceId);
    _scrollController.addListener(_onScroll);
    _textFieldFocusNode.addListener(_onFocusChange);

    if (isDMConversation && widget.otherUserId != null) {
      _loadDisplayName();
      _listenToOnlineStatus();
    } else {
      _displayName = widget.space?.name ?? 'Chat';
    }

    _listenToTypingUsers();
  }

  @override
  void didUpdateWidget(EmbeddedChatView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.spaceId != widget.spaceId) {
      ChatNotificationService.setActiveChat(widget.spaceId);
      _typingSubscription?.cancel();
      _onlineStatusSubscription?.cancel();
      _sendingMessages.clear();
      _allMessages.clear();
      _repliedMessagesCache.clear();
      _replyingTo = null;
      _namasteSentThisSession = false;

      if (isDMConversation && widget.otherUserId != null) {
        _loadDisplayName();
        _listenToOnlineStatus();
      } else {
        _displayName = widget.space?.name ?? 'Chat';
      }

      _listenToTypingUsers();
    }
  }

  @override
  void dispose() {
    ChatNotificationService.clearActiveChat();
    _scrollController.removeListener(_onScroll);
    _messageController.dispose();
    _scrollController.dispose();
    _typingSubscription?.cancel();
    _onlineStatusSubscription?.cancel();
    _typingTimer?.cancel();
    _chatService.setTyping(widget.spaceId, false);
    _textFieldFocusNode.dispose();
    super.dispose();
  }

  // ------- Listeners & loaders -------

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

  void _listenToOnlineStatus() {
    if (widget.otherUserId == null) return;
    _onlineStatusSubscription = locator<UserRepository>()
        .userStream(widget.otherUserId!)
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
      final userDoc = await locator<UserRepository>()
          .getUser(widget.otherUserId!);
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

  // ------- Scroll helpers -------

  void _onScroll() {
    if (_scrollController.hasClients) {
      final wasAtBottom = _isAtBottom;
      _isAtBottom = _scrollController.offset <= 80;
      if (wasAtBottom != _isAtBottom) setState(() {});
    }
  }

  double get _bottomScrollOffset => 0;

  void _forceScrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scrollController.hasClients) {
        _scrollController.animateTo(_bottomScrollOffset,
            duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  void _scrollToMessage(String messageId) {
    final index = _allMessages.indexWhere((m) => m.id == messageId);
    if (index == -1) return;
    HapticFeedback.lightImpact();
    final reversedIndex = _allMessages.length - 1 - index;
    final estimatedPosition = reversedIndex * 85.0;
    _scrollController.animateTo(
      estimatedPosition.clamp(0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  // ------- Text / typing -------

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

  // ------- Navigation -------

  void _navigateToHeader() {
    if (isDMConversation && widget.otherUserId != null) {
      context.push('${RouteNames.userProfile}/${widget.otherUserId}');
    } else if (!isDMConversation) {
      context.push('${RouteNames.spaceScreen}/${widget.spaceId}');
    }
  }

  void _openMediaGallery() {
    context.push('/media/gallery/${widget.spaceId}', extra: {
      'title': _displayName ?? 'Media',
    });
  }

  void _openMessageSearch() {
    MessageSearchSheet.show(
      context,
      spaceId: widget.spaceId,
      onMessageSelected: (message) => _scrollToMessage(message.id),
    );
  }

  // ------- Timestamp-reveal gesture handlers -------

  void _onTimestampPointerDown() {
    setState(() {
      _totalDragDx = 0;
      _totalDragDy = 0;
    });
  }

  void _onTimestampPointerMove(PointerMoveEvent e) {
    _totalDragDx += e.delta.dx;
    _totalDragDy += e.delta.dy;
    final absDx = _totalDragDx.abs();
    final absDy = _totalDragDy.abs();
    if (!_isDraggingReveal && (absDx > 8 || absDy > 8) && absDx > absDy) {
      setState(() => _isDraggingReveal = true);
    }
    if (_isDraggingReveal) {
      setState(() {
        _timestampRevealOffset = (_timestampRevealOffset - e.delta.dx)
            .clamp(0.0, _kTimestampRevealStripWidth);
      });
    }
  }

  void _onTimestampPointerUp() {
    setState(() {
      _isDraggingReveal = false;
      _timestampRevealOffset = 0.0;
    });
  }

  // ------- Build -------

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color scaffoldColor =
        isDark ? AppTheme.scaffoldDarkColor : AppTheme.scaffoldLightColor;

    return Container(
      color: scaffoldColor,
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: Column(
          children: [
            if (widget.showHeader)
              EmbeddedChatHeader(
                spaceId: widget.spaceId,
                otherUserId: widget.otherUserId,
                displayName: _displayName,
                isDMConversation: isDMConversation,
                isLoadingName: _isLoadingName,
                isOtherUserOnline: _isOtherUserOnline,
                otherUserLastSeen: _otherUserLastSeen,
                space: widget.space,
                onBack: widget.onBack,
                onNavigateToHeader: _navigateToHeader,
                onGalleryTap: _openMediaGallery,
                onSearchTap: _openMessageSearch,
                isDark: isDark,
              ),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: EmbeddedMessageList(
                      messageStream:
                          _chatService.getMessages(widget.spaceId),
                      scrollController: _scrollController,
                      sendingMessages: _sendingMessages,
                      typingUsers: _typingUsers,
                      currentUserId: _currentUser?.uid,
                      isConnected: _isConnected,
                      isDMConversation: isDMConversation,
                      repliedMessagesCache: _repliedMessagesCache,
                      timestampRevealOffset: _timestampRevealOffset,
                      isDraggingReveal: _isDraggingReveal,
                      onMessagesUpdated: (allMessages) {
                        _allMessages = allMessages;
                        for (final msg in allMessages) {
                          _repliedMessagesCache[msg.id] = msg;
                        }
                      },
                      deduplicateMessages: deduplicateMessages,
                      onReply: startReply,
                      onQuickReact: quickReact,
                      onShowExactTime: showExactTime,
                      onScrollToMessage: _scrollToMessage,
                      onPointerDown: _onTimestampPointerDown,
                      onPointerMove: _onTimestampPointerMove,
                      onPointerUp: _onTimestampPointerUp,
                    ),
                  ),
                  if (!isDMConversation)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: ActiveCallBanner(
                        spaceId: widget.spaceId,
                        spaceName: widget.space?.name ?? 'Group Call',
                      ),
                    ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: SpaceChatInputArea(
                      key: ValueKey('chat_input_${widget.spaceId}'),
                      spaceId: widget.spaceId,
                      messageController: _messageController,
                      textFieldFocusNode: _textFieldFocusNode,
                      replyingTo: _replyingTo,
                      isDMConversation: isDMConversation,
                      namasteSentThisSession: _namasteSentThisSession,
                      onSendMessage: sendMessage,
                      onSendNamaste: sendNamaste,
                      onCancelReply: cancelReply,
                      onTextChanged: _onTextChanged,
                      onOptimisticVoiceMessage: addOptimisticVoiceMessage,
                      onVoiceMessageStatusUpdate: updateVoiceMessageStatus,
                    ),
                  ),
                  if (!_isAtBottom)
                    Positioned(
                      bottom: 140,
                      right: 16,
                      child: ScrollToBottomFAB(
                        onTap: () {
                          _scrollController.animateTo(_bottomScrollOffset,
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOut);
                        },
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
