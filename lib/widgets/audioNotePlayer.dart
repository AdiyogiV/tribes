import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/utils/media_type_selector.dart';
import 'package:aurogram/widgets/postHeader.dart';
import 'package:aurogram/widgets/Dialogs/login_bottom_sheet.dart';
import 'package:aurogram/widgets/Dialogs/postDailog.dart';
import 'package:aurogram/widgets/ui/skeleton_widgets.dart';
import 'package:aurogram/services/database_service.dart';
import 'package:aurogram/services/auth_service.dart';
import 'package:aurogram/services/data/post_db_service.dart';
import 'package:aurogram/utils/logging/app_logger.dart';

/// Clean audio player matching TransparentToolbox style
/// - Card with elevation 4
/// - Audio controls area with its own elevation
/// - All text in primary color
class AudioNotePlayer extends StatefulWidget {
  final String? author;
  final String? space;
  final String audioUrl;
  final int durationInSeconds;
  final String? postId;
  final String? title;
  final Timestamp? timestamp;
  final String? label;
  final Color? labelColor;
  final bool hasContentBelow;
  final bool isProfilePost;

  const AudioNotePlayer({
    Key? key,
    this.postId,
    this.space,
    this.author,
    required this.audioUrl,
    required this.durationInSeconds,
    this.title,
    this.timestamp,
    this.label,
    this.labelColor,
    this.hasContentBelow = false,
    this.isProfilePost = false,
  }) : super(key: key);

  @override
  State<AudioNotePlayer> createState() => _AudioNotePlayerState();
}

