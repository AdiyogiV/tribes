import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:aurogram/services/chat/space_chat_service.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/utils/responsive.dart';
import 'package:aurogram/widgets/ui/skeleton_widgets.dart';
import 'fullscreen_image_viewer.dart';
import 'package:aurogram/utils/theme/app_dimensions.dart';
import 'package:aurogram/widgets/common/snack_bar_service.dart';

/// A page that displays all media (images, videos, files) shared in a chat
class MediaGalleryPage extends StatefulWidget {
  final String spaceId;
  final String title;

  const MediaGalleryPage({
    super.key,
    required this.spaceId,
    required this.title,
  });

  @override
  State<MediaGalleryPage> createState() => _MediaGalleryPageState();
}

class _MediaGalleryPageState extends State<MediaGalleryPage>
    with SingleTickerProviderStateMixin {
  final SpaceChatService _chatService = SpaceChatService();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.surfaceDarkColor : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? AppTheme.surfaceDarkColor : Colors.white,
        elevation: 0,
        title: Text(
          'Media',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_rounded,
            color: isDark ? Colors.white : Colors.black87,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: isDark ? Colors.grey[500] : Colors.grey[600],
          indicatorColor: AppTheme.primaryColor,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'Photos'),
            Tab(text: 'Videos'),
            Tab(text: 'Files'),
          ],
        ),
      ),
      body: StreamBuilder<List<ChatMessage>>(
        stream: _chatService.getMediaMessages(widget.spaceId, limit: 100),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _MediaGalleryLoading();
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: AppDimensions.spacingLg),
                  Text(
                    'Failed to load media',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          }

          final allMedia = snapshot.data ?? [];
          final images =
              allMedia.where((m) => m.messageType == 'image').toList();
          final videos =
              allMedia.where((m) => m.messageType == 'video').toList();
          final files = allMedia
              .where((m) => m.messageType == 'file' || m.messageType == 'audio')
              .toList();

          return TabBarView(
            controller: _tabController,
            children: [
              _buildImageGrid(images),
              _buildVideoGrid(videos),
              _buildFileList(files),
            ],
          );
        },
      ),
    );
  }

  Widget _buildImageGrid(List<ChatMessage> images) {
    if (images.isEmpty) {
      return _buildEmptyState('No photos shared yet', Icons.photo_outlined);
    }

    final crossAxisCount = Responsive.gridColumns(context);

    return GridView.builder(
      padding: const EdgeInsets.all(2),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: images.length,
      itemBuilder: (context, index) {
        final message = images[index];
        return _MediaGridItem(
          message: message,
          onTap: () => FullscreenImageViewer.show(context, message.mediaUrl!),
        );
      },
    );
  }

  Widget _buildVideoGrid(List<ChatMessage> videos) {
    if (videos.isEmpty) {
      return _buildEmptyState('No videos shared yet', Icons.videocam_outlined);
    }

    final crossAxisCount = Responsive.gridColumns(context);

    return GridView.builder(
      padding: const EdgeInsets.all(2),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: videos.length,
      itemBuilder: (context, index) {
        final message = videos[index];
        return _MediaGridItem(
          message: message,
          isVideo: true,
          onTap: () {
            // TODO: Navigate to video player
            showCustomSnackBar(context, message: 'Video player coming soon', duration: const Duration(seconds: 2));
          },
        );
      },
    );
  }

  Widget _buildFileList(List<ChatMessage> files) {
    if (files.isEmpty) {
      return _buildEmptyState('No files shared yet', Icons.folder_outlined);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppDimensions.paddingLg),
      itemCount: files.length,
      itemBuilder: (context, index) {
        final message = files[index];
        return _FileListItem(message: message);
      },
    );
  }

  Widget _buildEmptyState(String text, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: isDark ? Colors.grey[700] : Colors.grey[300],
          ),
          const SizedBox(height: AppDimensions.spacingLg),
          Text(
            text,
            style: TextStyle(
              color: isDark ? Colors.grey[500] : Colors.grey[600],
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class _MediaGridItem extends StatelessWidget {
  final ChatMessage message;
  final bool isVideo;
  final VoidCallback onTap;

  const _MediaGridItem({
    required this.message,
    this.isVideo = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl =
        isVideo ? (message.thumbnailUrl ?? message.mediaUrl) : message.mediaUrl;

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (imageUrl != null)
            CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[800]
                    : Colors.grey[200],
              ),
              errorWidget: (_, __, ___) => Container(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[800]
                    : Colors.grey[200],
                child: Icon(
                  Icons.broken_image,
                  color: Colors.grey[500],
                ),
              ),
            )
          else
            Container(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey[800]
                  : Colors.grey[200],
              child: Icon(
                isVideo ? Icons.videocam : Icons.image,
                color: Colors.grey[500],
              ),
            ),
          if (isVideo)
            Center(
              child: Container(
                padding: const EdgeInsets.all(AppDimensions.paddingSm),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FileListItem extends StatelessWidget {
  final ChatMessage message;

  const _FileListItem({required this.message});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAudio = message.messageType == 'audio';

    String sizeText = '';
    if (message.fileSize != null) {
      final kb = message.fileSize! / 1024;
      if (kb > 1024) {
        sizeText = '${(kb / 1024).toStringAsFixed(1)} MB';
      } else {
        sizeText = '${kb.toStringAsFixed(1)} KB';
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.paddingSm),
      padding: const EdgeInsets.all(AppDimensions.paddingMd),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100],
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppDimensions.radiusMdSm),
            ),
            child: Icon(
              isAudio ? Icons.mic_rounded : Icons.insert_drive_file_rounded,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(width: AppDimensions.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isAudio ? 'Voice Message' : 'File',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                if (sizeText.isNotEmpty)
                  Text(
                    sizeText,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[500] : Colors.grey[600],
                    ),
                  ),
              ],
            ),
          ),
          Text(
            _formatDate(message.timestamp),
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey[500] : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'Today';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

class _MediaGalleryLoading extends StatelessWidget {
  const _MediaGalleryLoading();

  @override
  Widget build(BuildContext context) {
    final crossAxisCount = Responsive.gridColumns(context);

    return GridView.builder(
      padding: const EdgeInsets.all(2),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: 12,
      itemBuilder: (context, index) {
        return const ShimmerImagePlaceholder(
          width: double.infinity,
          height: double.infinity,
          borderRadius: 0,
        );
      },
    );
  }
}
