import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/widgets/ui/skeleton_widgets.dart';
import 'package:intl/intl.dart';

/// Page to display user's saved insights
class SavedInsightsPage extends StatelessWidget {
  final String uid;

  const SavedInsightsPage({super.key, required this.uid});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final brown = AppTheme.astroBrown(isDark);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          // Header
          SliverToBoxAdapter(
            child: SafeArea(
              bottom: false,
              child: Container(
                height: 60,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    // Back button
                    SizedBox(
                      width: 40,
                      child: IconButton(
                        icon: Icon(Icons.arrow_back_ios_new_rounded,
                            size: 20, color: brown),
                        onPressed: () => Navigator.of(context).pop(),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                    // Title
                    Expanded(
                      child: Center(
                        child: Text(
                          'saved',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: brown,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
                    // Spacer
                    const SizedBox(width: 40),
                  ],
                ),
              ),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .collection('savedInsights')
                  .orderBy('savedAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _buildLoadingState();
                }

                if (snapshot.hasError) {
                  return _buildErrorState(brown);
                }

                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return _buildEmptyState(brown);
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: docs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      return _buildSavedInsightCard(
                        context: context,
                        docId: doc.id,
                        data: data,
                        brown: brown,
                        isDark: isDark,
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ),

          // Bottom padding
          const SliverToBoxAdapter(
            child: SizedBox(height: 100),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: List.generate(
          3,
          (index) => const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: SkeletonCard(height: 120),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(Color brown) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 60),
          Icon(
            Icons.bookmark_outline,
            size: 64,
            color: brown.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No saved insights yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: brown.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap Save on any insight card to keep it here',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: brown.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(Color brown) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 60),
          Icon(
            Icons.error_outline,
            size: 48,
            color: brown.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Could not load saved insights',
            style: TextStyle(
              fontSize: 16,
              color: brown.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSavedInsightCard({
    required BuildContext context,
    required String docId,
    required Map<String, dynamic> data,
    required Color brown,
    required bool isDark,
  }) {
    final title = data['title'] as String? ?? 'Insight';
    final content = data['content'] as String? ?? '';
    final scheduledFor = data['scheduledFor'] as String?;
    final insightDate = data['insightDate'] as String?;

    // Format dates
    String dateInfo = '';
    if (insightDate != null) {
      try {
        final date = DateTime.parse(insightDate);
        dateInfo = DateFormat('MMM d, yyyy').format(date);
        if (scheduledFor != null) {
          dateInfo += ' at $scheduledFor';
        }
      } catch (_) {
        dateInfo = insightDate;
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: isDark ? AppTheme.cardDarkColor : AppTheme.cardLightColor,
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: brown,
                          ),
                        ),
                        if (dateInfo.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            dateInfo,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: brown.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Delete button
                  GestureDetector(
                    onTap: () => _deleteInsight(context, docId, brown),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        Icons.close,
                        size: 18,
                        color: brown.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                ],
              ),

              if (content.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  content,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    height: 1.5,
                    color: brown.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteInsight(
      BuildContext context, String docId, Color brown) async {
    HapticFeedback.lightImpact();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Remove saved insight?',
          style: TextStyle(color: brown),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: brown.withValues(alpha: 0.6)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Remove',
              style: TextStyle(color: AppTheme.errorColor),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('savedInsights')
          .doc(docId)
          .delete();
    }
  }
}

