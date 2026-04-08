import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:aurogram/services/chat/space_chat_service.dart';
import 'package:aurogram/pages/spaces/space_chat_screen.dart';
import 'package:aurogram/models/space.dart';
import 'package:aurogram/models/space_types.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/utils/theme/header_style.dart';
import 'package:aurogram/widgets/dialogs/login_bottom_sheet.dart';
import 'package:aurogram/utils/logging/app_logger.dart';
import 'package:aurogram/widgets/ui/skeleton_widgets.dart';
import 'package:aurogram/providers/ai_chat_provider.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:aurogram/services/search_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:aurogram/services/analytics_service.dart';
import 'package:aurogram/services/contact_service.dart';
import 'package:aurogram/services/user_service.dart';
import 'package:aurogram/services/namaste_service.dart';
import 'package:aurogram/models/contact_match.dart';
import 'package:aurogram/pages/tabs/widgets/message_skeletons.dart';
import 'package:aurogram/pages/tabs/widgets/messages_search_bar.dart';
import 'package:aurogram/utils/responsive.dart';
import 'package:aurogram/pages/tabs/messages/messages_all_sections.dart';
import 'package:aurogram/pages/tabs/messages/messages_desktop_layout.dart';
import 'package:aurogram/pages/tabs/messages/messages_request_widgets.dart';
import 'package:aurogram/pages/tabs/messages/messages_search_results.dart';
import 'package:aurogram/pages/tabs/messages/messages_contact_actions.dart';
import 'package:aurogram/pages/tabs/messages/messages_navigation.dart';
import 'package:aurogram/pages/tabs/messages/messages_stream_content.dart';
import 'package:aurogram/pages/tabs/messages/messages_search_helpers.dart';
import 'package:aurogram/widgets/common/snack_bar_service.dart';

/// Main Messages page that replaces the notifications tab
/// Shows Direct Messages with real-time updates
class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key});

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

enum _MessagesTab { chats, requests }

