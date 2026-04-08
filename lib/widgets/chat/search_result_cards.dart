import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:aurogram/providers/ai_chat_provider.dart';
import 'package:aurogram/config/api_endpoints.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/models/thought_process.dart';
import 'package:aurogram/utils/theme/app_dimensions.dart';

/// A utility class for building search result cards in the chat interface.
///
/// This class provides static methods to create different types of search result
/// cards that can be displayed alongside AI chat messages to show relevant
/// web search results.
class SearchResultCards {
  /// Builds a detailed search result card with full information display.
  ///
  /// [result] The search result data to display
  /// [onLaunchUrl] Callback function to handle URL launches
  static Widget buildSearchResultCard(
      SearchResult result, Function(String) onLaunchUrl) {
    return Container(
      width: 290,
      margin: EdgeInsets.symmetric(horizontal: 4),
      child: Card(
        elevation: 3,
        shadowColor: AppTheme.primaryColor.withValues(alpha: 0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusLg)),
        child: InkWell(
          onTap: () {
            onLaunchUrl(result.link);
            HapticFeedback.lightImpact();
          },
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white,
                  Colors.grey[50]!,
                ],
              ),
            ),
            child: Padding(
              padding: EdgeInsets.all(AppDimensions.paddingMdLg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with favicon and domain
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: CachedNetworkImage(
                            imageUrl: result.favicon ?? '',
                            width: 16,
                            height: 16,
                            placeholder: (context, url) => Icon(
                              Icons.language,
                              size: 16,
                              color: Colors.grey[600],
                            ),
                            errorWidget: (context, url, error) => Icon(
                              Icons.language,
                              size: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: AppDimensions.spacingMdSm),
                      Expanded(
                        child: Text(
                          result.displayLink,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.all(AppDimensions.paddingXs),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                        ),
                        child: Icon(
                          Icons.open_in_new,
                          size: 12,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: AppDimensions.spacingMd),
                  // Title
                  Text(
                    result.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: AppDimensions.spacingSm),
                  // Snippet
                  Expanded(
                    child: Text(
                      result.snippet,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[700],
                        height: 1.4,
                      ),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(height: AppDimensions.spacingSm),
                  // Source indicator
                  Row(
                    children: [
                      Icon(
                        Icons.source,
                        size: 12,
                        color: AppTheme.primaryColor.withValues(alpha: 0.7),
                      ),
                      SizedBox(width: AppDimensions.spacingXs),
                      Text(
                        'Tap to read more',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppTheme.primaryColor.withValues(alpha: 0.8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Widget buildEnhancedSearchCard(
      SearchResult result, Function(String) onLaunchUrl) {
    // Generate a background image URL based on the domain
    final domainImageUrl =
        '${ApiEndpoints.clearbitLogo}/${Uri.parse(result.link).host}';

    return Container(
      width: 240,
      margin: EdgeInsets.only(right: 12),
      child: Card(
        elevation: 2,
        shadowColor: AppTheme.primaryColor.withValues(alpha: 0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusMd)),
        child: InkWell(
          onTap: () {
            onLaunchUrl(result.link);
            HapticFeedback.lightImpact();
          },
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white,
                  Colors.grey[50]!,
                ],
              ),
            ),
            child: Stack(
              children: [
                // Background image overlay
                Positioned(
                  top: 0,
                  right: 0,
                  child: ClipRRect(
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(12),
                      bottomLeft: Radius.circular(20),
                    ),
                    child: Container(
                      width: 60,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.primaryColor.withValues(alpha: 0.1),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: CachedNetworkImage(
                        imageUrl: domainImageUrl,
                        width: 32,
                        height: 32,
                        fit: BoxFit.contain,
                        placeholder: (context, url) => Icon(
                          Icons.language,
                          size: 16,
                          color: AppTheme.primaryColor.withValues(alpha: 0.3),
                        ),
                        errorWidget: (context, url, error) => Icon(
                          Icons.language,
                          size: 16,
                          color: AppTheme.primaryColor.withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                  ),
                ),
                // Content
                Padding(
                  padding: EdgeInsets.all(AppDimensions.paddingMd),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        result.title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111827),
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: AppDimensions.spacingXs),
                      // Domain
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(1),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: CachedNetworkImage(
                              imageUrl: result.favicon ?? '',
                              width: 12,
                              height: 12,
                              placeholder: (context, url) => Icon(
                                Icons.public,
                                size: 12,
                                color: Colors.grey[500],
                              ),
                              errorWidget: (context, url, error) => Icon(
                                Icons.public,
                                size: 12,
                                color: Colors.grey[500],
                              ),
                            ),
                          ),
                          SizedBox(width: AppDimensions.spacingSmMd),
                          Expanded(
                            child: Text(
                              result.displayLink,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(
                            Icons.open_in_new,
                            size: 10,
                            color: AppTheme.primaryColor.withValues(alpha: 0.6),
                          ),
                        ],
                      ),
                      SizedBox(height: AppDimensions.spacingSmMd),
                      // Snippet
                      Expanded(
                        child: Text(
                          result.snippet,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[700],
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget buildIntegratedSearchResults(
    AiChatProvider provider,
    dynamic message,
    Map<String, bool> expansionState,
    Function(String, bool) onExpansionChanged,
    Function(String) onLaunchUrl,
  ) {
    // Get search results from the message first, fallback to provider's current results
    final searchResults =
        message.searchResults ?? provider.currentSession.searchResults;

    if (searchResults.isEmpty) return SizedBox.shrink();

    // Use message ID for per-message expansion state
    final messageId = message.id;
    final isExpanded = expansionState[messageId] ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Clickable header to toggle expansion
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
            onTap: () {
              onExpansionChanged(messageId, !isExpanded);
              HapticFeedback.lightImpact();
            },
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.link,
                    size: 14,
                    color: AppTheme.primaryColor.withValues(alpha: 0.7),
                  ),
                  SizedBox(width: AppDimensions.spacingSmMd),
                  Text(
                    'Sources (${searchResults.length})',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(width: AppDimensions.spacingXs),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0.0,
                    duration: Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      size: 16,
                      color: AppTheme.primaryColor.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Collapsible search result cards
        AnimatedContainer(
          duration: Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          height: isExpanded ? 120 : 0,
          child: AnimatedOpacity(
            duration: Duration(milliseconds: 200),
            opacity: isExpanded ? 1.0 : 0.0,
            child: isExpanded
                ? Container(
                    margin: EdgeInsets.only(top: 4),
                    height: 120,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.symmetric(horizontal: 0),
                      itemCount: searchResults.length,
                      itemBuilder: (context, index) {
                        final result = searchResults[index];
                        return buildEnhancedSearchCard(result, onLaunchUrl);
                      },
                    ),
                  )
                : SizedBox.shrink(),
          ),
        ),
      ],
    );
  }
}
