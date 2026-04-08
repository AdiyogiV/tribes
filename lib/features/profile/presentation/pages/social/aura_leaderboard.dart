import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:aurogram/shared/presentation/widgets/media/common_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:aurogram/features/profile/domain/aura_service.dart';
import 'package:aurogram/shared/presentation/widgets/avatars/user_avatar.dart';
import 'package:aurogram/shared/presentation/widgets/loaders/skeleton_widgets.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/widgets/universal/transparent_toolbox.dart';
import 'package:aurogram/features/profile/presentation/pages/user_profile.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

/// Leaderboard page showing top users by aura score
class AuraLeaderboardPage extends StatefulWidget {
  const AuraLeaderboardPage({super.key});

  @override
  State<AuraLeaderboardPage> createState() => _AuraLeaderboardPageState();
}

enum _AuroboardTab { leaderboard, scoreDetails }

class _AuraLeaderboardPageState extends State<AuraLeaderboardPage> {
  final AuraService _auraService = AuraService();
  List<Map<String, dynamic>> _leaderboard = [];
  bool _isLoading = true;
  int? _currentUserRank;
  int? _currentUserScore;
  final _currentUser = FirebaseAuth.instance.currentUser;

  _AuroboardTab _selectedTab = _AuroboardTab.leaderboard;
  Future<List<Map<String, dynamic>>>? _scoreHistoryFuture;

  @override
  void initState() {
    super.initState();
    _loadLeaderboard();
    if (_currentUser?.uid != null) {
      _scoreHistoryFuture =
          _auraService.getUserAuraHistory(_currentUser!.uid, limit: 100);
    }
  }

  Future<void> _loadLeaderboard() async {
    setState(() => _isLoading = true);

    try {
      final leaderboard = await _auraService.getLeaderboard(limit: 100);

      if (_currentUser?.uid != null) {
        final rank = await _auraService.getUserRank(_currentUser!.uid);
        final score = await _auraService.getUserAuraScore(_currentUser!.uid);
        if (mounted) {
          setState(() {
            _currentUserRank = rank;
            _currentUserScore = score;
          });
        }
      }

      if (mounted) {
        setState(() {
          _leaderboard = leaderboard;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshScoreHistory() async {
    if (_currentUser?.uid == null) return;
    final future =
        _auraService.getUserAuraHistory(_currentUser!.uid, limit: 100);
    final result = await future;
    if (!mounted) return;
    setState(() {
      _scoreHistoryFuture = Future.value(result);
    });
  }

  void _showAuroScoreInfo(Color primaryColor, bool isDark) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingXxl),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          decoration: BoxDecoration(
            color: isDark
                ? AppTheme.scaffoldDarkColor
                : AppTheme.scaffoldLightColor,
            borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
            border: Border.all(
              color: primaryColor.withValues(alpha: 0.2),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        'What is Auro score?',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: primaryColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: Icon(Icons.close, color: primaryColor, size: 22),
                        onPressed: () => Navigator.of(context).pop(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimensions.spacingMd),
                  Text(
                    'Your Auro score is a number that grows when you participate and connect. '
                    'It reflects how active you are and how others engage with you.',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: primaryColor.withValues(alpha: 0.85),
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spacingXl),
                  Text(
                    'How you earn points',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: primaryColor.withValues(alpha: 0.7),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spacingMdSm),
                  _infoRow(
                      primaryColor, 'Complete your profile', '20 (one-time)'),
                  _infoRow(primaryColor, 'Set up astrology', '10 (one-time)'),
                  _infoRow(primaryColor, 'Someone replies to your post', '10'),
                  _infoRow(primaryColor, 'Someone sends you Namaste', '5'),
                  _infoRow(primaryColor, 'New follower', '5'),
                  _infoRow(primaryColor, 'Someone likes your post', '3'),
                  _infoRow(primaryColor, 'You create a post', '2'),
                  _infoRow(primaryColor, 'You send Namaste', '1 (up to 3/day)'),
                  _infoRow(primaryColor, 'You reply to a post', '1'),
                  _infoRow(primaryColor, 'View daily insight', '1 (once/day)'),
                  const SizedBox(height: AppDimensions.spacingSm),
                  Text(
                    'Tap Your score to see your full history.',
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: primaryColor.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoRow(Color primaryColor, String label, String points) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.paddingSm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '• ',
            style: TextStyle(
              fontSize: 14,
              color: primaryColor.withValues(alpha: 0.6),
            ),
          ),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: primaryColor.withValues(alpha: 0.85),
              ),
            ),
          ),
          Text(
            points.startsWith('-') ? points : '+$points',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color:
                  points.startsWith('-') ? primaryColor : AppTheme.grassGreen,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = AppTheme.primaryColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // App bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.arrow_back_ios,
                      color: primaryColor,
                      size: 20,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text(
                      'auroboard',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: primaryColor,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.info_outline_rounded,
                      color: primaryColor,
                      size: 22,
                    ),
                    onPressed: () => _showAuroScoreInfo(primaryColor, isDark),
                  ),
                ],
              ),
            ),