class _MessagesPageState extends State<MessagesPage>
    with AutomaticKeepAliveClientMixin {
  final SpaceChatService _chatService = SpaceChatService();
  final SearchService _searchService = SearchService();
  final ContactService _contactService = ContactService.instance;
  final UserService _userService = UserService();
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  // Track if we're in the middle of a refresh to prevent multiple rebuilds
  bool _isRefreshing = false;

  // Keep a stable stream instance across rebuilds to avoid losing last data
  late Stream<List<DmConversation>> _conversationsStream;

  // Search functionality
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  List<QueryDocumentSnapshot> _userSearchResults = [];
  bool _isSearchingUsers = false;
  Timer? _searchDebounceTimer;
  String? _lastSearchMetricsKey; // ignore: unused_field
  static const int _minSearchLength = 2;

  // Contact sync state
  ContactSyncResult? _contactResult;
  bool _isLoadingContacts = false;
  bool _hasRequestedContactPermission = false;
  int _contactsNotOnAppLimit = 20; // Pagination limit
  int _conversationsLimit = 50; // Pagination limit for conversations

  // Cache for user names to avoid repeated Firestore calls
  final Map<String, String> _userNameCache = {};
  final Map<String, Future<String>> _userNameFutures = {};

  // Track active user IDs from conversations for deduplication
  Set<String> _activeUserIds = {};

  // Track user IDs that have received namaste (for hiding the button with animation)
  final Set<String> _namastesSentThisSession = {};

  // Desktop master-detail state
  String? _selectedConversationId;
  Space? _selectedSpace;
  String? _selectedOtherUserId;

  int _chatCount = 0;
  List<DmConversation> _cachedConversations = const [];
  _MessagesTab _selectedTab = _MessagesTab.chats;

  /// Handle refresh action
  Future<void> _handleRefresh() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    await Future.delayed(Duration.zero);
    try {
      _chatService.clearConversationsCache();
      if (mounted) {
        setState(() {
          _namastesSentThisSession.clear();
          _conversationsStream = _chatService
              .getUserDmConversations()
              .handleError((error, stackTrace) {
            AppLogger.e('Stream error: $error',
                category: LogCategory.ui, error: error);
            return <DmConversation>[];
          });
        });
      }
      await Future.delayed(Duration(milliseconds: 500));
    } catch (e) {
      AppLogger.e('Error during refresh', category: LogCategory.general, error: e);
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  void _updateChatCount(int count) {
    if (count == _chatCount) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _chatCount = count;
      });
    });
  }

  @override
  void initState() {
    super.initState();

    // Initialize a stable stream once. Do not rebuild a new stream every build.
    _conversationsStream =
        _chatService.getUserDmConversations().handleError((error, stackTrace) {
      AppLogger.e('🔥 STREAM ERROR: $error',
          category: LogCategory.ui, error: error);
      AppLogger.e('🔥 STACK TRACE: $stackTrace', category: LogCategory.ui);
      // Return empty list on error to prevent UI hanging
      return <DmConversation>[];
    });

    // Load contacts if cached, otherwise wait for user action
    _loadCachedContacts();
  }

  /// Load cached contacts from local storage (no permission prompt)
  Future<void> _loadCachedContacts() async {
    // Ensure current user's phone is indexed (backfill)
    await _userService.ensurePhoneIndexed();

    // Initialize service to load from storage
    await _contactService.initialize();

    final cached = _contactService.cachedResult;
    if (cached != null && cached.hasPermission && mounted) {
      setState(() => _contactResult = cached);
    }
  }

  /// Sync contacts with permission check
  Future<void> _syncContacts(
      {bool forceRefresh = false, bool showPermissionDialog = true}) async {
    if (_isLoadingContacts) return;

    await syncContactsWithUI(
      context: context,
      contactService: _contactService,
      hasRequestedPermission: _hasRequestedContactPermission,
      showPermissionDialog: showPermissionDialog,
      isMounted: () => mounted,
      setLoading: (loading) {
        if (mounted) setState(() => _isLoadingContacts = loading);
      },
      onResult: (ContactSyncResult result, bool hasRequested) {
        if (mounted) {
          setState(() {
            _contactResult = result;
            _isLoadingContacts = false;
            _hasRequestedContactPermission = hasRequested;
          });
        }
      },
      forceRefresh: forceRefresh,
    );
  }

  @override
  void dispose() {
    // Clear the stream cache when the page is disposed
    _chatService.clearConversationsCache();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _searchDebounceTimer?.cancel();
    super.dispose();
  }

  Future<String> _getUserName(String userId) async {
    if (_userNameCache.containsKey(userId)) return _userNameCache[userId]!;
    if (_userNameFutures.containsKey(userId)) return _userNameFutures[userId]!;
    final future = _userService
        .getUserDisplayName(userId, cachedName: _userNameCache[userId])
        .catchError((_) => 'User');
    _userNameFutures[userId] = future;
    final name = await future;
    _userNameFutures.remove(userId);
    _userNameCache[userId] = name;
    return name;
  }

  bool _areSameUserResults(
      List<QueryDocumentSnapshot> current, List<QueryDocumentSnapshot> next) {
    if (current.length != next.length) return false;
    for (int i = 0; i < current.length; i++) {
      if (current[i].id != next[i].id) return false;
    }
    return true;
  }

  Widget _buildUserNameWidget(String userId) {
    return buildUserNameText(
      userId: userId,
      userNameCache: _userNameCache,
      getUserName: _getUserName,
    );
  }

  void _openConversation(DmConversation conversation) async {
    await openConversation(
      context: context,
      conversation: conversation,
      onDesktopSelect: (id, space, otherUserId) {
        setState(() {
          _selectedConversationId = id;
          _selectedSpace = space;
          _selectedOtherUserId = otherUserId;
        });
      },
    );
  }

  void _openProfile(String userId) {
    openProfile(context, userId);
  }

  Future<void> _inviteContact(ContactMatch contact) async {
    HapticFeedback.lightImpact();

    try {
      final result = await SharePlus.instance.share(
        ShareParams(
          text: '🙏 Namaste! Join me on Aurogram for cosmic insights.\n\nhttps://aurogram.in',
          subject: 'Join me on Aurogram',
        ),
      );

      if (result.status == ShareResultStatus.success ||
          result.status == ShareResultStatus.dismissed) {
        await _contactService.removeFromNotOnApp(contact.phoneHash);

        if (mounted) {
          HapticFeedback.mediumImpact();
          setState(() {
            _contactResult = _contactService.cachedResult;
          });
        }
      }

      AnalyticsService().trackInviteSent(method: 'contact_invite');
    } catch (e) {
      AppLogger.e('Error inviting contact', category: LogCategory.ui, error: e);
    }
  }

  void _showNamasteError(NamasteResult result) {
    String message;
    if (result.quotaExceeded) {
      message = 'Daily limit reached. You can send 3 namastes per day.';
    } else if (result.alreadySentToday) {
      message = 'Already sent namaste to this person today.';
    } else if (result.blocked) {
      message = 'Unable to send namaste to this user.';
    } else {
      message = 'Failed to send Namaste. Please try again.';
    }

    showCustomSnackBar(context, message: message, behavior: SnackBarBehavior.floating, backgroundColor: result.quotaExceeded || result.alreadySentToday
            ? AppTheme.primaryColor
            : AppTheme.errorColor);
  }

  Future<void> _sendNamasteToContact(ContactMatch contact) async {
    if (contact.userId == null) return;
    await _sendNamasteCore(contact.userId!, contactPhoneHash: contact.phoneHash);
  }

  Future<void> _sendNamasteToUser(String userId) async {
    await _sendNamasteCore(userId);
  }

  Future<void> _sendNamasteCore(String userId, {String? contactPhoneHash}) async {
    final dmId = await _chatService.createDirectMessage(userId);
    final result = await NamasteService().sendNamaste(userId, dmId: dmId);
    if (!mounted) return;
    if (result.success) {
      if (contactPhoneHash != null) {
        await _contactService.removeFromOnApp(contactPhoneHash);
      }
      setState(() {
        _namastesSentThisSession.add(userId);
        if (contactPhoneHash != null) _contactResult = _contactService.cachedResult;
      });
      final points = result.senderPointsAwarded ?? 0;
      if (points > 0 && mounted) {
        showCustomSnackBar(context, message: '+$points Auro for sending Namaste!', behavior: SnackBarBehavior.floating, backgroundColor: AppTheme.primaryColor);
      }
    } else {
      _showNamasteError(result);
    }
  }

  void _handleCardTap({
    DmConversation? conversation,
    ContactMatch? contact,
    bool isInvite = false,
  }) {
    if (conversation != null) {
      _openConversation(conversation);
    } else if (contact != null && !isInvite && contact.userId != null) {
      _openProfile(contact.userId!);
    } else if (contact != null && isInvite) {
      _inviteContact(contact);
    }
  }

  void _handleShowMore(String type) {
    HapticFeedback.lightImpact();
    setState(() {
      if (type == 'contacts') {
        _contactsNotOnAppLimit += 20;
      } else if (type == 'conversations') {
        _conversationsLimit += 50;
      }
    });
  }

  Widget _buildSearchResults(List<DmConversation> conversations) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MessagesSearchResultsView(
      conversations: conversations,
      userSearchResults: _userSearchResults,
      isSearchingUsers: _isSearchingUsers,
      searchQuery: _searchQuery,
      contactResult: _contactResult,
      isDark: isDark,
      namastesSentThisSession: _namastesSentThisSession,
      onCardTap: _handleCardTap,
      onSendNamaste: _sendNamasteToUser,
      onSendNamasteToContact: _sendNamasteToContact,
      onInviteContact: _inviteContact,
      buildUserNameWidget: _buildUserNameWidget,
      onStartConversation: _startConversationWithUser,
    );
  }

  Widget _buildAllSections(List<DmConversation> conversations) {
    return MessagesAllSections(
      conversations: conversations,
      contactResult: _contactResult,
      hasRequestedContactPermission: _hasRequestedContactPermission,
      activeUserIds: _activeUserIds,
      namastesSentThisSession: _namastesSentThisSession,
      conversationsLimit: _conversationsLimit,
      contactsNotOnAppLimit: _contactsNotOnAppLimit,
      isLoadingContacts: _isLoadingContacts,
      onCardTap: _handleCardTap,
      onSendNamaste: _sendNamasteToUser,
      onSendNamasteToContact: _sendNamasteToContact,
      onInviteContact: _inviteContact,
      buildUserNameWidget: _buildUserNameWidget,
      onSyncContacts: _syncContacts,
      onShowMore: _handleShowMore,
    );
  }

  /// Filter out AI conversations from the list
  List<DmConversation> _filterAiConversations(
      List<DmConversation> conversations) {
    return conversations.where((c) =>
      c.otherUserId != HOLYCOW_USER_ID &&
      !c.id.startsWith('ai_chat_') &&
      !c.id.contains('holycow_system_user')
    ).toList();
  }

  Widget _buildMessagesList() {
    // Smooth crossfade transition between skeleton and content
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      reverseDuration: const Duration(milliseconds: 300),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOut,
          ),
          child: child,
        );
      },
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          alignment: Alignment.topCenter,
          children: [
            ...previousChildren,
            if (currentChild != null) currentChild,
          ],
        );
      },
      child: _isRefreshing
          ? MessageSkeletons(key: const ValueKey('skeleton'))
          : _buildActualContent(key: const ValueKey('content')),
    );
  }

  /// Build desktop master-detail layout with conversation list on left and chat on right
  Widget _buildDesktopLayout() {
    return MessagesDesktopLayout(
      messagesListWidget: _buildMessagesList(),
      selectedConversationId: _selectedConversationId,
      selectedSpace: _selectedSpace,
      selectedOtherUserId: _selectedOtherUserId,
      isRefreshing: _isRefreshing,
      onRefresh: _handleRefresh,
      searchController: _searchController,
      searchFocusNode: _searchFocusNode,
      onSearchChanged: _onSearchChanged,
    );
  }

  Widget _buildActualContent({Key? key}) {
    return StreamBuilder<List<DmConversation>>(
      key: key,
      stream: _conversationsStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          AppLogger.e('Messages StreamBuilder error',
              category: LogCategory.ui, error: snapshot.error);
          return MessagesStreamErrorState(
            error: snapshot.error,
            isRefreshing: _isRefreshing,
            onRetry: _handleRefresh,
          );
        }

        // Show loading state only on initial load
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData && _cachedConversations.isEmpty) {
          return MessageSkeletons(key: const ValueKey('loading'));
        }

        // Update cache when fresh data arrives
        var conversations = snapshot.data ?? _cachedConversations;
        if (snapshot.hasData) _cachedConversations = snapshot.data ?? [];

        // Filter AI conversations and pending requests
        conversations = _filterAiConversations(conversations);
        conversations = conversations.where((c) =>
          c.status != 'pending' || c.requestedBy == _currentUser?.uid
        ).toList();
        _updateChatCount(conversations.length);

        // Update active user IDs for deduplication
        _activeUserIds = conversations
            .where((c) => c.id.startsWith('dm_'))
            .map((c) => c.otherUserId)
            .toSet();

        // Batch prefetch user names (non-blocking)
        _prefetchUserNames(conversations);

        // If no search query, show all sections
        if (_searchQuery.trim().isEmpty) {
          return _buildAllSections(conversations);
        }

        // Use FutureBuilder for async search filtering
        return FutureBuilder<List<DmConversation>>(
          future: _filterBySearch(conversations, _searchQuery),
          builder: (context, filterSnapshot) {
            if (filterSnapshot.connectionState == ConnectionState.waiting) {
              return Column(
                children: List.generate(4, (_) => SkeletonListItem()),
              );
            }

            final filteredConversations = filterSnapshot.data ?? conversations;
            return _buildSearchResults(filteredConversations);
          },
        );
      },
    );
  }

  /// Batch prefetch user names for all conversations
  Future<void> _prefetchUserNames(List<DmConversation> conversations) async {
    await prefetchUserNames(conversations, _userNameCache);
  }

  /// Filter conversations based on search query
  Future<List<DmConversation>> _filterBySearch(
      List<DmConversation> conversations, String query) async {
    return filterConversationsBySearch(conversations, query, _getUserName);
  }

  void _onSearchChanged(String query) {
    if (query == _searchQuery) return;
    setState(() => _searchQuery = query);
    _searchDebounceTimer?.cancel();
    final trimmed = query.trim();
    if (trimmed.length >= _minSearchLength) {
      _searchDebounceTimer = Timer(const Duration(milliseconds: 300), () {
        if (mounted && _searchQuery == query) _searchUsers(trimmed);
      });
    } else if (_userSearchResults.isNotEmpty || _isSearchingUsers) {
      setState(() { _userSearchResults = []; _isSearchingUsers = false; });
    }
  }

  Future<void> _searchUsers(String query) async {
    if (!_isSearchingUsers && query.trim().length >= _minSearchLength) {
      setState(() => _isSearchingUsers = true);
    }
    await searchUsersInFirestore(
      query: query,
      minSearchLength: _minSearchLength,
      currentSearchQuery: _searchQuery,
      searchService: _searchService,
      isMounted: () => mounted,
      currentResults: _userSearchResults,
      areSameResults: _areSameUserResults,
      onResultsUpdated: ({required results, required isSearching}) {
        if (mounted) {
          setState(() {
            _userSearchResults = results;
            _isSearchingUsers = isSearching;
          });
        }
      },
    );
  }

  Future<void> _startConversationWithUser(
      String userId, String userName) async {
    await startConversationWithUser(
      context: context,
      userId: userId,
      userName: userName,
      currentUserId: _currentUser?.uid,
      chatService: _chatService,
      searchController: _searchController,
      searchFocusNode: _searchFocusNode,
      onSearchChanged: _onSearchChanged,
      onDesktopSelect: (id, space, otherUserId) {
        setState(() {
          _selectedConversationId = id;
          _selectedSpace = space;
          _selectedOtherUserId = otherUserId;
        });
      },
    );
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final bool isWideLayout = Responsive.isWideLayout(context);
    // Hide header in wide layout (sidebar handles navigation)
    final bool hideHeader = isWideLayout;

    if (_currentUser == null) {
      return Scaffold(
        extendBody: true,
        backgroundColor: Colors.transparent,
        appBar: hideHeader
            ? null
            : AppHeaderStyle.buildStandardAppBar(
                context: context,
                title: "messages",
              ),
        body: MessagesNotLoggedInState(
          onLogin: () => showLoginBottomSheet(context),
        ),
      );
    }

    final showSearch = _selectedTab == _MessagesTab.chats && !isWideLayout;
    if (isWideLayout && _selectedTab == _MessagesTab.chats) {
      return Scaffold(
        extendBody: true,
        backgroundColor: Colors.transparent,
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: _buildTabChips(),
            ),
            Expanded(child: _buildDesktopLayout()),
          ],
        ),
      );
    }

    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        onTap: () {
          _searchFocusNode.unfocus();
        },
        child: Stack(
          children: [
            CustomScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                AppHeaderStyle.buildStandardHeader(
                  context: context,
                  title: "messages",
                  leadingWidget: const SizedBox.shrink(),
                  showSearchField: false,
                  backgroundStyle: HeaderBackgroundStyle.gradient,
                  isRefreshing: _isRefreshing,
                ),
                if (_selectedTab == _MessagesTab.chats)
                  CupertinoSliverRefreshControl(
                    onRefresh: _handleRefresh,
                    builder: (context, refreshState, pulledExtent,
                        refreshTriggerPullDistance, refreshIndicatorExtent) {
                      return const SizedBox.shrink();
                    },
                  ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  sliver: SliverToBoxAdapter(
                    child: _buildTabChips(),
                  ),
                ),
                if (_selectedTab == _MessagesTab.chats) ...[
                  SliverToBoxAdapter(child: _buildMessagesList()),
                  const SliverToBoxAdapter(child: SizedBox(height: 120)),
                ] else ...[
                  _buildMessageRequestsSliver(),
                  const SliverToBoxAdapter(child: SizedBox(height: 120)),
                ],
              ],
            ),
            if (showSearch)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: MessagesSearchBar(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  onSearchChanged: _onSearchChanged,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabChips() {
    return StreamBuilder<List<DmConversation>>(
      stream: _chatService.getUserDmConversations(),
      builder: (context, snapshot) {
        final conversations = snapshot.data ?? [];
        final pendingCount = conversations.where((c) =>
          c.status == 'pending' &&
          c.requestedBy != _currentUser?.uid
        ).length;
        return MessagesTabChips(
          selectedIndex: _selectedTab == _MessagesTab.chats ? 0 : 1,
          chatCount: _chatCount,
          pendingCount: pendingCount,
          onTabChanged: (index) => _setTab(
            index == 0 ? _MessagesTab.chats : _MessagesTab.requests,
          ),
        );
      },
    );
  }

  void _setTab(_MessagesTab tab) {
    if (_selectedTab == tab) return;
    setState(() {
      _selectedTab = tab;
    });
  }

  SliverToBoxAdapter _buildMessageRequestsSliver() {
    return SliverToBoxAdapter(
      child: MessagesRequestsSliverContent(
        conversationsStream: _chatService.getUserDmConversations(),
        currentUserId: _currentUser?.uid,
        cachedConversations: _cachedConversations,
        onAccept: _acceptRequestInline,
        onDecline: _declineRequestInline,
      ),
    );
  }

  Future<void> _acceptRequestInline(DmConversation request) async {
    final space = Space(
      id: request.id,
      name: request.spaceName ?? request.otherUserId,
      searchName: 'dm_${request.otherUserId}',
      description: 'Direct message conversation',
      spaceType: SpaceType.private,
      limitedVisibility: false,
    );

    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => SpaceChatScreen(
          spaceId: request.id,
          space: space,
          otherUserId: request.otherUserId,
        ),
      ),
    );
  }

  Future<void> _declineRequestInline(String conversationId) async {
    final success = await _chatService.declineMessageRequest(conversationId);
    if (!mounted) return;

    if (success) {
      showCustomSnackBar(context, message: 'Message request declined', backgroundColor: AppTheme.primaryColor, duration: const Duration(seconds: 2));
    } else {
      showCustomSnackBar(context, message: 'Failed to decline request', backgroundColor: AppTheme.errorColor);
    }
  }
}
