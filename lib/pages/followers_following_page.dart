import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:aurogram/pages/follow_list_page.dart';

/// Stats page with tabs for Followers and Following. Opened from the profile stats card.
class FollowersFollowingPage extends StatefulWidget {
  final String userId;
  final String? userName;
  /// 0 = Followers, 1 = Following
  final int initialTabIndex;

  const FollowersFollowingPage({
    super.key,
    required this.userId,
    this.userName,
    this.initialTabIndex = 0,
  });

  @override
  State<FollowersFollowingPage> createState() => _FollowersFollowingPageState();
}

class _FollowersFollowingPageState extends State<FollowersFollowingPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 1),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;
    final scaffoldBg = theme.scaffoldBackgroundColor;
    final subtitleColor = primaryColor.withValues(alpha: 0.6);
    final unselectedColor = isDark
        ? primaryColor.withValues(alpha: 0.5)
        : primaryColor.withValues(alpha: 0.6);

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: scaffoldBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: primaryColor),
        leading: IconButton(
          icon: Icon(CupertinoIcons.back, color: primaryColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            Text(
              'Stats',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: primaryColor,
              ),
            ),
            if (widget.userName != null && widget.userName!.isNotEmpty)
              Text(
                widget.userName!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: subtitleColor,
                ),
              ),
          ],
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: primaryColor,
          labelColor: primaryColor,
          unselectedLabelColor: unselectedColor,
          labelStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: unselectedColor,
          ),
          tabs: const [
            Tab(text: 'Followers'),
            Tab(text: 'Following'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          FollowListContent(
            userId: widget.userId,
            listType: FollowListType.followers,
            userName: widget.userName,
          ),
          FollowListContent(
            userId: widget.userId,
            listType: FollowListType.following,
            userName: widget.userName,
          ),
        ],
      ),
    );
  }
}
