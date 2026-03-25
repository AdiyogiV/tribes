import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/utils/chat/external_link_utils.dart';

/// Link preview card shown above input when URL is detected
class InputLinkPreview extends StatelessWidget {
  final ExternalLinkPreview? preview;
  final bool isLoading;
  final bool isDark;
  final VoidCallback onDismiss;

  const InputLinkPreview({
    super.key,
    required this.preview,
    required this.isLoading,
    required this.isDark,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        decoration: BoxDecoration(
          color: isDark
              ? AppTheme.cardDarkColor.withValues(alpha: 0.95)
              : Colors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.primaryColor.withValues(alpha: 0.15),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: isLoading ? _buildLoadingState() : _buildPreviewContent(),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(
                AppTheme.primaryColor.withValues(alpha: 0.5),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Loading preview...',
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.primaryColor.withValues(alpha: 0.5),
            ),
          ),
          const Spacer(),
          _buildDismissButton(),
        ],
      ),
    );
  }

  Widget _buildPreviewContent() {
    final p = preview;
    if (p == null) return const SizedBox.shrink();

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Thumbnail (if available)
          if (p.image != null)
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(11),
                bottomLeft: Radius.circular(11),
              ),
              child: SizedBox(
                width: 72,
                child: CachedNetworkImage(
                  imageUrl: p.image!,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    child: Icon(
                      CupertinoIcons.link,
                      color: AppTheme.primaryColor.withValues(alpha: 0.3),
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
          // Content
          Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                p.image != null ? 10 : 12,
                10,
                8,
                10,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Site name
                  Text(
                    p.siteName.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryColor.withValues(alpha: 0.4),
                      letterSpacing: 0.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  // Title
                  Text(
                    p.title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryColor.withValues(alpha: 0.85),
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
          // Dismiss button
          Padding(
            padding: const EdgeInsets.only(right: 4, top: 4),
            child: _buildDismissButton(),
          ),
        ],
      ),
    );
  }

  Widget _buildDismissButton() {
    return GestureDetector(
      onTap: onDismiss,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppTheme.primaryColor.withValues(alpha: 0.08),
        ),
        child: Icon(
          Icons.close_rounded,
          color: AppTheme.primaryColor.withValues(alpha: 0.5),
          size: 16,
        ),
      ),
    );
  }
}
