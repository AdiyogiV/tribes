import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/pages/ayurveda/widgets/ayurveda_theme.dart';
import 'package:aurogram/utils/logging/app_logger.dart';

/// AI-powered personalized Ayurveda recommendations card
/// Fetches recommendations from backend using Gemini AI
class AIRecommendationsCard extends StatefulWidget {
  final bool isDark;
  final VoidCallback? onRefresh;

  const AIRecommendationsCard({
    super.key,
    required this.isDark,
    this.onRefresh,
  });

  @override
  State<AIRecommendationsCard> createState() => _AIRecommendationsCardState();
}

class _AIRecommendationsCardState extends State<AIRecommendationsCard> {
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  Map<String, dynamic>? _recommendations;
  Map<String, dynamic>? _context;

  @override
  void initState() {
    super.initState();
    _loadRecommendations();
  }

  Future<void> _loadRecommendations() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
    });

    try {
      // Ensure user is authenticated before calling
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }
      
      // Force refresh the ID token to ensure it's valid
      await user.getIdToken(true);
      
      final functions = FirebaseFunctions.instanceFor(region: 'asia-southeast2');
      final callable = functions.httpsCallable('getAyurvedaRecommendations');
      final result = await callable.call();

      if (result.data != null && result.data['success'] == true) {
        setState(() {
          _recommendations = Map<String, dynamic>.from(result.data['recommendations'] ?? {});
          _context = Map<String, dynamic>.from(result.data['context'] ?? {});
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to get recommendations');
      }
    } catch (e, stackTrace) {
      AppLogger.e('Failed to load AI recommendations',
          category: LogCategory.general, error: e, stackTrace: stackTrace);
      setState(() {
        _hasError = true;
        _errorMessage = 'Unable to load recommendations';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.primaryColor;

    return AyurvedaCardContainer(
      isDark: widget.isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Expanded(
                child: Text(
                  'Wellness Tips',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: c,
                  ),
                ),
              ),
              if (!_isLoading && !_hasError)
                GestureDetector(
                  onTap: _loadRecommendations,
                  child: Icon(
                    Icons.refresh,
                    size: 18,
                    color: widget.isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
            ],
          ),

          if (_context != null && _context!['topImbalance'] != null) ...[
            const SizedBox(height: 4),
            Text(
              'Based on your ${_context!['topImbalance']} imbalance • ${_context!['season'] ?? 'Current season'}',
              style: TextStyle(
                fontSize: 11,
                color: widget.isDark ? Colors.white38 : Colors.black38,
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Content
          if (_isLoading)
            _buildLoadingState()
          else if (_hasError)
            _buildErrorState()
          else
            _buildRecommendations(),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Column(
      children: [
        const SizedBox(height: 20),
        SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation(AppTheme.primaryColor),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Generating personalized tips...',
          style: TextStyle(
            fontSize: 12,
            color: widget.isDark ? Colors.white54 : Colors.black54,
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildErrorState() {
    // Show compact retry option instead of prominent error
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            size: 16,
            color: widget.isDark ? Colors.white38 : Colors.black38,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'AI tips unavailable',
              style: TextStyle(
                fontSize: 12,
                color: widget.isDark ? Colors.white54 : Colors.black54,
              ),
            ),
          ),
          GestureDetector(
            onTap: _loadRecommendations,
            child: Text(
              'Retry',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendations() {
    if (_recommendations == null) return const SizedBox.shrink();

    final diet = _recommendations!['diet'] as Map<String, dynamic>?;
    final lifestyle = _recommendations!['lifestyle'] as List<dynamic>?;
    final quickRemedy = _recommendations!['quickRemedy'] as Map<String, dynamic>?;
    final mindfulness = _recommendations!['mindfulness'] as String?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Quick Remedy (most prominent)
        if (quickRemedy != null) ...[
          _buildQuickRemedySection(quickRemedy),
          const SizedBox(height: 16),
        ],

        // Diet recommendations
        if (diet != null && diet['favor'] != null) ...[
          _buildDietSection(diet),
          const SizedBox(height: 16),
        ],

        // Lifestyle tips
        if (lifestyle != null && lifestyle.isNotEmpty) ...[
          _buildLifestyleSection(lifestyle),
          const SizedBox(height: 16),
        ],

        // Mindfulness note
        if (mindfulness != null) _buildMindfulnessSection(mindfulness),
      ],
    );
  }

  Widget _buildQuickRemedySection(Map<String, dynamic> remedy) {
    final action = remedy['action'] as String? ?? '';
    final reasoning = remedy['reasoning'] as String?;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.spa,
              size: 20,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Today\'s Tip',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  action,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: widget.isDark ? Colors.white : Colors.black87,
                  ),
                ),
                if (reasoning != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    reasoning,
                    style: TextStyle(
                      fontSize: 11,
                      color: widget.isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDietSection(Map<String, dynamic> diet) {
    final favor = (diet['favor'] as List<dynamic>?)?.cast<String>() ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.restaurant_outlined,
              size: 14,
              color: widget.isDark ? Colors.white54 : Colors.black54,
            ),
            const SizedBox(width: 6),
            Text(
              'Foods to Favor',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: widget.isDark ? Colors.white70 : Colors.black54,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: favor.take(6).map((food) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: widget.isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                food,
                style: TextStyle(
                  fontSize: 12,
                  color: widget.isDark ? Colors.white70 : Colors.black54,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildLifestyleSection(List<dynamic> lifestyle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.self_improvement_outlined,
              size: 14,
              color: widget.isDark ? Colors.white54 : Colors.black54,
            ),
            const SizedBox(width: 6),
            Text(
              'Daily Routine',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: widget.isDark ? Colors.white70 : Colors.black54,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...lifestyle.take(3).map((tip) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 14,
                  color: AppTheme.primaryColor.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tip.toString(),
                    style: TextStyle(
                      fontSize: 12,
                      color: widget.isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildMindfulnessSection(String mindfulness) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.purple.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            Icons.psychology_outlined,
            size: 16,
            color: Colors.purple,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              mindfulness,
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: widget.isDark ? Colors.white70 : Colors.black54,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
