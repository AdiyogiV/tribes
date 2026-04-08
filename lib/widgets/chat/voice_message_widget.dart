import 'package:aurogram/utils/theme/app_dimensions.dart';
import 'dart:async';
import 'package:aurogram/widgets/ui/common_widgets.dart';
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/utils/logging/app_logger.dart';

// Conditional imports for platform-specific file operations
import 'voice_message_widget_stub.dart'
    if (dart.library.io) 'voice_message_widget_io.dart' as platform_io;

class VoiceMessageWidget extends StatefulWidget {
  final String transcript;
  final String audioUrl;
  final int durationInSeconds;
  final bool isUserMessage;
  final EdgeInsets? padding;
  
  /// When true, shows upload progress spinner instead of play button
  final bool isSending;
  
  /// Callback for retry when upload fails
  final VoidCallback? onRetry;

  const VoiceMessageWidget({
    super.key,
    required this.transcript,
    required this.audioUrl,
    required this.durationInSeconds,
    this.isUserMessage = false,
    this.padding,
    this.isSending = false,
    this.onRetry,
  });

  @override
  State<VoiceMessageWidget> createState() => _VoiceMessageWidgetState();
}

class _VoiceMessageWidgetState extends State<VoiceMessageWidget>
    with SingleTickerProviderStateMixin {
  AudioPlayer? _audioPlayer;
  bool _isPlaying = false;
  bool _isLoading = false;
  bool _userInitiatedLoad = false; // Track if loading was user-initiated
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;
  StreamSubscription<PlayerState>? _playerStateSubscription;
  
  // Waveform bars - generated once per widget
  late List<double> _waveformBars;
  static const int _barCount = 28;
  
  // Animation controller for play button pulse
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    
    // Generate waveform bars based on audio URL hash for consistency
    _waveformBars = _generateWaveform(widget.audioUrl);
    
    // Setup pulse animation
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    // Don't initialize player for sending messages (no audio URL yet)
    if (!widget.isSending) {
      _initializePlayer();
    } else {
      // Set duration from provided value for sending state
      _totalDuration = Duration(seconds: widget.durationInSeconds);
    }
  }

  List<double> _generateWaveform(String seed) {
    // Use hash of URL for consistent waveform per message
    final random = math.Random(seed.hashCode);
    return List.generate(_barCount, (index) {
      // Create a more natural waveform shape
      final baseHeight = 0.3 + random.nextDouble() * 0.7;
      // Add some variation to make it look more natural
      final variation = math.sin(index * 0.5) * 0.2;
      return (baseHeight + variation).clamp(0.2, 1.0);
    });
  }

  @override
  void didUpdateWidget(VoiceMessageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // If the audio URL changed, we need to reinitialize
    if (oldWidget.audioUrl != widget.audioUrl) {
      AppLogger.i('🎵 Voice message widget updated with new URL',
          category: LogCategory.media,
          data: {
            'oldUrl': oldWidget.audioUrl,
            'newUrl': widget.audioUrl,
            'oldDuration': oldWidget.durationInSeconds,
            'newDuration': widget.durationInSeconds,
          });
      
      // Regenerate waveform for new URL
      _waveformBars = _generateWaveform(widget.audioUrl);
      
      // Dispose old player and subscriptions
      _positionSubscription?.cancel();
      _durationSubscription?.cancel();
      _playerStateSubscription?.cancel();
      _audioPlayer?.dispose();
      _audioPlayer = null;
      
      // Reset state
      _currentPosition = Duration.zero;
      _isPlaying = false;
      _isLoading = false;
      _userInitiatedLoad = false;
      
      // Reinitialize with new URL
      if (!widget.isSending) {
        _initializePlayer();
      } else {
        setState(() {
          _totalDuration = Duration(seconds: widget.durationInSeconds);
        });
      }
    } else if (oldWidget.durationInSeconds != widget.durationInSeconds) {
      // Just duration changed, update the total duration
      AppLogger.i('🎵 Voice message duration updated',
          category: LogCategory.media,
          data: {
            'oldDuration': oldWidget.durationInSeconds,
            'newDuration': widget.durationInSeconds,
          });
      setState(() {
        _totalDuration = Duration(seconds: widget.durationInSeconds);
      });
    }
  }

  void _initializePlayer() async {
    try {
      final player = AudioPlayer();
      _audioPlayer = player;

      // Configure audio session for speaker playback on iOS (not needed on web)
      if (!kIsWeb && platform_io.isIOS) {
        try {
          final session = await AudioSession.instance;
          await session.configure(AudioSessionConfiguration(
            avAudioSessionCategory: AVAudioSessionCategory.playback,
            avAudioSessionCategoryOptions:
                AVAudioSessionCategoryOptions.defaultToSpeaker,
            avAudioSessionMode: AVAudioSessionMode.defaultMode,
          ));
          AppLogger.i('🔊 iOS audio session configured for speaker playback',
              category: LogCategory.media);
        } catch (e) {
          AppLogger.w('🔊 Failed to configure audio session',
              category: LogCategory.media);
        }
      }

      // Set the total duration from the provided value
      _totalDuration = Duration(seconds: widget.durationInSeconds);

      AppLogger.i('🎵 Initializing voice message player',
          category: LogCategory.media,
          data: {
            'audioUrl': widget.audioUrl,
            'durationInSeconds': widget.durationInSeconds,
            'transcript': widget.transcript,
          });

      AppLogger.i('🎵 Audio player initialized, ready for on-demand loading',
          category: LogCategory.media);
      
      // Preload audio in background after a short delay for smoother UX
      // This starts downloading/caching without blocking the UI
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          _preloadAudio();
        }
      });

      // Subscribe to streams
      _positionSubscription = player.positionStream.listen((position) {
        if (mounted) {
          setState(() {
            _currentPosition = position;
          });
        }
      });

      _durationSubscription = player.durationStream.listen((duration) {
        if (mounted && duration != null) {
          setState(() {
            _totalDuration = duration;
          });
        }
      });

      _playerStateSubscription = player.playerStateStream.listen((state) {
        if (mounted) {
          AppLogger.i('🎵 Player state changed',
              category: LogCategory.media,
              data: {
                'playing': state.playing,
                'processingState': state.processingState.toString(),
                'audioUrl': widget.audioUrl,
              });

          final isLoadingOrBuffering = state.processingState == ProcessingState.loading ||
              state.processingState == ProcessingState.buffering;
          
          setState(() {
            _isPlaying = state.playing;
            // Only show loading indicator if user initiated the load
            _isLoading = isLoadingOrBuffering && _userInitiatedLoad;
          });
          
          // Reset user-initiated flag once loading is done
          if (!isLoadingOrBuffering && _userInitiatedLoad) {
            _userInitiatedLoad = false;
          }
          
          // Handle pulse animation
          if (state.playing) {
            _pulseController.repeat(reverse: true);
          } else {
            _pulseController.stop();
            _pulseController.reset();
          }

          // Auto-stop when completed
          if (state.processingState == ProcessingState.completed) {
            player.seek(Duration.zero);
            player.stop();
          }
        }
      });
    } on PlayerException catch (e) {
      AppLogger.e('❌ PlayerException initializing voice message player',
          category: LogCategory.media,
          error: e,
          data: {
            'audioUrl': widget.audioUrl,
            'errorCode': e.code.toString(),
            'errorMessage': e.message,
            'transcript': widget.transcript,
          });
    } on PlayerInterruptedException catch (e) {
      AppLogger.e(
          '❌ PlayerInterruptedException initializing voice message player',
          category: LogCategory.media,
          error: e,
          data: {
            'audioUrl': widget.audioUrl,
            'errorMessage': e.message,
            'transcript': widget.transcript,
          });
    } catch (e) {
      AppLogger.e('❌ Generic error initializing voice message player',
          category: LogCategory.media,
          error: e,
          data: {
            'audioUrl': widget.audioUrl,
            'urlLength': widget.audioUrl.length,
            'transcript': widget.transcript,
            'isValidUrl': widget.audioUrl.startsWith('http'),
            'errorType': e.runtimeType.toString(),
          });
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _audioPlayer?.dispose();
    super.dispose();
  }

  void _togglePlayback() async {
    final player = _audioPlayer;
    if (player == null) {
      AppLogger.w('🎵 Cannot toggle playback - player not initialized',
          category: LogCategory.media);
      return;
    }
    
    // Haptic feedback
    HapticFeedback.lightImpact();
    
    try {
      AppLogger.i('🎵 Toggle playback requested',
          category: LogCategory.media,
          data: {
            'currentlyPlaying': _isPlaying,
            'isLoading': _isLoading,
            'audioUrl': widget.audioUrl,
            'playerState': player.processingState.toString(),
          });

      if (_isPlaying) {
        AppLogger.i('🎵 Pausing playback', category: LogCategory.media);
        await player.pause();
      } else {
        AppLogger.i('🎵 Starting playback', category: LogCategory.media);

        // Load audio source on-demand for better performance
        if (player.processingState == ProcessingState.idle) {
          AppLogger.i('🎵 Loading audio on-demand...',
              category: LogCategory.media);
          // Mark as user-initiated so we show loading indicator
          _userInitiatedLoad = true;
          setState(() => _isLoading = true);
          await _loadAudioSource();
        }

        // Reset position to start if completed
        if (player.processingState == ProcessingState.completed) {
          AppLogger.i('🎵 Resetting to start before playing',
              category: LogCategory.media);
          await player.seek(Duration.zero);
        }

        await player.play();
        AppLogger.i('🎵 Play command sent successfully',
            category: LogCategory.media);
      }
    } on PlayerException catch (e) {
      AppLogger.e('❌ PlayerException during playback toggle',
          category: LogCategory.media,
          error: e,
          data: {
            'audioUrl': widget.audioUrl,
            'errorCode': e.code.toString(),
            'errorMessage': e.message,
            'isPlaying': _isPlaying,
          });
    } on PlayerInterruptedException catch (e) {
      AppLogger.e('❌ PlayerInterruptedException during playback toggle',
          category: LogCategory.media,
          error: e,
          data: {
            'audioUrl': widget.audioUrl,
            'errorMessage': e.message,
            'isPlaying': _isPlaying,
          });
    } catch (e) {
      AppLogger.e('❌ Generic error toggling voice message playback',
          category: LogCategory.media,
          error: e,
          data: {
            'audioUrl': widget.audioUrl,
            'isPlaying': _isPlaying,
            'errorType': e.runtimeType.toString(),
          });
    }
  }

  /// Seek to position when user taps on waveform
  void _seekToPosition(double tapPosition, double width) async {
    final player = _audioPlayer;
    if (player == null || _totalDuration.inMilliseconds == 0) return;
    
    HapticFeedback.selectionClick();
    
    final progress = tapPosition / width;
    final newPosition = Duration(
      milliseconds: (_totalDuration.inMilliseconds * progress).round(),
    );
    
    // Load audio if not loaded
    if (player.processingState == ProcessingState.idle) {
      _userInitiatedLoad = true;
      setState(() => _isLoading = true);
      await _loadAudioSource();
    }
    
    await player.seek(newPosition);
    
    // Start playing if not already
    if (!_isPlaying) {
      await player.play();
    }
  }

  /// Check if URL is a local file path (not applicable on web)
  bool _isLocalFile(String url) {
    if (kIsWeb) return false;
    return url.startsWith('/') || url.startsWith('file://');
  }

  /// Load audio source with caching for remote files, direct access for local files
  /// On web, uses direct URL without file caching
  Future<void> _loadAudioSource() async {
    final player = _audioPlayer;
    if (player == null) {
      AppLogger.w('🎵 Cannot load audio - player not initialized',
          category: LogCategory.media);
      return;
    }
    
    final isLocal = _isLocalFile(widget.audioUrl);
    
    AppLogger.i('🎵 Loading audio source...',
        category: LogCategory.media,
        data: {
          'audioUrl': widget.audioUrl,
          'isLocal': isLocal,
          'isWeb': kIsWeb,
        });

    try {
      AudioSource audioSource;
      
      if (kIsWeb) {
        // Web: Use direct URL (no file caching available)
        audioSource = AudioSource.uri(Uri.parse(widget.audioUrl));
        AppLogger.i('🎵 Using direct URL (web)', category: LogCategory.media);
      } else if (isLocal) {
        // Mobile: Local file - use directly (fastest)
        final localPath = widget.audioUrl.startsWith('file://') 
            ? widget.audioUrl.substring(7) 
            : widget.audioUrl;
        audioSource = AudioSource.file(localPath);
        AppLogger.i('🎵 Using local file directly', category: LogCategory.media);
      } else {
        // Mobile: Remote URL - use caching
        final cachePath = await platform_io.getCacheFilePath(widget.audioUrl);
        
        if (cachePath != null) {
          // Ensure cache directory exists
          await platform_io.ensureCacheDirectory(cachePath);
          
          // Check if already cached
          if (await platform_io.cacheFileExists(cachePath)) {
            // Use cached file directly
            audioSource = AudioSource.file(cachePath);
            AppLogger.i('🎵 Using cached file', 
                category: LogCategory.media,
                data: {'cachePath': cachePath});
          } else {
            // Use LockCachingAudioSource - downloads and caches automatically
            audioSource = LockCachingAudioSource(
              Uri.parse(widget.audioUrl),
            );
            AppLogger.i('🎵 Using caching audio source', category: LogCategory.media);
          }
        } else {
          // Fallback to direct URL if caching unavailable
          audioSource = AudioSource.uri(Uri.parse(widget.audioUrl));
          AppLogger.i('🎵 Using direct URL (cache unavailable)', category: LogCategory.media);
        }
      }

      await player.setAudioSource(audioSource, preload: true);
      AppLogger.i('🎵 Audio source loaded successfully',
          category: LogCategory.media);
    } catch (primaryError) {
      AppLogger.w('🎵 Primary method failed, trying direct URL',
          category: LogCategory.media,
          data: {'error': primaryError.toString()});

      try {
        // Fallback: Simple URI without caching
        await player.setUrl(widget.audioUrl);
        AppLogger.i('🎵 Fallback method successful',
            category: LogCategory.media);
      } catch (fallbackError) {
        AppLogger.e('🎵 All loading methods failed',
            category: LogCategory.media);
        rethrow;
      }
    }
  }
  
  /// Preload audio in background for faster playback
  Future<void> _preloadAudio() async {
    final player = _audioPlayer;
    if (player == null || widget.audioUrl.isEmpty) return;
    
    // Don't preload if already loaded
    if (player.processingState != ProcessingState.idle) return;
    
    try {
      await _loadAudioSource();
      AppLogger.i('🎵 Audio preloaded successfully', category: LogCategory.media);
    } catch (e) {
      // Silently fail preload - will try again on play
      AppLogger.w('🎵 Preload failed, will load on play', 
          category: LogCategory.media);
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(1, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isUser = widget.isUserMessage;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Colors based on sender
    final primaryColor = isUser ? Colors.white : AppTheme.primaryColor;
    final secondaryColor = isUser 
        ? Colors.white.withValues(alpha: 0.35)
        : (isDark ? Colors.white.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.35));
    final bgColor = isUser
        ? (widget.isSending 
            ? AppTheme.primaryColor.withValues(alpha: 0.7) 
            : AppTheme.primaryColor)
        : (isDark ? AppTheme.cardDarkColor : Colors.white);

    // Border radius matching chat bubbles
    final borderRadius = isUser
        ? const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(4),
          )
        : const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(18),
          );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: borderRadius,
        border: isUser
            ? null
            : Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.grey.withValues(alpha: 0.12),
              ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Play/pause button (elevated)
          _buildPlayButton(primaryColor, secondaryColor, isUser, isDark),
          
          const SizedBox(width: AppDimensions.spacingSm),
          
          // Waveform
          Expanded(
            child: _buildWaveform(primaryColor, secondaryColor),
          ),
          
          const SizedBox(width: AppDimensions.spacingSm),
          
          // Duration at end
          _buildDurationText(primaryColor, isDark, isUser),
        ],
      ),
    );
  }

  Widget _buildPlayButton(Color primaryColor, Color secondaryColor, bool isUser, bool isDark) {
    final buttonSize = 36.0;
    
    // Elevated button colors
    final buttonBgColor = isUser 
        ? Colors.white
        : AppTheme.primaryColor;
    final iconColor = isUser 
        ? AppTheme.primaryColor
        : Colors.white;
    
    if (widget.isSending) {
      // Uploading state
      return Container(
        width: buttonSize,
        height: buttonSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: secondaryColor,
        ),
        child: AppLoadingIndicator(
          size: 16,
          strokeWidth: 2,
          color: primaryColor,
        ),
      );
    }
    
    return GestureDetector(
      onTap: _togglePlayback,
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _isPlaying ? _pulseAnimation.value : 1.0,
            child: Container(
              width: buttonSize,
              height: buttonSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isLoading ? secondaryColor : buttonBgColor,
                boxShadow: _isLoading ? null : [
                  BoxShadow(
                    color: (isUser ? Colors.black : AppTheme.primaryColor).withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: _isLoading
                  ? AppLoadingIndicator(
                      size: 16,
                      strokeWidth: 2,
                      color: primaryColor,
                    )
                  : Icon(
                      _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: iconColor,
                      size: 20,
                    ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildWaveform(Color primaryColor, Color secondaryColor) {
    final progress = _totalDuration.inMilliseconds > 0
        ? _currentPosition.inMilliseconds / _totalDuration.inMilliseconds
        : 0.0;
    
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onTapDown: widget.isSending 
              ? null 
              : (details) => _seekToPosition(details.localPosition.dx, constraints.maxWidth),
          onHorizontalDragUpdate: widget.isSending
              ? null
              : (details) => _seekToPosition(details.localPosition.dx.clamp(0, constraints.maxWidth), constraints.maxWidth),
          child: Container(
            height: 24,
            color: Colors.transparent, // For hit testing
            child: widget.isSending
                ? _buildSendingWaveform(secondaryColor)
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: List.generate(_barCount, (index) {
                      // Calculate threshold - bar is active if playback has passed it
                      // Use (index + 1) / _barCount so first bar needs some progress to light up
                      final barThreshold = (index + 0.5) / _barCount;
                      final isActive = progress > 0 && progress >= barThreshold;
                      final barHeight = _waveformBars[index] * 20;
                      
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 80),
                        width: 2.5,
                        height: barHeight.clamp(4.0, 20.0),
                        decoration: BoxDecoration(
                          color: isActive ? primaryColor : secondaryColor,
                          borderRadius: BorderRadius.circular(1.5),
                        ),
                      );
                    }),
                  ),
          ),
        );
      },
    );
  }

  Widget _buildSendingWaveform(Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: List.generate(_barCount, (index) {
        final barHeight = _waveformBars[index] * 20;
        return Container(
          width: 2.5,
          height: barHeight.clamp(4.0, 20.0),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(1.5),
          ),
        );
      }),
    );
  }

  Widget _buildDurationText(Color primaryColor, bool isDark, bool isUser) {
    final textColor = isUser
        ? Colors.white.withValues(alpha: 0.8)
        : (isDark ? Colors.white70 : Colors.grey[600]);
    
    if (widget.isSending) {
      return SizedBox(
        width: 32,
        child: Text(
          '...',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: AppTheme.holyCowTextSize,
            fontWeight: FontWeight.w500,
            color: textColor,
          ),
        ),
      );
    }
    
    final displayDuration = _isPlaying || _currentPosition > Duration.zero
        ? _currentPosition
        : _totalDuration;
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_isPlaying)
          Container(
            width: 5,
            height: 5,
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isUser ? Colors.white : AppTheme.primaryColor,
            ),
          ),
        Text(
          _formatDuration(displayDuration),
          style: TextStyle(
            fontSize: AppTheme.holyCowTextSize,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
      ],
    );
  }
}
