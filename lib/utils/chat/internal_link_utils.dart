import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:aurogram/utils/logging/app_logger.dart';

/// Types of internal app links that can be previewed
enum InternalLinkType {
  post,
  profile,
  space,
  cosmic,
  unknown,
}

/// Parsed internal link data
class InternalLink {
  final InternalLinkType type;
  final String id;
  final String originalUrl;

  InternalLink({
    required this.type,
    required this.id,
    required this.originalUrl,
  });
}

/// Preview data for internal links
class InternalLinkPreview {
  final InternalLinkType type;
  final String id;
  final String title;
  final String? subtitle;
  final String? imageUrl;
  final String? authorName;
  final String? authorAvatar;
  final Map<String, dynamic>? extraData;

  InternalLinkPreview({
    required this.type,
    required this.id,
    required this.title,
    this.subtitle,
    this.imageUrl,
    this.authorName,
    this.authorAvatar,
    this.extraData,
  });
}

/// Utility class for detecting and fetching internal app link previews
class InternalLinkUtils {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Cache for link previews to avoid repeated fetches
  static final Map<String, InternalLinkPreview> _previewCache = {};

  // App base URLs and schemes
  static const List<String> _appHosts = [
    'ty-dev-516d7.web.app',
    'aurogram.in', // Production domain
  ];
  static const String _customScheme = 'aurogram';

  /// URL regex pattern for detecting URLs in text
  static final RegExp urlPattern = RegExp(
    r'https?://[^\s<>\[\]]+|aurogram://[^\s<>\[\]]+',
    caseSensitive: false,
  );

