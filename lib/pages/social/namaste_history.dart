import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/utils/logging/app_logger.dart';
import 'package:aurogram/widgets/common/user_avatar.dart';
import 'package:aurogram/widgets/ui/skeleton_widgets.dart';
import 'package:aurogram/pages/tabs/user_profile.dart';
import 'package:aurogram/services/search_service.dart';
import 'package:intl/intl.dart';
import 'package:aurogram/utils/theme/app_dimensions.dart';

class NamasteHistoryPage extends StatefulWidget {
  const NamasteHistoryPage({super.key});

  @override
  State<NamasteHistoryPage> createState() => _NamasteHistoryPageState();
}

class _NamasteHistoryPageState extends State<NamasteHistoryPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  User? get _currentUser => _auth.currentUser;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppTheme.scaffoldDarkColor : AppTheme.scaffoldLightColor,
      body: CustomScrollView(
        slivers: [
          // Custom App Bar with gradient
          SliverAppBar(
            backgroundColor:
                isDark ? AppTheme.scaffoldDarkColor : AppTheme.scaffoldLightColor,
            elevation: 0,
            pinned: true,
            leading: IconButton(
              icon: Container(
                padding: EdgeInsets.all(AppDimensions.paddingSm),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.white.withValues(alpha: 0.8),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_back_ios_new,
                  color: AppTheme.primaryColor,
                  size: 16,
                ),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/icons/namaste.png',
                  width: 28,
                  height: 28,
                  filterQuality: FilterQuality.high,
                ),
                SizedBox(width: AppDimensions.spacingMd),
                Text(
                  'Namastes',
                  style: TextStyle(
                    color: AppTheme.primaryColor,
                    fontSize: AppTheme.holyCowTextSize,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
            centerTitle: true,
            bottom: PreferredSize(
              preferredSize: Size.fromHeight(100),
              child: Column(
                children: [
                  // Custom Tab Bar
                  Container(
                    margin: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                      boxShadow: isDark
                          ? []
                          : [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 10,
                                offset: Offset(0, 2),
                              ),
                            ],
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicator: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppDimensions.radiusMdLg),
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.primaryColor,
                            AppTheme.primaryColor.withValues(alpha: 0.8),
                          ],
                        ),
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      labelColor: Colors.white,
                      unselectedLabelColor: isDark
                          ? AppTheme.textSecondaryDarkColor
                          : AppTheme.textSecondaryLightColor,
                      labelStyle: TextStyle(
                        fontSize: AppTheme.holyCowTextSize,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                      unselectedLabelStyle: TextStyle(
                        fontSize: AppTheme.holyCowTextSize,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.3,
                      ),
                      tabs: [
                        Tab(text: 'Sent'),
                        Tab(text: 'Received'),
                      ],
                    ),
                  ),
                  // Search bar
                  Container(
                    margin: EdgeInsets.fromLTRB(20, 8, 20, 16),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
                      boxShadow: isDark
                          ? []
                          : [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 10,
                                offset: Offset(0, 2),
                              ),
                            ],
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.grey.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value.trim();
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Search by name...',
                        hintStyle: TextStyle(
                          color: isDark
                              ? AppTheme.textSecondaryDarkColor
                              : AppTheme.textSecondaryLightColor,
                          fontSize: AppTheme.holyCowTextSize,
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: AppTheme.primaryColor.withValues(alpha: 0.7),
                          size: 22,
                        ),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: Icon(
                                  Icons.clear_rounded,
                                  color: isDark
                                      ? AppTheme.textSecondaryDarkColor
                                      : AppTheme.textSecondaryLightColor,
                                  size: 20,
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _searchQuery = '';
                                  });
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      ),
                      style: TextStyle(
                        color:
                            isDark ? AppTheme.textDarkColor : AppTheme.textLightColor,
                        fontSize: AppTheme.holyCowTextSize,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Tab content
          SliverFillRemaining(
            hasScrollBody: true,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSentNamasteList(isDark),
                _buildReceivedNamasteList(isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSentNamasteList(bool isDark) {
    if (_currentUser == null) {
      return _buildEmptyState(
        icon: Icons.login,
        title: 'Not logged in',
        subtitle: 'Please log in to view your namaste history',
        isDark: isDark,
      );
    }

    // Query auraHistory and filter/sort in the app to avoid needing composite indexes
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('users')
          .doc(_currentUser!.uid)
          .collection('auraHistory')
          .limit(500) // Get more to filter
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          AppLogger.e('Error loading sent namastes',
              category: LogCategory.general, error: snapshot.error);
          return _buildEmptyState(
            icon: Icons.error_outline,
            title: 'Error loading history',
            subtitle: 'Please try again later',
            isDark: isDark,
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return ListView.builder(
            padding: EdgeInsets.only(top: 16, bottom: 20),
            itemCount: 5,
            itemBuilder: (_, __) => Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: SkeletonListItem(),
            ),
          );
        }

        // Filter for sent namastes and sort by timestamp
        final allDocs = snapshot.data?.docs ?? [];
        final namastes = allDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['action'] == 'namaste_sent';
        }).toList();

        // Sort by timestamp (most recent first)
        namastes.sort((a, b) {
          final aTime =
              (a.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
          final bTime =
              (b.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
          if (aTime == null || bTime == null) return 0;
          return bTime.compareTo(aTime);
        });

        // Limit to 100 most recent
        final limitedNamastes = namastes.take(100).toList();

        if (limitedNamastes.isEmpty) {
          return _buildEmptyState(
            useNamasteIcon: true,
            title: 'No namastes sent yet',
            subtitle: 'Send a namaste to someone to see it here!',
            isDark: isDark,
          );
        }

        // Filter by search query if provided (using FutureBuilder for async filtering)
        if (_searchQuery.isEmpty) {
          return ListView.builder(
            padding: EdgeInsets.only(top: 16, bottom: 20),
            itemCount: limitedNamastes.length,
            itemBuilder: (context, index) {
              final namaste = limitedNamastes[index];
              final data = namaste.data() as Map<String, dynamic>;
              final recipientId = data['affectedUserId'] as String?;
              final timestamp = (data['timestamp'] as Timestamp?)?.toDate();

              if (recipientId == null) return SizedBox.shrink();

              return _buildNamasteCard(
                userId: recipientId,
                timestamp: timestamp,
                isSent: true,
                isDark: isDark,
              );
            },
          );
        }

        // Use FutureBuilder for async search filtering
        return FutureBuilder<List<QueryDocumentSnapshot>>(
          future: _filterNamastesBySearch(limitedNamastes, _searchQuery),
          builder: (context, filterSnapshot) {
            if (filterSnapshot.connectionState == ConnectionState.waiting) {
              return ListView.builder(
                padding: EdgeInsets.only(top: 16, bottom: 20),
                itemCount: 4,
                itemBuilder: (_, __) => Padding(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: SkeletonListItem(),
                ),
              );
            }

            final filteredNamastes = filterSnapshot.data ?? [];

            if (filteredNamastes.isEmpty) {
              return _buildEmptyState(
                icon: Icons.search_off,
                title: 'No results found',
                subtitle: 'Try searching with a different name or username',
                isDark: isDark,
              );
            }

            return ListView.builder(
              padding: EdgeInsets.only(top: 16, bottom: 20),
              itemCount: filteredNamastes.length,
              itemBuilder: (context, index) {
                final namaste = filteredNamastes[index];
                final data = namaste.data() as Map<String, dynamic>;
                final recipientId = data['affectedUserId'] as String?;
                final timestamp = (data['timestamp'] as Timestamp?)?.toDate();

                if (recipientId == null) return SizedBox.shrink();

                return _buildNamasteCard(
                  userId: recipientId,
                  timestamp: timestamp,
                  isSent: true,
                  isDark: isDark,
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildReceivedNamasteList(bool isDark) {
    if (_currentUser == null) {
      return _buildEmptyState(
        icon: Icons.login,
        title: 'Not logged in',
        subtitle: 'Please log in to view your namaste history',
        isDark: isDark,
      );
    }

    // Query auraHistory and filter/sort in the app to avoid needing composite indexes
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('users')
          .doc(_currentUser!.uid)
          .collection('auraHistory')
          .limit(500) // Get more to filter
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          AppLogger.e('Error loading received namastes',
              category: LogCategory.general, error: snapshot.error);
          return _buildEmptyState(
            icon: Icons.error_outline,
            title: 'Error loading history',
            subtitle: 'Please try again later',
            isDark: isDark,
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return ListView.builder(
            padding: EdgeInsets.only(top: 16, bottom: 20),
            itemCount: 5,
            itemBuilder: (_, __) => Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: SkeletonListItem(),
            ),
          );
        }

        // Filter for received namastes and sort by timestamp
        final allDocs = snapshot.data?.docs ?? [];
        final namastes = allDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['action'] == 'namaste_received';
        }).toList();

        // Sort by timestamp (most recent first)
        namastes.sort((a, b) {
          final aTime =
              (a.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
          final bTime =
              (b.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
          if (aTime == null || bTime == null) return 0;
          return bTime.compareTo(aTime);
        });

        // Limit to 100 most recent
        final limitedNamastes = namastes.take(100).toList();

        if (limitedNamastes.isEmpty) {
          return _buildEmptyState(
            useNamasteIcon: true,
            title: 'No namastes received yet',
            subtitle: 'When someone sends you a namaste, it will appear here!',
            isDark: isDark,
          );
        }

        // Filter by search query if provided (using FutureBuilder for async filtering)
        if (_searchQuery.isEmpty) {
          return ListView.builder(
            padding: EdgeInsets.only(top: 16, bottom: 20),
            itemCount: limitedNamastes.length,
            itemBuilder: (context, index) {
              final namaste = limitedNamastes[index];
              final data = namaste.data() as Map<String, dynamic>;
              final senderId = data['affectedUserId'] as String?;
              final timestamp = (data['timestamp'] as Timestamp?)?.toDate();

              if (senderId == null) return SizedBox.shrink();

              return _buildNamasteCard(
                userId: senderId,
                timestamp: timestamp,
                isSent: false,
                isDark: isDark,
              );
            },
          );
        }

        // Use FutureBuilder for async search filtering
        return FutureBuilder<List<QueryDocumentSnapshot>>(
          future: _filterNamastesBySearch(limitedNamastes, _searchQuery),
          builder: (context, filterSnapshot) {
            if (filterSnapshot.connectionState == ConnectionState.waiting) {
              return ListView.builder(
                padding: EdgeInsets.only(top: 16, bottom: 20),
                itemCount: 4,
                itemBuilder: (_, __) => Padding(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: SkeletonListItem(),
                ),
              );
            }

            final filteredNamastes = filterSnapshot.data ?? [];

            if (filteredNamastes.isEmpty) {
              return _buildEmptyState(
                icon: Icons.search_off,
                title: 'No results found',
                subtitle: 'Try searching with a different name or username',
                isDark: isDark,
              );
            }

            return ListView.builder(
              padding: EdgeInsets.only(top: 16, bottom: 20),
              itemCount: filteredNamastes.length,
              itemBuilder: (context, index) {
                final namaste = filteredNamastes[index];
                final data = namaste.data() as Map<String, dynamic>;
                final senderId = data['affectedUserId'] as String?;
                final timestamp = (data['timestamp'] as Timestamp?)?.toDate();

                if (senderId == null) return SizedBox.shrink();

                return _buildNamasteCard(
                  userId: senderId,
                  timestamp: timestamp,
                  isSent: false,
                  isDark: isDark,
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildNamasteCard({
    required String userId,
    required DateTime? timestamp,
    required bool isSent,
    required bool isDark,
  }) {
    return FutureBuilder<DocumentSnapshot>(
      future: _firestore.collection('users').doc(userId).get(),
      builder: (context, snapshot) {
        String name = 'Loading...';
        String? displayPicture;

        if (snapshot.hasData && snapshot.data!.exists) {
          final userData = snapshot.data!.data() as Map<String, dynamic>?;
          name = userData?['name'] ?? 'Unknown';
          displayPicture = userData?['displayPicture'];
        }

        return Container(
          margin: EdgeInsets.fromLTRB(20, 0, 20, 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      Colors.white.withValues(alpha: 0.08),
                      Colors.white.withValues(alpha: 0.04),
                    ]
                  : [
                      Colors.white,
                      Colors.white,
                    ],
            ),
            boxShadow: isDark
                ? [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      blurRadius: 20,
                      offset: Offset(0, 4),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 20,
                      offset: Offset(0, 4),
                    ),
                  ],
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.12)
                  : AppTheme.primaryColor.withValues(alpha: 0.1),
              width: 1.5,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
              onTap: () {
                Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute(
                    builder: (context) => UserProfilePage(uid: userId),
                  ),
                );
              },
              child: Container(
                padding: EdgeInsets.all(18),
                child: Row(
                  children: [
                    // Avatar with gradient border
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.primaryColor,
                            AppTheme.primaryColor.withValues(alpha: 0.6),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryColor.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: EdgeInsets.all(3),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark
                              ? AppTheme.scaffoldDarkColor
                              : Colors.white,
                        ),
                        padding: EdgeInsets.all(2),
                        child: UserAvatar(
                          userId: userId,
                          imageUrl: displayPicture,
                          size: 60,
                          nameInitials:
                              name.isNotEmpty ? name.substring(0, 1) : null,
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                    ),
                    SizedBox(width: 18),

                    // User info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  name,
                                  style: TextStyle(
                                    fontSize: AppTheme.holyCowTextSize,
                                    fontWeight: FontWeight.w700,
                                    color: isDark
                                        ? AppTheme.textDarkColor
                                        : AppTheme.textLightColor,
                                    letterSpacing: 0.2,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              // Direction indicator
                              Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isSent
                                      ? AppTheme.primaryColor.withValues(alpha: 0.15)
                                      : AppTheme.accentColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isSent
                                          ? Icons.arrow_upward_rounded
                                          : Icons.arrow_downward_rounded,
                                      size: 12,
                                      color: isSent
                                          ? AppTheme.primaryColor
                                          : AppTheme.accentColor,
                                    ),
                                    SizedBox(width: AppDimensions.spacingXs),
                                    Text(
                                      isSent ? 'Sent' : 'Received',
                                      style: TextStyle(
                                        fontSize: AppTheme.holyCowTextSize,
                                        fontWeight: FontWeight.w600,
                                        color: isSent
                                            ? AppTheme.primaryColor
                                            : AppTheme.accentColor,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (timestamp != null) ...[
                            SizedBox(height: AppDimensions.spacingSm),
                            Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(AppDimensions.paddingXs),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(AppDimensions.radiusSmMd),
                                  ),
                                  child: Icon(
                                    Icons.access_time_rounded,
                                    size: 12,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                                SizedBox(width: AppDimensions.spacingSmMd),
                                Text(
                                  _formatTimestamp(timestamp),
                                  style: TextStyle(
                                    fontSize: AppTheme.holyCowTextSize,
                                    color: isDark
                                        ? AppTheme.textSecondaryDarkColor
                                        : AppTheme.textSecondaryLightColor,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),

                    SizedBox(width: AppDimensions.spacingMd),

                    // Namaste icon with glow effect
                    Container(
                      padding: EdgeInsets.all(AppDimensions.paddingMd),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppTheme.primaryColor.withValues(alpha: 0.2),
                            AppTheme.primaryColor.withValues(alpha: 0.1),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryColor.withValues(alpha: 0.2),
                            blurRadius: 16,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Image.asset(
                        'assets/icons/namaste.png',
                        width: 48,
                        height: 48,
                        filterQuality: FilterQuality.high,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState({
    IconData? icon,
    bool useNamasteIcon = false,
    required String title,
    required String subtitle,
    required bool isDark,
  }) {
    return SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: MediaQuery.of(context).size.height - 200,
        ),
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(48),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Animated icon container
                Container(
                  padding: EdgeInsets.all(40),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppTheme.primaryColor.withValues(alpha: 0.15),
                        AppTheme.primaryColor.withValues(alpha: 0.05),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor.withValues(alpha: 0.2),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: useNamasteIcon
                      ? Image.asset(
                          'assets/icons/namaste.png',
                          width: 100,
                          height: 100,
                          opacity: AlwaysStoppedAnimation(0.7),
                          filterQuality: FilterQuality.high,
                        )
                      : Icon(
                          icon ?? Icons.error_outline,
                          size: 72,
                          color: AppTheme.primaryColor.withValues(alpha: 0.7),
                        ),
                ),
                SizedBox(height: AppDimensions.spacingLargeSection),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: AppTheme.holyCowTextSize,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppTheme.textDarkColor
                        : AppTheme.textLightColor,
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: AppDimensions.spacingLg),
                Container(
                  constraints: BoxConstraints(maxWidth: 300),
                  child: Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: AppTheme.holyCowTextSize,
                      color: isDark
                          ? AppTheme.textSecondaryDarkColor
                          : AppTheme.textSecondaryLightColor,
                      height: 1.6,
                      fontWeight: FontWeight.w400,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<List<QueryDocumentSnapshot>> _filterNamastesBySearch(
      List<QueryDocumentSnapshot> namastes, String query) async {
    final filtered = <QueryDocumentSnapshot>[];

    for (final namaste in namastes) {
      final data = namaste.data() as Map<String, dynamic>;
      final userId = data['affectedUserId'] as String?;

      if (userId == null) continue;

      try {
        final userDoc = await _firestore.collection('users').doc(userId).get();
        if (userDoc.exists) {
          final userData = userDoc.data();
          final name = (userData?['name'] ?? '').toString();
          final nickname = (userData?['nickname'] ?? '').toString();

          // Use central SearchService for consistent smart matching
          if (SearchService.smartMatch(query, name) ||
              SearchService.smartMatch(query, nickname)) {
            filtered.add(namaste);
          }
        }
      } catch (e) {
        AppLogger.w('Error filtering namaste by search',
            category: LogCategory.general, data: {'error': e.toString()});
      }
    }

    return filtered;
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else if (difference.inDays < 30) {
      return '${(difference.inDays / 7).floor()}w ago';
    } else {
      return DateFormat('MMM d, yyyy').format(timestamp);
    }
  }
}
