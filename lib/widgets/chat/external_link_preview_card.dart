import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/utils/chat/external_link_utils.dart';
import 'package:aurogram/widgets/ui/skeleton_widgets.dart';

/// A card widget that displays external link previews with Open Graph data
class ExternalLinkPreviewCard extends StatelessWidget {
  final ExternalLinkPreview preview;
  final bool isOwnMessage;
  final bool compact;

  const ExternalLinkPreviewCard({
    super.key,
    required this.preview,
    required this.isOwnMessage,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => _launchUrl(preview.url),
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        decoration: BoxDecoration(
          color: isOwnMessage
              ? Colors.white.withValues(alpha: 0.12)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.03)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isOwnMessage
                ? Colors.white.withValues(alpha: 0.15)
                : (isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.06)),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child:
            compact ? _buildCompactLayout(context) : _buildFullLayout(context),
      ),
    );
  }

  Widget _buildFullLayout(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Image if available
        if (preview.image != null)
          AspectRatio(
            aspectRatio: 1.91, // Standard OG image ratio
            child: CachedNetworkImage(
              imageUrl: preview.image!,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                color: isDark ? Colors.grey[800] : Colors.grey[200],
                child: Center(
                  child: Icon(
                    Icons.image_outlined,
                    color: isDark ? Colors.grey[600] : Colors.grey[400],
                    size: 32,
                  ),
                ),
              ),
              errorWidget: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),

        // Content
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Site name with favicon
              Row(
                children: [
                  if (preview.favicon != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: CachedNetworkImage(
                          imageUrl: preview.favicon!,
                          width: 14,
                          height: 14,
                          errorWidget: (_, __, ___) => Icon(
                            Icons.language,
                            size: 14,
                            color: isOwnMessage
                                ? Colors.white.withValues(alpha: 0.6)
                                : AppTheme.primaryColor.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    ),
                  Expanded(
                    child: Text(
                      preview.siteName.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                        color: isOwnMessage
                            ? Colors.white.withValues(alpha: 0.6)
                            : (isDark ? Colors.grey[500] : Colors.grey[600]),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    Icons.open_in_new_rounded,
                    size: 12,
                    color: isOwnMessage
                        ? Colors.white.withValues(alpha: 0.4)
                        : (isDark ? Colors.grey[600] : Colors.grey[400]),
                  ),
                ],
              ),

              const SizedBox(height: 6),

              // Title
              Text(
                preview.title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isOwnMessage
                      ? Colors.white
                      : AppTheme.primaryColor,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              // Description
              if (preview.description != null) ...[
                const SizedBox(height: 4),
                Text(
                  preview.description!,
                  style: TextStyle(
                    fontSize: 12,
                    color: isOwnMessage
                        ? Colors.white.withValues(alpha: 0.7)
                        : (isDark ? Colors.grey[400] : Colors.grey[600]),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCompactLayout(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          // Thumbnail or icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isOwnMessage
                  ? Colors.white.withValues(alpha: 0.15)
                  : AppTheme.primaryColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            clipBehavior: Clip.antiAlias,
            child: preview.image != null
                ? CachedNetworkImage(
                    imageUrl: preview.image!,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Icon(
                      Icons.language,
                      color: isOwnMessage
                          ? Colors.white.withValues(alpha: 0.6)
                          : AppTheme.primaryColor,
                    ),
                  )
                : Icon(
                    Icons.language,
                    color: isOwnMessage
                        ? Colors.white.withValues(alpha: 0.6)
                        : AppTheme.primaryColor,
                  ),
          ),

          const SizedBox(width: 10),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  preview.siteName,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: isOwnMessage
                        ? Colors.white.withValues(alpha: 0.6)
                        : (isDark ? Colors.grey[500] : Colors.grey[600]),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  preview.title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isOwnMessage ? Colors.white : AppTheme.primaryColor,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          Icon(
            Icons.chevron_right,
            size: 18,
            color: isOwnMessage
                ? Colors.white.withValues(alpha: 0.4)
                : (isDark ? Colors.grey[600] : Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      // Ignore launch errors
    }
  }
}

/// Loading placeholder for external link preview
class ExternalLinkPreviewLoading extends StatelessWidget {
  final bool isOwnMessage;

  const ExternalLinkPreviewLoading({
    super.key,
    required this.isOwnMessage,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isOwnMessage
            ? Colors.white.withValues(alpha: 0.12)
            : (isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.03)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const ShimmerImagePlaceholder(
            width: 48,
            height: 48,
            borderRadius: 8,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                ShimmerImagePlaceholder(
                  width: 60,
                  height: 10,
                  borderRadius: 4,
                ),
                SizedBox(height: 6),
                ShimmerImagePlaceholder(
                  width: double.infinity,
                  height: 14,
                  borderRadius: 4,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Builder widget that fetches and displays external link preview
class ExternalLinkPreviewBuilder extends StatefulWidget {
  final String url;
  final bool isOwnMessage;
  final bool compact;

  const ExternalLinkPreviewBuilder({
    super.key,
    required this.url,
    required this.isOwnMessage,
    this.compact = false,
  });

  @override
  State<ExternalLinkPreviewBuilder> createState() =>
      _ExternalLinkPreviewBuilderState();
}

class _ExternalLinkPreviewBuilderState
    extends State<ExternalLinkPreviewBuilder> {
  ExternalLinkPreview? _preview;
  bool _isLoading = true;
  bool _hasFailed = false;
  String? _loadedUrl; // Track which URL was loaded

  @override
  void initState() {
    super.initState();
    _fetchPreview();
  }

  @override
  void didUpdateWidget(ExternalLinkPreviewBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // If URL changed, refetch
    if (oldWidget.url != widget.url) {
      _preview = null;
      _isLoading = true;
      _hasFailed = false;
      _loadedUrl = null;
      _fetchPreview();
    }
  }

  Future<void> _fetchPreview() async {
    final urlToFetch = widget.url;
    
    try {
      final preview = await ExternalLinkUtils.fetchPreview(urlToFetch);
      
      // Check if widget is still mounted and URL hasn't changed
      if (!mounted || widget.url != urlToFetch) return;
      
      setState(() {
        _preview = preview;
        _isLoading = false;
        _hasFailed = preview == null;
        _loadedUrl = urlToFetch;
      });
    } catch (e) {
      if (!mounted || widget.url != urlToFetch) return;
      
      setState(() {
        _isLoading = false;
        _hasFailed = true;
        _loadedUrl = urlToFetch;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return ExternalLinkPreviewLoading(isOwnMessage: widget.isOwnMessage);
    }

    // Don't show anything if we couldn't fetch metadata
    if (_hasFailed || _preview == null) {
      return const SizedBox.shrink();
    }
    
    // Safety check: make sure loaded URL matches widget URL
    if (_loadedUrl != widget.url) {
      return ExternalLinkPreviewLoading(isOwnMessage: widget.isOwnMessage);
    }

    return ExternalLinkPreviewCard(
      preview: _preview!,
      isOwnMessage: widget.isOwnMessage,
      compact: widget.compact,
    );
  }
}
