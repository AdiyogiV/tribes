import 'package:flutter/foundation.dart';
import 'package:metadata_fetch/metadata_fetch.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'internal_link_utils.dart';

/// Preview data for external links (from Open Graph)
class ExternalLinkPreview {
  final String url;
  final String title;
  final String? description;
  final String? image;
  final String siteName;
  final String? favicon;
  final String type;

  ExternalLinkPreview({
    required this.url,
    required this.title,
    this.description,
    this.image,
    required this.siteName,
    this.favicon,
    required this.type,
  });

  factory ExternalLinkPreview.fromMetadata(Metadata metadata, String url) {
    // Extract domain from URL for site name
    String siteName = 'Link';
    try {
      final uri = Uri.parse(url);
      siteName = uri.host.replaceFirst('www.', '');
    } catch (_) {
      AppLogger.w('ExternalLinkPreview: failed to parse URL domain', category: LogCategory.general);
    }

    return ExternalLinkPreview(
      url: url,
      title: metadata.title ?? siteName,
      description: metadata.description,
      image: metadata.image,
      siteName: siteName,
      favicon: null, // metadata_fetch doesn't provide favicon
      type: 'link',
    );
  }

  /// Create from a JSON map (e.g. cached or serialised preview data).
  factory ExternalLinkPreview.fromJson(Map<String, dynamic> json) {
    return ExternalLinkPreview(
      url: json['url'] ?? '',
      title: json['title'] ?? 'Link',
      description: json['description'],
      image: json['image'],
      siteName: json['siteName'] ?? 'Link',
      favicon: json['favicon'],
      type: json['type'] ?? 'link',
    );
  }

  /// Create from Cloud Function response (for web)
  factory ExternalLinkPreview.fromCloudFunction(Map<String, dynamic> data, String url) {
    return ExternalLinkPreview(
      url: url,
      title: data['title'] ?? 'Link',
      description: data['description'],
      image: data['image'],
      siteName: data['siteName'] ?? 'Link',
      favicon: data['favicon'],
      type: data['type'] ?? 'link',
    );
  }
}

/// Utility class for external link preview fetching
class ExternalLinkUtils {
  // Cache for external link previews
  static final Map<String, ExternalLinkPreview> _previewCache = {};
  static final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheDuration = Duration(hours: 24);
  
  // Track failed URLs to avoid repeated attempts
  static final Set<String> _failedUrls = {};

  /// URL regex pattern for detecting URLs in text
  static final RegExp urlPattern = RegExp(
    r'https?://[^\s<>\[\]]+',
    caseSensitive: false,
  );

  /// Extract all URLs from text
  static List<String> extractUrls(String text) {
    return urlPattern.allMatches(text).map((m) => m.group(0)!).toList();
  }

  /// Check if URL is external (not an internal app link)
  static bool isExternalLink(String url) {
    return !InternalLinkUtils.isInternalLink(url);
  }

  /// Extract first external link from text
  static String? extractFirstExternalLink(String text) {
    final urls = extractUrls(text);
    for (final url in urls) {
      if (isExternalLink(url)) {
        return url;
      }
    }
    return null;
  }

  /// Fetch preview for an external URL
  /// On web: Uses Cloud Function to bypass CORS
  /// On mobile: Uses direct metadata_fetch package
  static Future<ExternalLinkPreview?> fetchPreview(String url) async {
    // Normalize URL for cache key
    final cacheKey = url.toLowerCase().trim();

    // Check cache first
    if (_previewCache.containsKey(cacheKey)) {
      final timestamp = _cacheTimestamps[cacheKey];
      if (timestamp != null &&
          DateTime.now().difference(timestamp) < _cacheDuration) {
        return _previewCache[cacheKey];
      }
    }
    
    // Skip URLs that previously failed
    if (_failedUrls.contains(cacheKey)) {
      return null;
    }

    try {
      ExternalLinkPreview? preview;
      
      if (kIsWeb) {
        // Web: Use Cloud Function to avoid CORS
        preview = await _fetchViaCloudFunction(url);
      } else {
        // Mobile: Use direct client-side fetch
        preview = await _fetchDirect(url);
      }
      
      if (preview == null) {
        _failedUrls.add(cacheKey);
        return null;
      }

      // Cache the result
      _previewCache[cacheKey] = preview;
      _cacheTimestamps[cacheKey] = DateTime.now();

      return preview;
    } catch (e) {
      AppLogger.w('🔗 Error fetching link preview',
          category: LogCategory.general,
          data: {'url': url, 'error': e.toString(), 'isWeb': kIsWeb});
      _failedUrls.add(cacheKey);
    }

    return null;
  }

  /// Fetch preview via Cloud Function (for web to bypass CORS)
  static Future<ExternalLinkPreview?> _fetchViaCloudFunction(String url) async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('getLinkPreview');
      final result = await callable.call({'url': url});
      
      if (result.data == null) {
        return null;
      }
      
      final data = Map<String, dynamic>.from(result.data);
      final preview = ExternalLinkPreview.fromCloudFunction(data, url);
      
      AppLogger.i('🔗 Link preview fetched via Cloud Function',
          category: LogCategory.general,
          data: {
            'url': url,
            'title': preview.title,
            'hasImage': preview.image != null,
          });
      
      return preview;
    } catch (e) {
      AppLogger.w('🔗 Cloud Function error fetching link preview',
          category: LogCategory.general,
          data: {'url': url, 'error': e.toString()});
      return null;
    }
  }

  /// Fetch preview directly using metadata_fetch (for mobile)
  static Future<ExternalLinkPreview?> _fetchDirect(String url) async {
    try {
      final metadata = await MetadataFetch.extract(url);
      
      if (metadata == null) {
        return null;
      }

      final preview = ExternalLinkPreview.fromMetadata(metadata, url);
      
      AppLogger.i('🔗 Link preview fetched directly',
          category: LogCategory.general,
          data: {
            'url': url,
            'title': preview.title,
            'hasImage': preview.image != null,
          });

      return preview;
    } catch (e) {
      AppLogger.w('🔗 Error fetching link preview directly',
          category: LogCategory.general,
          data: {'url': url, 'error': e.toString()});
      return null;
    }
  }

  /// Clear the preview cache
  static void clearCache() {
    _previewCache.clear();
    _cacheTimestamps.clear();
    _failedUrls.clear();
  }
}