  /// Check if a URL is an internal app link
  static bool isInternalLink(String url) {
    try {
      final uri = Uri.parse(url.trim());

      // Check custom scheme
      if (uri.scheme == _customScheme) {
        return true;
      }

      // Check app hosts
      if (_appHosts.contains(uri.host)) {
        return true;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  /// Parse an internal link to extract type and ID
  static InternalLink? parseInternalLink(String url) {
    try {
      final uri = Uri.parse(url.trim());
      String? type;
      String? id;

      if (uri.scheme == _customScheme) {
        // aurogram://type/id - host is the type
        type = uri.host;
        id = uri.pathSegments.isNotEmpty ? uri.pathSegments[0] : null;
      } else if (_appHosts.contains(uri.host)) {
        // https://domain/type/id
        if (uri.pathSegments.length >= 2) {
          type = uri.pathSegments[0];
          id = uri.pathSegments[1];
        }
      }

      if (type == null || id == null || id.isEmpty) {
        return null;
      }

      final linkType = _parseType(type);
      if (linkType == InternalLinkType.unknown) {
        return null;
      }

      return InternalLink(
        type: linkType,
        id: id,
        originalUrl: url,
      );
    } catch (e) {
      AppLogger.w('Failed to parse internal link: $url',
          category: LogCategory.general, data: {'error': e.toString()});
      return null;
    }
  }

  static InternalLinkType _parseType(String type) {
    switch (type.toLowerCase()) {
      case 'p':
      case 'post':
        return InternalLinkType.post;
      case 'u':
      case 'user':
      case 'profile':
        return InternalLinkType.profile;
      case 's':
      case 'space':
      case 'gram':
        return InternalLinkType.space;
      case 'cosmic':
      case 'compatibility':
        return InternalLinkType.cosmic;
      default:
        return InternalLinkType.unknown;
    }
  }

  /// Extract all URLs from text
  static List<String> extractUrls(String text) {
    return urlPattern.allMatches(text).map((m) => m.group(0)!).toList();
  }

  /// Extract the first internal link from text (for preview)
  static InternalLink? extractFirstInternalLink(String text) {
    final urls = extractUrls(text);
    for (final url in urls) {
      if (isInternalLink(url)) {
        final link = parseInternalLink(url);
        if (link != null) return link;
      }
    }
    return null;
  }

  /// Fetch preview data for an internal link
  /// Times out after 5 seconds to prevent hanging
  static Future<InternalLinkPreview?> fetchPreview(InternalLink link) async {
    // Check cache first
    final cacheKey = '${link.type.name}_${link.id}';
    if (_previewCache.containsKey(cacheKey)) {
      return _previewCache[cacheKey];
    }

    try {
      InternalLinkPreview? preview;

      // Wrap in timeout to prevent hanging
      final fetchFuture = switch (link.type) {
        InternalLinkType.post => _fetchPostPreview(link.id),
        InternalLinkType.profile => _fetchProfilePreview(link.id),
        InternalLinkType.space => _fetchSpacePreview(link.id),
        InternalLinkType.cosmic => _fetchCosmicPreview(link.id),
        InternalLinkType.unknown => Future.value(null),
      };

      preview = await fetchFuture.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          AppLogger.w('Link preview fetch timed out',
              category: LogCategory.general,
              data: {'type': link.type.name, 'id': link.id});
          return null;
        },
      );

      // Cache the result
      if (preview != null) {
        _previewCache[cacheKey] = preview;
      }

      return preview;
    } catch (e) {
      AppLogger.w('Failed to fetch link preview',
          category: LogCategory.general,
          data: {'type': link.type.name, 'id': link.id, 'error': e.toString()});
      return null;
    }
  }

  static Future<InternalLinkPreview?> _fetchPostPreview(String postId) async {
    final doc = await _firestore.collection('posts').doc(postId).get();
    if (!doc.exists) return null;

    final data = doc.data()!;
    final postType = data['postType'] as String? ?? 'text';

    String? imageUrl;
    if (postType == 'video') {
      imageUrl = data['thumbnail'] as String?;
    }

    return InternalLinkPreview(
      type: InternalLinkType.post,
      id: postId,
      title: data['title'] as String? ?? 'Post',
      subtitle: _truncateText(data['content'] as String?, 100),
      imageUrl: imageUrl,
      authorName: data['authorName'] as String?,
      authorAvatar: data['authorAvatar'] as String?,
      extraData: {
        'postType': postType,
        'likeCount': data['likeCount'] ?? 0,
        'replyCount': data['replyCount'] ?? 0,
      },
    );
  }

  static Future<InternalLinkPreview?> _fetchProfilePreview(
      String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    if (!doc.exists) return null;

    final data = doc.data()!;

    return InternalLinkPreview(
      type: InternalLinkType.profile,
      id: userId,
      title: data['name'] as String? ?? data['nickname'] as String? ?? 'User',
      subtitle: data['bio'] as String?,
      imageUrl: data['avatar'] as String? ?? data['photoURL'] as String?,
      extraData: {
        'followerCount': data['followerCount'] ?? 0,
        'followingCount': data['followingCount'] ?? 0,
      },
    );
  }

  static Future<InternalLinkPreview?> _fetchSpacePreview(String spaceId) async {
    final doc = await _firestore.collection('spaces').doc(spaceId).get();
    if (!doc.exists) return null;

    final data = doc.data()!;

    return InternalLinkPreview(
      type: InternalLinkType.space,
      id: spaceId,
      title: data['name'] as String? ?? 'Space',
      subtitle: data['description'] as String?,
      imageUrl: data['displayPicture'] as String? ?? data['image'] as String?,
      extraData: {
        'memberCount': data['memberCount'] ?? 0,
        'spaceType': data['spaceType'] ?? 0,
      },
    );
  }

  static Future<InternalLinkPreview?> _fetchCosmicPreview(String userId) async {
    // Cosmic links show user profile with compatibility context
    final preview = await _fetchProfilePreview(userId);
    if (preview == null) return null;

    return InternalLinkPreview(
      type: InternalLinkType.cosmic,
      id: userId,
      title: preview.title,
      subtitle: 'Check cosmic compatibility',
      imageUrl: preview.imageUrl,
      extraData: preview.extraData,
    );
  }

  static String? _truncateText(String? text, int maxLength) {
    if (text == null || text.isEmpty) return null;
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  /// Clear the preview cache
  static void clearCache() {
    _previewCache.clear();
  }
}
