import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:aurogram/services/chat/space_chat_service.dart';
import 'package:aurogram/services/user_service.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/utils/logging/app_logger.dart';
import 'package:aurogram/widgets/user_avatar.dart';

class ShareableContent {
  final String type;
  final String id;
  final String? title;
  final String? subtitle;
  final String? imageUrl;
  final String? authorName;
  final Map<String, dynamic>? extraData;

  ShareableContent({
    required this.type,
    required this.id,
    this.title,
    this.subtitle,
    this.imageUrl,
    this.authorName,
    this.extraData,
  });

  Map<String, dynamic> toJson() => {
        'type': type,
        'id': id,
        'title': title,
        'subtitle': subtitle,
        'imageUrl': imageUrl,
        'authorName': authorName,
        ...?extraData,
      };
}

class ChatPickerResult {
  final List<DmConversation> selectedConversations;
  final String? message;

  ChatPickerResult({
    required this.selectedConversations,
    this.message,
  });
}

class ChatPickerBottomSheet extends StatefulWidget {
  final ShareableContent content;
  final bool allowMultiSelect;
  final String? initialMessage;

  const ChatPickerBottomSheet({
    super.key,
    required this.content,
    this.allowMultiSelect = false,
    this.initialMessage,
  });

  static Future<ChatPickerResult?> show(
    BuildContext context, {
    required ShareableContent content,
    bool allowMultiSelect = false,
    String? initialMessage,
  }) {
    return showModalBottomSheet<ChatPickerResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      isDismissible: true,
      builder: (context) => ChatPickerBottomSheet(
        content: content,
        allowMultiSelect: allowMultiSelect,
        initialMessage: initialMessage,
      ),
    );
  }

  @override
  State<ChatPickerBottomSheet> createState() => _ChatPickerBottomSheetState();
}

class _ChatPickerBottomSheetState extends State<ChatPickerBottomSheet> {
  final SpaceChatService _chatService = SpaceChatService();
  final UserService _userService = UserService();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();

  final Set<String> _selectedIds = {};
  final Map<String, String> _userNameCache = {};

  String _searchQuery = '';
  List<DmConversation> _conversations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    final startTime = DateTime.now();
    AppLogger.i('📤 ChatPicker: initState started', category: LogCategory.ui);

    if (widget.initialMessage != null) {
      _messageController.text = widget.initialMessage!;
    }

    // Reset state completely for fresh load
    _selectedIds.clear();
    _userNameCache.clear();
    _searchQuery = '';
    _conversations = [];
    _isLoading = true;