class _AudioNotePlayerState extends State<AudioNotePlayer>
    with TickerProviderStateMixin {
  late AudioPlayer _audioPlayer;
  bool _isVisible = false;
  bool _isPlaying = false;
  bool _isLoading = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;

  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;
  StreamSubscription<PlayerState>? _playerStateSub;

  late AnimationController _pulseController;

  // Counters
  int _likeCount = 0;
  int _replyCount = 0;
  bool _isLiked = false;

  @override
  void initState() {
    super.initState();
    _initPlayer();
    _loadCounters();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
  }

  Future<void> _loadCounters() async {
    if (widget.postId == null) return;
    try {
      final db = DatabaseService();
      final replies = await db.getPostReplies(widget.postId!);
      final likes = await db.getLikeCount(widget.postId!);
      final isLiked = await db.isPostLikedByUser(widget.postId);
      if (mounted) {
        setState(() {
          _replyCount = replies.docs.length;
          _likeCount = likes;
          _isLiked = isLiked;
        });
      }
    } catch (_) {}
  }

  void _initPlayer() async {
    _audioPlayer = AudioPlayer();
    _totalDuration = Duration(seconds: widget.durationInSeconds);

    try {
      await _audioPlayer.setUrl(widget.audioUrl);

      _positionSub = _audioPlayer.positionStream.listen((pos) {
        if (mounted) setState(() => _currentPosition = pos);
      });

      _durationSub = _audioPlayer.durationStream.listen((dur) {
        if (mounted && dur != null) setState(() => _totalDuration = dur);
      });

      _playerStateSub = _audioPlayer.playerStateStream.listen((state) {
        if (!mounted) return;
        setState(() {
          _isPlaying = state.playing;
          _isLoading = state.processingState == ProcessingState.loading;
        });

        if (_isPlaying) {
          _pulseController.repeat(reverse: true);
        } else {
          _pulseController.stop();
          _pulseController.reset();
        }

        if (state.processingState == ProcessingState.completed) {
          _audioPlayer.seek(Duration.zero);
          _audioPlayer.stop();
        }
      });
    } catch (e) {
      AppLogger.e('Audio player init failed', error: e);
    }
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _durationSub?.cancel();
    _playerStateSub?.cancel();
    _pulseController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _handleVisibility(VisibilityInfo info) {
    if (!mounted) return;
    final nowVisible = info.visibleFraction > 0.7;
    if (_isVisible != nowVisible) setState(() => _isVisible = nowVisible);
    if (nowVisible && widget.postId != null) {
      DatabaseService().markPostAsSeen(widget.postId);
    }
    if (!nowVisible && _isPlaying) _audioPlayer.pause();
  }

  void _togglePlayback() async {
    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
      } else {
        await _audioPlayer.play();
      }
    } catch (e) {
      AppLogger.e('Playback toggle failed', error: e);
    }
  }

  void _seekTo(double value) {
    final pos = Duration(seconds: (value * _totalDuration.inSeconds).round());
    _audioPlayer.seek(pos);
  }

  void _toggleLike() {
    final auth = Provider.of<AuthService>(context, listen: false);
    if (auth.status != Status.Authenticated) {
      _showLoginDialog();
      return;
    }
    if (widget.postId == null) return;
    setState(() {
      _isLiked = !_isLiked;
      _likeCount += _isLiked ? 1 : -1;
    });
    DatabaseService().likePost(widget.postId!);
  }

  void _openReply() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    if (auth.status != Status.Authenticated) {
      _showLoginDialog();
      return;
    }
    if (widget.postId == null) return;

    final postDbService = PostDbService();
    String? space = await postDbService.getPostSpace(widget.postId!);

    if (mounted) {
      MediaTypeSelector.showMediaTypeSelection(
        context: context,
        space: space ?? widget.space ?? '',
        replyTo: widget.postId,
      );
    }
  }

  void _showMoreOptions() {
    showCupertinoModalPopup(
      context: context,
      builder: (_) => PostDialog(
        post: widget.postId,
        author: widget.author,
      ),
    );
  }

  void _showLoginDialog() {
    showLoginBottomSheet(context);
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Card styling (background, border radius, shadow) handled by parent (PostSwitcher)
    return VisibilityDetector(
      key: ValueKey('audio_${widget.postId}'),
      onVisibilityChanged: _handleVisibility,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              PostHeader(
                uid: widget.author,
                space: widget.space,
                timestamp: widget.timestamp,
                isProfilePost: widget.isProfilePost,
                label: widget.label,
                labelColor: widget.labelColor,
              ),

              const SizedBox(height: 10),

              // Audio controls area with elevation
              Material(
                color: isDark ? const Color(0xFF1A2535) : const Color(0xFFE8F2FC),
                elevation: 2,
                shadowColor: Colors.black.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Type badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.mic, size: 14, color: AppTheme.primaryColor),
                            const SizedBox(width: 6),
                            Text(
                              'Voice',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Title
                      if (widget.title != null && widget.title!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          widget.title!,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryColor,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],

                      const SizedBox(height: 16),

                      // Play button
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          final scale = _isPlaying ? 1.0 + (_pulseController.value * 0.08) : 1.0;
                          return Transform.scale(
                            scale: scale,
                            child: GestureDetector(
                              onTap: _togglePlayback,
                              child: Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppTheme.primaryColor,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.primaryColor.withValues(alpha: 0.3),
                                      blurRadius: 16,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: _isLoading
                                    ? const Padding(
                                        padding: EdgeInsets.all(20),
                                        child: PulsingDots(color: Colors.white, size: 8),
                                      )
                                    : Icon(
                                        _isPlaying ? Icons.pause : Icons.play_arrow,
                                        color: Colors.white,
                                        size: 32,
                                      ),
                              ),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 16),

                      // Progress bar
                      Row(
                        children: [
                          Text(
                            _formatDuration(_currentPosition),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: SliderTheme(
                                data: SliderThemeData(
                                  trackHeight: 4,
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                                  activeTrackColor: AppTheme.primaryColor,
                                  inactiveTrackColor: AppTheme.primaryColor.withValues(alpha: 0.2),
                                  thumbColor: AppTheme.primaryColor,
                                  overlayColor: AppTheme.primaryColor.withValues(alpha: 0.15),
                                ),
                                child: Slider(
                                  value: _totalDuration.inMilliseconds > 0
                                      ? (_currentPosition.inMilliseconds / _totalDuration.inMilliseconds).clamp(0.0, 1.0)
                                      : 0.0,
                                  onChanged: _seekTo,
                                ),
                              ),
                            ),
                          ),
                          Text(
                            _formatDuration(_totalDuration),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // Toolbar
              Row(
                children: [
                  _ToolbarButton(
                    icon: _isLiked ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                    label: _likeCount > 0 ? _formatCount(_likeCount) : null,
                    isActive: _isLiked,
                    onTap: _toggleLike,
                  ),
                  const SizedBox(width: 16),
                  _ToolbarButton(
                    icon: Icons.reply_outlined,
                    label: _replyCount > 0 ? _formatCount(_replyCount) : null,
                    onTap: _openReply,
                  ),
                  const Spacer(),
                  _ToolbarButton(icon: CupertinoIcons.ellipsis, onTap: _showMoreOptions),
                ],
              ),
            ],
          ),
        ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String? label;
  final bool isActive;
  final VoidCallback onTap;

  const _ToolbarButton({
    required this.icon,
    this.label,
    this.isActive = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppTheme.barnRed : AppTheme.primaryColor;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: color),
            if (label != null) ...[
              const SizedBox(width: 6),
              Text(
                label!,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
