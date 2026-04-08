import 'dart:async';
import 'package:aurogram/utils/logging/app_logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:aurogram/utils/theme/app_dimensions.dart';

/// A widget that shows an offline indicator banner when the device loses internet connection.
/// Only shows on web platform for a more app-like experience.
class OfflineIndicator extends StatefulWidget {
  final Widget child;
  
  const OfflineIndicator({
    super.key,
    required this.child,
  });

  @override
  State<OfflineIndicator> createState() => _OfflineIndicatorState();
}

class _OfflineIndicatorState extends State<OfflineIndicator>
    with SingleTickerProviderStateMixin {
  bool _isOffline = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
    
    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
    
    _initConnectivity();
  }

  Future<void> _initConnectivity() async {
    // Only monitor connectivity on web
    if (!kIsWeb) return;
    
    try {
      // Check initial connectivity
      final results = await Connectivity().checkConnectivity();
      _updateConnectionStatus(results);
      
      // Listen for connectivity changes
      _connectivitySubscription = Connectivity()
          .onConnectivityChanged
          .listen(_updateConnectionStatus);
    } catch (e) {
      // Connectivity check failed, assume online
      AppLogger.w('OfflineIndicator: Connectivity check failed: $e', category: LogCategory.network);
    }
  }

  void _updateConnectionStatus(List<ConnectivityResult> results) {
    final isOffline = results.isEmpty || 
        results.every((r) => r == ConnectivityResult.none);
    
    if (_isOffline != isOffline) {
      setState(() {
        _isOffline = isOffline;
      });
      
      if (isOffline) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Only show indicator on web
    if (!kIsWeb) {
      return widget.child;
    }
    
    return Stack(
      children: [
        widget.child,
        
        // Offline banner
        if (_isOffline)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SlideTransition(
              position: _slideAnimation,
              child: FadeTransition(
                opacity: _opacityAnimation,
                child: _buildOfflineBanner(),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildOfflineBanner() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return SafeArea(
      child: Material(
        color: Colors.transparent,
        child: Container(
          margin: const EdgeInsets.all(AppDimensions.paddingMd),
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingLg, vertical: AppDimensions.paddingMd),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF2D2D2D)
                : Colors.white,
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: AppTheme.warningColor.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppDimensions.paddingSm),
                decoration: BoxDecoration(
                  color: AppTheme.warningColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                ),
                child: Icon(
                  Icons.cloud_off_rounded,
                  color: AppTheme.warningColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppDimensions.spacingMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'You\'re offline',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : AppTheme.textLightColor,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spacingXxs),
                    Text(
                      'Some features may not be available',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.6)
                            : AppTheme.textSecondaryLightColor,
                      ),
                    ),
                  ],
                ),
              ),
              // Retry button
              GestureDetector(
                onTap: () async {
                  final results = await Connectivity().checkConnectivity();
                  _updateConnectionStatus(results);
                },
                child: Container(
                  padding: const EdgeInsets.all(AppDimensions.paddingSm),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                  ),
                  child: Icon(
                    Icons.refresh_rounded,
                    color: AppTheme.primaryColor,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A wrapper that provides offline indicator functionality
/// Can be used at the root of the widget tree
class OfflineAwareApp extends StatelessWidget {
  final Widget child;
  
  const OfflineAwareApp({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return OfflineIndicator(child: child);
  }
}
