import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:aurogram/widgets/ui/common_widgets.dart';
import 'package:aurogram/utils/logging/app_logger.dart';
import 'package:aurogram/services/data/post_db_service.dart';
import 'package:aurogram/services/analytics_service.dart';
import 'package:aurogram/services/story_service.dart';
import 'package:aurogram/services/share/share_links.dart';
import 'package:aurogram/services/share/share_media.dart';
import 'package:aurogram/services/share/share_text_builders.dart';
import 'package:aurogram/services/share/share_ui.dart';
import 'package:aurogram/widgets/astrology/cosmic_share_card.dart';
import 'package:aurogram/widgets/astrology/compatibility_share_cards.dart';
import 'package:aurogram/widgets/astrology/insight_share_card.dart';
import 'package:aurogram/widgets/spaces/gram_share_card.dart';
import 'package:aurogram/widgets/share/share_preview_sheets.dart';
import 'package:aurogram/widgets/chat/chat_picker_sheet.dart';
import 'package:aurogram/pages/stories/story_composer_page.dart';

/// Service for sharing content (posts, profiles, spaces, cosmic connections)
///
/// Uses Universal Links (iOS) and App Links (Android) for deep linking
/// Hosted on Firebase Hosting at ty-dev-516d7.web.app
class ShareService {
  /// Capture a card widget and open story composer with the image.
  /// Caller should pop any overlay (e.g. preview sheet) before calling if desired.
  static Future<void> addToStoryFromCard(
    BuildContext context,
    Widget card, {
    String? sourceType,
    String? sourceId,
  }) async {
    AppLogger.i('addToStoryFromCard: capturing card widget',
        category: LogCategory.general,
        data: {'sourceType': sourceType, 'sourceId': sourceId});
    final bytes = await ShareMedia.captureWidgetToBytes(card: card);
    AppLogger.i('addToStoryFromCard: capture result',
        category: LogCategory.general,
        data: {'bytesLength': bytes?.length ?? 0, 'success': bytes != null});
    if (!context.mounted) return;
    if (bytes == null) {
      ShareUi.showErrorSnackbar(context, 'Could not create story image');
      return;
    }
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => StoryComposerPage(
          initialImageBytes: bytes,
          sourceType: sourceType,
          sourceId: sourceId,
        ),
      ),
    );
  }

  /// Share a post
  static Future<void> sharePost({
    required BuildContext context,
    required String postId,
  }) async {
    try {
      // Get post data for context
      final postDbService = PostDbService();
      final postDoc = await postDbService.getPost(postId);

      String? title;
      String? authorName;
      String? authorId;
      String? authorAvatar;
      String? imageUrl;
      String? postType;

      if (postDoc.exists) {
        final data = postDoc.data() as Map<String, dynamic>?;
        title = data?['title'] as String?;
        authorName = data?['authorName'] as String?;
        authorId = data?['author'] as String?;
        authorAvatar = data?['authorAvatar'] as String? ??
            data?['authorPhotoURL'] as String?;
        // Try all possible image field names: thumbnail, video (for image posts), media
        imageUrl = data?['thumbnail'] as String? ??
            data?['video'] as String? ??
            data?['media'] as String?;
        postType = data?['postType'] as String?;
        AppLogger.d('Share post: loaded post data',
            category: LogCategory.general,
            data: {
              'postId': postId,
              'postType': postType,
              'hasThumbnail': data?['thumbnail'] != null,
              'hasVideo': data?['video'] != null,
              'hasMedia': data?['media'] != null,
              'finalImageUrl': imageUrl,
            });
      }

      // Build share URL (short path)
      final shareUrl = ShareLinks.post(postId);

      // Build share text
      final shareText = ShareTextBuilders.post(
        shareUrl: shareUrl,
        title: title,
        authorName: authorName,
      );

      // Create chat share content
      final extraData = <String, dynamic>{};
      if (postType != null) extraData['postType'] = postType;
      if (authorId != null) extraData['authorId'] = authorId;
      if (authorAvatar != null) extraData['authorAvatar'] = authorAvatar;

      final chatContent = ShareableContent(
        type: 'post',
        id: postId,
        title: title ?? 'Post',
        subtitle: title?.isNotEmpty == true ? null : 'Shared a post',
        imageUrl: imageUrl,
        authorName: authorName,
        extraData: extraData.isNotEmpty ? extraData : null,
      );

      // Show share options
      await ShareUi.showShareOptions(
        context: context,
        shareText: shareText,
        shareUrl: shareUrl,
        contentType: 'Post',
        chatShareContent: chatContent,
        onAddToStory: () async {
          // Render post as story card with Instagram-style black background
          final bytes = await StoryService().renderPostStoryCard(
            postId: postId,
            backgroundColor: Colors.black,
          );

          if (bytes == null) {
            if (context.mounted) {
              ShareUi.showErrorSnackbar(context, 'Failed to create story card');
            }
            return;
          }

          // Open story composer with preview (user can review before posting)
          if (context.mounted) {
            await Navigator.of(context).push<bool>(
              MaterialPageRoute(
                builder: (_) => StoryComposerPage(
                  initialImageBytes: bytes,
                  sourceType: 'post',
                  sourceId: postId,
                ),
              ),
            );
          }
        },
      );

      AnalyticsService().trackContentShared(
        contentType: 'post',
        itemId: postId,
      );
    } catch (e) {
      AppLogger.e('Error sharing post', error: e);
      ShareUi.showErrorSnackbar(context, 'Failed to share');
    }
  }

  /// Share a user profile
  static Future<void> shareProfile({
    required BuildContext context,
    required String userId,
    String? userName,
    String? userAvatar,
  }) async {
    try {
      final shareUrl = ShareLinks.profile(userId);
      final shareText = ShareTextBuilders.profile(
        shareUrl: shareUrl,
        userName: userName,
      );

      // Create chat share content
      final chatContent = ShareableContent(
        type: 'profile',
        id: userId,
        title: userName ?? 'User Profile',
        subtitle: 'Check out this profile',
        imageUrl: userAvatar,
      );

      await ShareUi.showShareOptions(
        context: context,
        shareText: shareText,
        shareUrl: shareUrl,
        contentType: 'Profile',
        chatShareContent: chatContent,
      );

      AnalyticsService().trackContentShared(
        contentType: 'profile',
        itemId: userId,
      );
    } catch (e) {
      AppLogger.e('Error sharing profile', error: e);
      ShareUi.showErrorSnackbar(context, 'Failed to share');
    }
  }

  /// Share cosmic profile (invite to check compatibility)
  /// This shares YOUR profile with a CTA to check compatibility
  static Future<void> shareCosmicProfile({
    required BuildContext context,
    required String userId,
    String? userName,
    String? sunSign,
    String? moonSign,
    String? userAvatar,
  }) async {
    try {
      final shareUrl = ShareLinks.cosmicProfile(userId);
      final shareText = ShareTextBuilders.cosmicProfile(
        shareUrl: shareUrl,
        userName: userName,
        sunSign: sunSign,
        moonSign: moonSign,
      );

      // Create chat share content
      final chatContent = ShareableContent(
        type: 'cosmic',
        id: userId,
        title: userName ?? 'Cosmic Profile',
        subtitle: sunSign != null && moonSign != null
            ? '$sunSign Sun, $moonSign Moon'
            : 'Check out my cosmic profile',
        imageUrl: userAvatar,
      );

      await ShareUi.showShareOptions(
        context: context,
        shareText: shareText,
        shareUrl: shareUrl,
        contentType: 'Cosmic Profile',
        chatShareContent: chatContent,
      );

      AnalyticsService().trackContentShared(
        contentType: 'cosmic_profile',
        itemId: userId,
      );
    } catch (e) {
      AppLogger.e('Error sharing cosmic profile', error: e);
      ShareUi.showErrorSnackbar(context, 'Failed to share');
    }
  }

  /// Share a space/gram
  static Future<void> shareSpace({
    required BuildContext context,
    required String spaceId,
    String? spaceName,
    String? spaceImage,
  }) async {
    try {
      final shareUrl = ShareLinks.space(spaceId);
      final shareText = ShareTextBuilders.space(
        shareUrl: shareUrl,
        spaceName: spaceName,
      );

      // Create chat share content
      final chatContent = ShareableContent(
        type: 'space',
        id: spaceId,
        title: spaceName ?? 'Gram',
        subtitle: 'Join this Gram',
        imageUrl: spaceImage,
      );

      await ShareUi.showShareOptions(
        context: context,
        shareText: shareText,
        shareUrl: shareUrl,
        chatShareContent: chatContent,
        contentType: 'Space',
      );

      AnalyticsService().trackContentShared(
        contentType: 'space',
        itemId: spaceId,
      );
    } catch (e) {
      AppLogger.e('Error sharing space', error: e);
      ShareUi.showErrorSnackbar(context, 'Failed to share');
    }
  }

  /// Get share URL for a user profile
  static String getProfileUrl(String userId) => ShareLinks.profile(userId);

  /// Get share URL for cosmic compatibility invite
  static String getCosmicUrl(String userId) => ShareLinks.cosmicProfile(userId);

  /// Get share URL for a post
  static String getPostUrl(String postId) => ShareLinks.post(postId);

  /// Get share URL for a space
  /// Build space URL with optional gram info for web preview
  static String getSpaceUrl(String spaceId,
          {String? gramName, String? inviterName, String? inviterId}) =>
      ShareLinks.space(spaceId,
          gramName: gramName, inviterName: inviterName, inviterId: inviterId);

  /// Show gram card preview before sharing
  /// User sees the card first, then can tap share
  static void showGramCardPreview({
    required BuildContext context,
    required String spaceId,
    required String gramName,
    String? description,
    File? displayPicture,
    String? displayPictureUrl,
    int memberCount = 0,
    bool isPrivate = false,
    String? inviterName,
    String? inviterId,
  }) {
    final card = GramShareCard(
      gramName: gramName,
      description: description,
      displayPicture: displayPicture,
      displayPictureUrl: displayPictureUrl,
      memberCount: memberCount,
      isPrivate: isPrivate,
      inviterName: inviterName,
    );

    AppBottomSheet.show(
      context,
      child: GramCardPreviewSheet(
        card: card,
        spaceName: gramName,
        onCopyLink: () async {
          final shareUrl = ShareLinks.space(spaceId,
              gramName: gramName,
              inviterName: inviterName,
              inviterId: inviterId);
          await Clipboard.setData(ClipboardData(text: shareUrl));
          if (context.mounted) {
            Navigator.pop(context);
            ShareUi.showSuccessSnackbar(context, 'Link copied!');
          }
        },
        onShareCard: () {
          Navigator.pop(context);
          final shareUrl = ShareLinks.space(spaceId,
              gramName: gramName,
              inviterName: inviterName,
              inviterId: inviterId);
          final shareText = ShareTextBuilders.gramInvite(
            spaceName: gramName,
            shareUrl: shareUrl,
          );
          ShareMedia.shareWidgetAsImage(
            context: context,
            card: card,
            filePrefix: 'gram_invite',
            shareText: shareText,
            logLabel: 'gram card',
          );
        },
        onAddToStory: () async {
          Navigator.pop(context);
          await addToStoryFromCard(
            context,
            card,
            sourceType: 'space',
            sourceId: spaceId,
          );
        },
      ),
    );
  }

  /// Show Cosmic Vibe Match card preview before sharing
  static void showCosmicVibeCardPreview({
    required BuildContext context,
    required int score,
    required String label,
    required List<PillarData> pillars,
    required String user1Name,
    required String user2Name,
    String? user1PhotoUrl,
    String? user2PhotoUrl,
    String? user1Sun,
    String? user1Moon,
    String? user1Rising,
    String? user2Sun,
    String? user2Moon,
    String? user2Rising,
  }) {
    final card = CosmicVibeShareCard(
      score: score,
      label: label,
      pillars: pillars,
      user1Name: user1Name,
      user2Name: user2Name,
      user1PhotoUrl: user1PhotoUrl,
      user2PhotoUrl: user2PhotoUrl,
      user1Sun: user1Sun,
      user1Moon: user1Moon,
      user1Rising: user1Rising,
      user2Sun: user2Sun,
      user2Moon: user2Moon,
      user2Rising: user2Rising,
    );

    final shareText = ShareTextBuilders.cosmicVibeMatch(score: score);

    AppBottomSheet.show(
      context,
      child: CompatibilityCardPreviewSheet(
        card: card,
        title: 'Cosmic Vibe Match',
        onShare: () {
          Navigator.pop(context);
          ShareMedia.shareWidgetAsImage(
            context: context,
            card: card,
            filePrefix: 'cosmic_vibe',
            shareText: shareText,
            logLabel: 'cosmic vibe card',
          );
        },
      ),
    );
  }

  /// Show Ashtakoot Match card preview before sharing
  static void showAshtakootCardPreview({
    required BuildContext context,
    required double score,
    required int outOf,
    required String label,
    required List<KootaData> kootas,
    required String user1Name,
    required String user2Name,
    String? user1PhotoUrl,
    String? user2PhotoUrl,
  }) {
    final card = AshtakootShareCard(
      score: score,
      outOf: outOf,
      label: label,
      kootas: kootas,
      user1Name: user1Name,
      user2Name: user2Name,
      user1PhotoUrl: user1PhotoUrl,
      user2PhotoUrl: user2PhotoUrl,
    );

    final scoreDisplay =
        score % 1 == 0 ? score.toInt().toString() : score.toStringAsFixed(1);
    final shareText = ShareTextBuilders.ashtakootMatch(
      scoreDisplay: scoreDisplay,
      outOf: outOf,
    );

    AppBottomSheet.show(
      context,
      child: CompatibilityCardPreviewSheet(
        card: card,
        title: 'Ashtakoot Match',
        onShare: () {
          Navigator.pop(context);
          ShareMedia.shareWidgetAsImage(
            context: context,
            card: card,
            filePrefix: 'ashtakoot',
            shareText: shareText,
            logLabel: 'ashtakoot card',
          );
        },
      ),
    );
  }

  /// Show Life Phase Sync card preview before sharing
  static void showLifePhaseCardPreview({
    required BuildContext context,
    required String syncLabel,
    required String user1MahaDasha,
    String? user1AntarDasha,
    required String user1Theme,
    required String user2MahaDasha,
    String? user2AntarDasha,
    required String user2Theme,
    required String insight,
    required String user1Name,
    required String user2Name,
    String? user1PhotoUrl,
    String? user2PhotoUrl,
  }) {
    final card = LifePhaseShareCard(
      syncLabel: syncLabel,
      user1MahaDasha: user1MahaDasha,
      user1AntarDasha: user1AntarDasha,
      user1Theme: user1Theme,
      user2MahaDasha: user2MahaDasha,
      user2AntarDasha: user2AntarDasha,
      user2Theme: user2Theme,
      insight: insight,
      user1Name: user1Name,
      user2Name: user2Name,
      user1PhotoUrl: user1PhotoUrl,
      user2PhotoUrl: user2PhotoUrl,
    );

    final shareText = ShareTextBuilders.lifePhaseSync(syncLabel: syncLabel);

    AppBottomSheet.show(
      context,
      child: CompatibilityCardPreviewSheet(
        card: card,
        title: 'Life Phase Sync',
        onShare: () {
          Navigator.pop(context);
          ShareMedia.shareWidgetAsImage(
            context: context,
            card: card,
            filePrefix: 'life_phase',
            shareText: shareText,
            logLabel: 'life phase card',
          );
        },
      ),
    );
  }

  /// Share an insight (supports both chat sharing and image export)
  static Future<void> shareInsight({
    required BuildContext context,
    required String insightId,
    required String cardType,
    required String title,
    required String content,
    String? userName,
    String? moonSign,
    String? risingSign,
    String? sunSign,
  }) async {
    try {
      // Create chat share content
      final chatContent = ShareableContent(
        type: 'insight',
        id: insightId,
        title: title,
        subtitle: cardType,
        extraData: {
          'cardType': cardType,
          'content': content,
          if (userName != null) 'userName': userName,
          if (moonSign != null) 'moonSign': moonSign,
          if (risingSign != null) 'risingSign': risingSign,
          if (sunSign != null) 'sunSign': sunSign,
        },
      );

      final shareText =
          ShareTextBuilders.insight(cardType: cardType, title: title);

      // Show share options
      await ShareUi.showShareOptions(
        context: context,
        shareText: shareText,
        shareUrl: null, // Insights don't have URLs
        contentType: 'Insight',
        chatShareContent: chatContent,
      );

      AnalyticsService().trackContentShared(
        contentType: 'insight',
        itemId: insightId,
      );
    } catch (e) {
      AppLogger.e('Error sharing insight', error: e);
      ShareUi.showErrorSnackbar(context, 'Failed to share');
    }
  }

  /// Show Insight card preview before sharing
  static void showInsightCardPreview({
    required BuildContext context,
    required String cardType,
    required String title,
    required String content,
    String? userName,
    String? moonSign,
    String? risingSign,
    String? sunSign,
  }) {
    final card = InsightShareCard(
      cardType: cardType,
      title: title,
      content: content,
      userName: userName,
      moonSign: moonSign,
      risingSign: risingSign,
      sunSign: sunSign,
    );

    final shareText =
        ShareTextBuilders.insight(cardType: cardType, title: title);

    AppBottomSheet.show(
      context,
      child: InsightCardPreviewSheet(
        card: card,
        onCopyText: () async {
          await Clipboard.setData(ClipboardData(text: shareText));
          if (context.mounted) {
            Navigator.pop(context);
            ShareUi.showSuccessSnackbar(context, 'Copied to clipboard!');
          }
        },
        onShareCard: () {
          Navigator.pop(context);
          ShareMedia.shareWidgetAsImage(
            context: context,
            card: card,
            filePrefix: 'insight_$cardType',
            shareText: shareText,
            logLabel: 'insight card',
          );
        },
        onAddToStory: () async {
          Navigator.pop(context);
          await addToStoryFromCard(
            context,
            card,
            sourceType: 'insight',
            sourceId: cardType,
          );
        },
      ),
    );
  }

  /// Show cosmic card preview before sharing
  /// User sees the card first, then can tap share
  static void showCosmicCardPreview({
    required BuildContext context,
    required String userId,
    String? userName,
    required String sunSign,
    required String moonSign,
    required String risingSign,
    String? sunNakshatra,
    String? moonNakshatra,
    String? risingNakshatra,
  }) {
    final card = CosmicShareCard(
      userName: userName,
      sunSign: sunSign,
      moonSign: moonSign,
      risingSign: risingSign,
      sunNakshatra: sunNakshatra,
      moonNakshatra: moonNakshatra,
      risingNakshatra: risingNakshatra,
    );

    AppBottomSheet.show(
      context,
      child: CosmicCardPreviewSheet(
        card: card,
        onShare: () {
          Navigator.pop(context);
          final shareUrl = ShareLinks.cosmicProfile(userId);
          final shareText = ShareTextBuilders.cosmicCard(shareUrl: shareUrl);
          ShareMedia.shareWidgetAsImage(
            context: context,
            card: card,
            filePrefix: 'cosmic_profile',
            shareText: shareText,
            logLabel: 'cosmic card',
          );
        },
        onAddToStory: () async {
          Navigator.pop(context);
          await addToStoryFromCard(
            context,
            card,
            sourceType: 'cosmic',
            sourceId: userId,
          );
        },
      ),
    );
  }
}