            // Tab selector (only when current user – Your score is personal)
            if (_currentUser != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: _buildTabSelector(primaryColor, isDark),
              ),

            // Selected page content
            Expanded(
              child: IndexedStack(
                index: _selectedTab.index,
                children: [
                  _buildLeaderboardPage(primaryColor),
                  _buildScoreDetailsPage(primaryColor),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabSelector(Color primaryColor, bool isDark) {
    final isCurrentUser = _currentUser != null;
    return Container(
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      ),
      padding: const EdgeInsets.all(AppDimensions.paddingXs),
      child: Row(
        children: [
          Expanded(
            child: _TabSegment(
              label: 'Leaderboard',
              isSelected: _selectedTab == _AuroboardTab.leaderboard,
              primaryColor: primaryColor,
              isDark: isDark,
              onTap: () =>
                  setState(() => _selectedTab = _AuroboardTab.leaderboard),
            ),
          ),
          if (isCurrentUser)
            Expanded(
              child: _TabSegment(
                label: 'Your score',
                isSelected: _selectedTab == _AuroboardTab.scoreDetails,
                primaryColor: primaryColor,
                isDark: isDark,
                onTap: () =>
                    setState(() => _selectedTab = _AuroboardTab.scoreDetails),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardPage(Color primaryColor) {
    return RefreshIndicator(
      onRefresh: _loadLeaderboard,
      color: primaryColor,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            sliver: _isLoading
                ? _buildLoadingSliver()
                : _buildLeaderboardSliver(primaryColor),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreDetailsPage(Color primaryColor) {
    if (_currentUser == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingXxl),
          child: Text(
            'Sign in to see how you earned your score',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: primaryColor.withValues(alpha: 0.6),
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshScoreHistory,
      color: primaryColor,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _scoreHistoryFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return AppLoadingIndicator(
              size: 28,
              strokeWidth: 2,
              color: primaryColor.withValues(alpha: 0.6),
            );
          }

          final history = snapshot.data ?? [];
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final totalScore = _currentUserScore ?? 0;
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            children: [
              _buildTotalScoreHeader(primaryColor, isDark, totalScore),
              const SizedBox(height: AppDimensions.spacingLg),
              if (history.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Text(
                      'No score history yet',
                      style: TextStyle(
                        fontSize: 15,
                        color: primaryColor.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                )
              else
                ...history.map<Widget>((entry) => Padding(
                      padding: const EdgeInsets.only(bottom: AppDimensions.paddingSm),
                      child: _buildScoreHistoryCard(
                        entry,
                        primaryColor,
                        isDark,
                      ),
                    )),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTotalScoreHeader(
      Color primaryColor, bool isDark, int totalScore) {
    return TransparentToolbox.buildCard(
      context: context,
      onTap: null,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.bolt,
              color: primaryColor,
              size: 28,
            ),
          ),
          const SizedBox(width: AppDimensions.spacingLg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Total score',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? AppTheme.textSecondaryDarkColor
                        : AppTheme.textSecondaryLightColor,
                  ),
                ),
                const SizedBox(height: AppDimensions.spacingXxs),
                Text(
                  totalScore.toString(),
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: primaryColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreHistoryCard(
    Map<String, dynamic> entry,
    Color primaryColor,
    bool isDark,
  ) {
    final points = (entry['points'] as num?)?.toInt() ?? 0;
    final reason = entry['reason'] as String? ?? '—';
    final timestamp = entry['timestamp'];
    DateTime? date;
    if (timestamp is Timestamp) {
      date = timestamp.toDate();
    }
    final dateStr =
        date != null ? DateFormat.yMMMd().add_jm().format(date) : '—';

    final isPositive = points >= 0;
    final pointsColor =
        isPositive ? AppTheme.grassGreen : AppTheme.primaryColor;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.paddingSm),
      child: TransparentToolbox.buildCard(
        context: context,
        onTap: null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    reason,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: primaryColor,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spacingXs),
                  Text(
                    dateStr,
                    style: TextStyle(
                      fontSize: 12,
                      color: primaryColor.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppDimensions.spacingMd),
            Text(
              '${isPositive ? '+' : ''}$points',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: pointsColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingSliver() {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (_, __) => const Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: SkeletonListItem(height: 64),
        ),
        childCount: 8,
      ),
    );
  }

  SliverList _buildLeaderboardSliver(Color primaryColor) {
    final items = <Widget>[];

    if (_currentUser != null && _currentUserRank != null) {
      items.add(_buildYourRankCard(primaryColor));
      items.add(const SizedBox(height: AppDimensions.spacingLg));
    }

    if (_leaderboard.isEmpty) {
      items.add(_buildEmptyState(primaryColor));
    } else {
      items.add(_buildColumnHeaders(primaryColor));
      items.add(const SizedBox(height: AppDimensions.spacingSm));
      for (int i = 0; i < _leaderboard.length; i++) {
        items.add(_buildLeaderboardRow(i, primaryColor));
      }
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) => items[index],
        childCount: items.length,
      ),
    );
  }

  /// Column headers - shown once at top in a card
  Widget _buildColumnHeaders(Color primaryColor) {
    return TransparentToolbox.buildCard(
      context: context,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // Rank header
          SizedBox(
            width: 36,
            child: Text(
              'Rank',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: primaryColor.withValues(alpha: 0.6),
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: AppDimensions.spacingMd),

          // Avatar space + Name header
          const SizedBox(width: 44 + 14), // avatar size + spacing
          Expanded(
            child: Text(
              'Name',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: primaryColor.withValues(alpha: 0.6),
                letterSpacing: 0.5,
              ),
            ),
          ),

          // Score header
          Text(
            'Score',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: primaryColor.withValues(alpha: 0.6),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  /// Your rank card - same style as other cards
  Widget _buildYourRankCard(Color primaryColor) {
    return TransparentToolbox.buildCard(
      context: context,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label
          Text(
            'YOUR POSITION',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: primaryColor.withValues(alpha: 0.5),
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingMd),

          // Stats row
          Row(
            children: [
              // Rank
              Expanded(
                child: Row(
                  children: [
                    Text(
                      'Rank',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: primaryColor.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(width: AppDimensions.spacingMd),
                    Text(
                      '$_currentUserRank',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),
              ),

              // Score
              Row(
                children: [
                  Text(
                    'Score',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: primaryColor.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(width: AppDimensions.spacingMd),
                  Text(
                    '${_currentUserScore ?? 0}',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: primaryColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Leaderboard row item - no labels, just values
  Widget _buildLeaderboardRow(int index, Color primaryColor) {
    final user = _leaderboard[index];
    final rank = index + 1;
    final score = user['auraScore'] as int? ?? 0;
    final isMe = user['userId'] == _currentUser?.uid;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Highlight color for current user - golden yellow
    final highlightColor = AppTheme.sunGold;

    final cardContent = Row(
      children: [
        // Rank
        SizedBox(
          width: 36,
          child: Text(
            '$rank',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color:
                  isMe ? highlightColor : primaryColor.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(width: AppDimensions.spacingMd),

        // Avatar
        UserAvatar(
          userId: user['userId'],
          imageUrl: user['displayPicture'],
          size: 44,
          nameInitials:
              (user['name'] ?? '').isNotEmpty ? user['name'][0] : null,
          borderRadius: BorderRadius.circular(22),
        ),
        const SizedBox(width: AppDimensions.spacingMdLg),

        // Name
        Expanded(
          child: Text(
            user['name'] ?? '—',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isMe ? highlightColor : primaryColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: AppDimensions.spacingMd),

        // Score
        Text(
          '$score',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: isMe ? highlightColor : primaryColor.withValues(alpha: 0.7),
          ),
        ),
      ],
    );

    // Use custom highlighted card for current user
    if (isMe) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppDimensions.paddingSm),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingLg, vertical: AppDimensions.paddingMd),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                highlightColor.withValues(alpha: isDark ? 0.2 : 0.15),
                highlightColor.withValues(alpha: isDark ? 0.1 : 0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
            border: Border.all(
              color: highlightColor.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
              onTap: () => Navigator.of(context, rootNavigator: true).push(
                CupertinoPageRoute(
                  builder: (_) => UserProfilePage(uid: user['userId']),
                ),
              ),
              child: cardContent,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.paddingSm),
      child: TransparentToolbox.buildCard(
        context: context,
        padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingLg, vertical: AppDimensions.paddingMd),
        onTap: () => Navigator.of(context, rootNavigator: true).push(
          CupertinoPageRoute(
            builder: (_) => UserProfilePage(uid: user['userId']),
          ),
        ),
        child: cardContent,
      ),
    );
  }

  Widget _buildEmptyState(Color primaryColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 100),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'No rankings yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: primaryColor.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: AppDimensions.spacingSm),
            Text(
              'Start earning aura to see your rank',
              style: TextStyle(
                fontSize: 13,
                color: primaryColor.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Segment for the tab selector: one of "Leaderboard" or "Your score"
class _TabSegment extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color primaryColor;
  final bool isDark;
  final VoidCallback onTap;

  const _TabSegment({
    required this.label,
    required this.isSelected,
    required this.primaryColor,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMdSm),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? primaryColor.withValues(alpha: isDark ? 0.22 : 0.14)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppDimensions.radiusMdSm),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? primaryColor
                    : primaryColor.withValues(alpha: 0.6),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