    _loadConversations().then((_) {
      final duration = DateTime.now().difference(startTime);
      AppLogger.i('📤 ChatPicker: initState complete',
          category: LogCategory.ui,
          data: {'duration_ms': duration.inMilliseconds});
    });
  }

  Future<void> _loadConversations() async {
    final startTime = DateTime.now();
    AppLogger.i('📤 ChatPicker: _loadConversations START',
        category: LogCategory.ui);

    setState(() {
      _isLoading = true;
      _conversations = [];
    });

    try {
      final streamStartTime = DateTime.now();
      AppLogger.i('📤 ChatPicker: Getting stream...', category: LogCategory.ui);

      final stream = _chatService.getUserDmConversations();

      final streamDuration = DateTime.now().difference(streamStartTime);
      AppLogger.i('📤 ChatPicker: Stream obtained',
          category: LogCategory.ui,
          data: {'stream_ms': streamDuration.inMilliseconds});

      final waitStartTime = DateTime.now();
      AppLogger.i('📤 ChatPicker: Waiting for first emission...',
          category: LogCategory.ui);

      // For broadcast streams, we need to listen properly to get the first emission
      // The underlying Firestore stream emits immediately, but broadcast streams
      // don't replay past events. We use a listen pattern to ensure we get the emission.
      final completer = Completer<List<DmConversation>>();
      StreamSubscription<List<DmConversation>>? subscription;
      Timer? timeoutTimer;

      subscription = stream.listen(
        (conversations) {
          if (!completer.isCompleted) {
            timeoutTimer?.cancel();
            subscription?.cancel();
            completer.complete(conversations);
          }
        },
        onError: (error) {
          if (!completer.isCompleted) {
            timeoutTimer?.cancel();
            subscription?.cancel();
            completer.completeError(error);
          }
        },
        cancelOnError: false,
      );

      // Timeout after 10 seconds
      timeoutTimer = Timer(const Duration(seconds: 10), () {
        if (!completer.isCompleted) {
          subscription?.cancel();
          completer.completeError(
              TimeoutException('No stream event', const Duration(seconds: 10)));
        }
      });

      final conversations = await completer.future;

      final waitDuration = DateTime.now().difference(waitStartTime);
      AppLogger.i('📤 ChatPicker: Got conversations',
          category: LogCategory.ui,
          data: {
            'count': conversations.length,
            'wait_ms': waitDuration.inMilliseconds,
          });

      // Show conversations immediately, load names in background
      if (mounted) {
        setState(() {
          _conversations = conversations;
          _isLoading = false;
        });

        final totalDuration = DateTime.now().difference(startTime);
        AppLogger.i('📤 ChatPicker: Conversations shown',
            category: LogCategory.ui,
            data: {
              'total_ms': totalDuration.inMilliseconds,
              'conversations': conversations.length,
              'breakdown': {
                'stream_ms': streamDuration.inMilliseconds,
                'wait_ms': waitDuration.inMilliseconds,
              },
            });
      }

      // Load names in background (parallel, non-blocking)
      final namesStartTime = DateTime.now();
      _loadUserNames(conversations).then((_) {
        final namesDuration = DateTime.now().difference(namesStartTime);
        AppLogger.i('📤 ChatPicker: User names loaded (background)',
            category: LogCategory.ui,
            data: {'names_ms': namesDuration.inMilliseconds});

        if (mounted) {
          setState(() {}); // Trigger rebuild to show updated names
        }
      });
    } catch (e) {
      final totalDuration = DateTime.now().difference(startTime);
      AppLogger.e('📤 ChatPicker: _loadConversations ERROR',
          category: LogCategory.ui,
          error: e,
          data: {
            'total_ms': totalDuration.inMilliseconds,
            'error': e.toString(),
          });

      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadUserNames(List<DmConversation> conversations) async {
    final dmConversations =
        conversations.where((c) => c.id.startsWith('dm_')).toList();
    final toLoad = dmConversations
        .where((c) => !_userNameCache.containsKey(c.otherUserId))
        .toList();

    if (toLoad.isEmpty) {
      AppLogger.i('📤 ChatPicker: All names cached', category: LogCategory.ui);
      return;
    }

    AppLogger.i('📤 ChatPicker: Loading ${toLoad.length} user names (parallel)',
        category: LogCategory.ui);

    final startTime = DateTime.now();

    // Load all names in parallel
    final results = await Future.wait(
      toLoad.map((conversation) async {
        try {
          final name = await _userService
              .getUserDisplayName(conversation.otherUserId)
              .timeout(const Duration(seconds: 3));
          return MapEntry(conversation.otherUserId, name);
        } catch (e) {
          // Use fallback name from conversation
          return MapEntry(
            conversation.otherUserId,
            conversation.lastMessageSenderName ?? 'User',
          );
        }
      }),
      eagerError: false, // Don't fail fast, get all results
    );

    // Batch update cache
    if (mounted) {
      for (final entry in results) {
        _userNameCache[entry.key] = entry.value;
      }

      final duration = DateTime.now().difference(startTime);
      AppLogger.i('📤 ChatPicker: User names loaded (parallel)',
          category: LogCategory.ui,
          data: {
            'count': results.length,
            'ms': duration.inMilliseconds,
            'avg_ms': duration.inMilliseconds / results.length,
          });

      // Single UI update after all names loaded
      setState(() {});
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  List<DmConversation> get _filtered {
    if (_searchQuery.isEmpty) return _conversations;
    final q = _searchQuery.toLowerCase();
    return _conversations.where((c) {
      if (c.spaceName != null) return c.spaceName!.toLowerCase().contains(q);
      final name = _userNameCache[c.otherUserId] ??
          c.lastMessageSenderName ??
          c.otherUserId;
      return name.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final height = MediaQuery.of(context).size.height * 0.5;

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDarkColor : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          _buildHeader(isDark),
          _buildSearch(isDark),
          Expanded(child: _buildList(isDark)),
          if (_selectedIds.isNotEmpty) _buildBottomBar(isDark),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Text(
            'Share',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppTheme.primaryColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearch(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _searchQuery = v),
        decoration: InputDecoration(
          hintText: 'Search',
          prefixIcon: const Icon(Icons.search, size: 20),
          filled: true,
          fillColor:
              isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey[100],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildList(bool isDark) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final filtered = _filtered;
    if (filtered.isEmpty) {
      return Center(
        child: Text(
          _searchQuery.isEmpty ? 'No conversations' : 'No results',
          style: TextStyle(color: Colors.grey[600]),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: filtered.length,
      itemBuilder: (context, i) {
        final conv = filtered[i];
        final isDM = conv.id.startsWith('dm_');
        final name = isDM
            ? (_userNameCache[conv.otherUserId] ??
                conv.lastMessageSenderName ??
                'User')
            : (conv.spaceName ?? 'Chat');
        final selected = _selectedIds.contains(conv.id);

        return ListTile(
          leading: UserAvatar(
            userId: isDM ? conv.otherUserId : null,
            imageUrl: conv.displayPicture,
            size: 44,
            loadFromFirestore: isDM,
            nameInitials: name.isNotEmpty ? name[0].toUpperCase() : 'U',
          ),
          title: Text(name),
          trailing: widget.allowMultiSelect
              ? Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? AppTheme.primaryColor : Colors.grey,
                      width: 2,
                    ),
                    color:
                        selected ? AppTheme.primaryColor : Colors.transparent,
                  ),
                  child: selected
                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                      : null,
                )
              : null,
          onTap: () {
            HapticFeedback.selectionClick();
            if (widget.allowMultiSelect) {
              setState(() {
                if (selected) {
                  _selectedIds.remove(conv.id);
                } else {
                  _selectedIds.add(conv.id);
                }
              });
            } else {
              _selectedIds.add(conv.id);
              _handleSend();
            }
          },
        );
      },
    );
  }

  Widget _buildBottomBar(bool isDark) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDarkColor : Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey[300]!, width: 0.5),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _messageController,
            decoration: InputDecoration(
              hintText: 'Write a message...',
              filled: true,
              fillColor: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _handleSend,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                _selectedIds.length > 1
                    ? 'Send to ${_selectedIds.length}'
                    : 'Send',
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleSend() {
    if (_selectedIds.isEmpty) return;
    final selected =
        _conversations.where((c) => _selectedIds.contains(c.id)).toList();
    Navigator.pop(
      context,
      ChatPickerResult(
        selectedConversations: selected,
        message: _messageController.text.trim().isEmpty
            ? null
            : _messageController.text.trim(),
      ),
    );
  }
}
