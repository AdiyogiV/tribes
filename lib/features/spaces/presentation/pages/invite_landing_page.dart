import 'package:aurogram/shared/models/space.dart';
import 'package:aurogram/shared/presentation/widgets/media/common_widgets.dart';
import 'package:aurogram/shared/models/space_types.dart';
import 'package:aurogram/features/spaces/domain/space_service.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/features/profile/presentation/widgets/preview_boxes/gram_picture.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:aurogram/features/auth/handle_login.dart';
import 'package:aurogram/features/auth/auth_service.dart';
import 'package:aurogram/features/anonymous_messages/pages/send_composer_screen.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';
import 'package:aurogram/shared/presentation/widgets/feedback/snack_bar_service.dart';
import 'package:go_router/go_router.dart';

class InviteLandingPage extends StatefulWidget {
  final String? space;
  final String? invitee;

  const InviteLandingPage({super.key, this.space, this.invitee});

  @override
  InviteLandingPageState createState() => InviteLandingPageState();
}

class InviteLandingPageState extends State<InviteLandingPage> {
  bool _isLoading = true;
  bool _isJoining = false;
  bool _isAlreadyMember = false;
  Space? _spaceData;
  String? _inviterName;
  String? _error;
  bool _loadStarted = false;

  @override
  void initState() {
    super.initState();
    // Small delay to ensure Firebase is fully initialized
    // This helps when the app is cold-started via deep link
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted && !_loadStarted) _loadData();
    });
  }

  Future<void> _loadData() async {
    if (_loadStarted) return;
    _loadStarted = true;
    AppLogger.i('InviteLandingPage: Loading data for space=${widget.space}, invitee=${widget.invitee}',
        category: LogCategory.navigation);
    
    if (widget.space == null || widget.space!.isEmpty) {
      AppLogger.w('InviteLandingPage: Invalid space ID', category: LogCategory.navigation);
      setState(() {
        _isLoading = false;
        _error = 'Invalid invite link';
      });
      return;
    }

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      AppLogger.d('InviteLandingPage: Current user=${currentUser?.uid}', category: LogCategory.navigation);
      
      // Load space data first
      DocumentSnapshot<Map<String, dynamic>>? spaceDoc;
      try {
        spaceDoc = await FirebaseFirestore.instance
            .collection('spaces')
            .doc(widget.space)
            .get();
        AppLogger.d('InviteLandingPage: Space doc exists=${spaceDoc.exists}', category: LogCategory.navigation);
      } catch (e) {
        AppLogger.e('InviteLandingPage: Error fetching space', category: LogCategory.navigation, error: e);
        rethrow;
      }

      if (!spaceDoc.exists || spaceDoc.data() == null) {
        AppLogger.w('InviteLandingPage: Space does not exist', category: LogCategory.navigation);

        // Fallback: /s/{id} can also be an anonymous message slug (normalize: trim, first token)
        final slug = (widget.space ?? '')
            .trim()
            .split(RegExp(r'\s+'))
            .where((s) => s.isNotEmpty)
            .firstOrNull ?? '';
        if (slug.isEmpty) {
          AppLogger.w('InviteLandingPage: Empty slug after normalize', category: LogCategory.navigation);
          setState(() {
            _isLoading = false;
            _error = 'This gram no longer exists';
          });
          return;
        }
        AppLogger.i('InviteLandingPage: Checking anonymous slug', category: LogCategory.navigation, data: {'slug': slug});
        try {
          final slugSnapshot = await FirebaseFirestore.instance
              .collection('users')
              .where('anonymousLinkSlug', isEqualTo: slug)
              .limit(1)
              .get();
          if (slugSnapshot.docs.isNotEmpty) {
            AppLogger.i('InviteLandingPage: Slug found, navigating to anonymous send composer',
                category: LogCategory.navigation, data: {'slug': slug});
            if (!mounted) return;
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) =>
                    SecretMessageSendComposer(slug: slug),
              ),
            );
            return;
          }
          AppLogger.w('InviteLandingPage: No user with slug=$slug, showing error',
              category: LogCategory.navigation);
        } catch (e, st) {
          AppLogger.w('InviteLandingPage: Error checking anonymous slug',
              category: LogCategory.navigation, data: {'slug': slug, 'error': e.toString(), 'stackTrace': st.toString()});
        }

        setState(() {
          _isLoading = false;
          _error = 'This gram no longer exists';
        });
        return;
      }

      // Load inviter info if provided
      String? inviterName;
      if (widget.invitee != null && widget.invitee!.isNotEmpty) {
        try {
          final inviterDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(widget.invitee)
              .get();
          if (inviterDoc.exists) {
            final data = inviterDoc.data();
            inviterName = data?['name'] as String?;
          }
        } catch (e) {
          // Non-critical, just log and continue
          AppLogger.w('InviteLandingPage: Error fetching inviter info', 
              category: LogCategory.navigation, data: {'error': e.toString()});
        }
      }

      // Check if current user is already a member
      bool isAlreadyMember = false;
      if (currentUser != null) {
        try {
          final memberDoc = await FirebaseFirestore.instance
              .collection('spaceRoles')
              .doc(widget.space)
              .collection('roles')
              .doc(currentUser.uid)
              .get();
          isAlreadyMember = memberDoc.exists;
        } catch (e) {
          // Non-critical, just log and continue
          AppLogger.w('InviteLandingPage: Error checking membership', 
              category: LogCategory.navigation, data: {'error': e.toString()});
        }
      }

      // Parse space data
      try {
        final spaceData = spaceDoc.data()!;
        AppLogger.d('InviteLandingPage: Parsing space data', 
            category: LogCategory.navigation, data: {'name': spaceData['name']});
        
        setState(() {
          _spaceData = Space.fromJson(spaceData);
          _inviterName = inviterName;
          _isAlreadyMember = isAlreadyMember;
          _isLoading = false;
        });
        
        AppLogger.i('InviteLandingPage: Successfully loaded gram "${_spaceData?.name}"',
            category: LogCategory.navigation);
      } catch (e) {
        AppLogger.e('InviteLandingPage: Error parsing space data', 
            category: LogCategory.navigation, error: e);
        rethrow;
      }
    } catch (e, stackTrace) {
      AppLogger.e('InviteLandingPage: Failed to load gram details', 
          category: LogCategory.navigation, error: e, stackTrace: stackTrace);
      
      // Provide more specific error messages
      String errorMessage = 'Failed to load gram details';
      final errorString = e.toString().toLowerCase();
      
      if (errorString.contains('permission-denied') || errorString.contains('permission_denied')) {
        errorMessage = 'Unable to access this gram. Please sign in first.';
      } else if (errorString.contains('not-found') || errorString.contains('not_found')) {
        errorMessage = 'This gram no longer exists';
      } else if (errorString.contains('network') || errorString.contains('unavailable')) {
        errorMessage = 'Network error. Please check your connection.';
      }
      
      setState(() {
        _isLoading = false;
        _error = errorMessage;
      });
    }
  }

  Future<void> _joinGram() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    
    // If not a registered account (logged out or anonymous guest), go to
    // login first — joining a gram needs a real account.
    if (!authService.isRegistered) {
      Navigator.of(context).pushReplacement(
        CupertinoPageRoute(
          builder: (context) => HandleLogin(
            space: widget.space,
            invitee: widget.invitee,
          ),
        ),
      );
      return;
    }

    setState(() => _isJoining = true);
    HapticFeedback.mediumImpact();

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null || widget.space == null) {
        throw Exception("User or space is null");
      }

      final success = await SpaceService()
          .addInviteeToSpace(widget.space!, currentUser.uid);
          
      if (success) {
        if (!mounted) return;
        context.go('/space/${widget.space!}');
      } else {
        _showError('Failed to join. You may already be a member.');
      }
    } catch (e) {
      _showError('Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isJoining = false);
    }
  }

  void _previewGram() {
    HapticFeedback.lightImpact();
    if (widget.space == null) return;

    context.push('/space/${widget.space!}');
  }

  void _openGram() {
    HapticFeedback.mediumImpact();
    if (widget.space == null) return;

    // Replace current page with gram screen since user is already a member
    context.go('/space/${widget.space!}');
  }

  void _dismiss() {
    HapticFeedback.lightImpact();
    Navigator.of(context).pop();
  }

  void _showError(String message) {
    if (!mounted) return;
    showCustomSnackBar(context, message: message, backgroundColor: AppTheme.errorColor, behavior: SnackBarBehavior.floating);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldColor = isDark ? AppTheme.scaffoldDarkColor : AppTheme.scaffoldLightColor;
    final cardColor = isDark ? AppTheme.cardDarkColor : Colors.white;
    final textPrimary = isDark ? AppTheme.textDarkColor : AppTheme.textLightColor;
    final textSecondary = isDark ? AppTheme.textSecondaryDarkColor : AppTheme.textSecondaryLightColor;

    return Scaffold(
      backgroundColor: scaffoldColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: textSecondary),
          onPressed: _dismiss,
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? _buildLoadingState()
            : _error != null
                ? _buildErrorState(textPrimary, textSecondary)
                : _buildInviteContent(isDark, cardColor, textPrimary, textSecondary),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CupertinoActivityIndicator(),
    );
  }

  Widget _buildErrorState(Color textPrimary, Color textSecondary) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.link_off_rounded,
              size: 64,
              color: textSecondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: AppDimensions.spacingLg),
            Text(
              _error ?? 'Something went wrong',
              style: TextStyle(
                fontSize: 16,
                color: textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.spacingXxl),
            TextButton(
              onPressed: _dismiss,
              child: Text(
                'Go Back',
                style: TextStyle(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInviteContent(bool isDark, Color cardColor, Color textPrimary, Color textSecondary) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingXxl),
      child: Column(
        children: [
          const SizedBox(height: AppDimensions.spacingXl),
          
          // Status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: _isAlreadyMember 
                  ? AppTheme.successColor.withValues(alpha: 0.1)
                  : AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
              border: Border.all(
                color: _isAlreadyMember 
                    ? AppTheme.successColor.withValues(alpha: 0.2)
                    : AppTheme.primaryColor.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isAlreadyMember 
                      ? Icons.check_circle_outline_rounded
                      : Icons.mail_outline_rounded,
                  size: 18,
                  color: _isAlreadyMember 
                      ? AppTheme.successColor
                      : AppTheme.primaryColor,
                ),
                const SizedBox(width: AppDimensions.spacingMdSm),
                Text(
                  _isAlreadyMember 
                      ? "You're already a member"
                      : (_inviterName != null 
                          ? '$_inviterName invited you'
                          : "You're Invited"),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _isAlreadyMember 
                        ? AppTheme.successColor
                        : AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: AppDimensions.spacingSection),
          
          // Gram card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppDimensions.paddingXxl),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Gram picture
                GramPicture(
                  displayPicture: _spaceData?.displayPicture,
                  size: 80,
                  spaceId: widget.space ?? '',
                  borderRadius: 20,
                ),
                
                const SizedBox(height: AppDimensions.spacingLg),
                
                // Gram name
                Text(
                  _spaceData?.name ?? 'Gram',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                // Description if available
                if (_spaceData?.description != null && 
                    _spaceData!.description!.isNotEmpty) ...[
                  const SizedBox(height: AppDimensions.spacingSm),
                  Text(
                    _spaceData!.description!,
                    style: TextStyle(
                      fontSize: 14,
                      color: textSecondary,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                
                const SizedBox(height: AppDimensions.spacingLg),
                
                // Space type badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _spaceData?.spaceType != null && 
                           _isPrivateSpace(_spaceData!.spaceType)
                        ? AppTheme.warningColor.withValues(alpha: 0.1)
                        : AppTheme.successColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _spaceData?.spaceType != null && 
                            _isPrivateSpace(_spaceData!.spaceType)
                            ? Icons.lock_outline_rounded
                            : Icons.public_rounded,
                        size: 14,
                        color: _spaceData?.spaceType != null && 
                               _isPrivateSpace(_spaceData!.spaceType)
                            ? AppTheme.warningColor
                            : AppTheme.successColor,
                      ),
                      const SizedBox(width: AppDimensions.spacingSmMd),
                      Text(
                        _spaceData?.spaceType != null && 
                            _isPrivateSpace(_spaceData!.spaceType)
                            ? 'Private'
                            : 'Public',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _spaceData?.spaceType != null && 
                                 _isPrivateSpace(_spaceData!.spaceType)
                              ? AppTheme.warningColor
                              : AppTheme.successColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: AppDimensions.spacingLargeSection),
          
          // Action buttons
          _buildActionButtons(isDark, cardColor, textPrimary, textSecondary),
          
          const SizedBox(height: AppDimensions.spacingLargeSection),
        ],
      ),
    );
  }

  Widget _buildActionButtons(bool isDark, Color cardColor, Color textPrimary, Color textSecondary) {
    // If already a member, show simplified UI
    if (_isAlreadyMember) {
      return Column(
        children: [
          // Open Gram button (primary)
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _openGram,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: isDark ? AppTheme.scaffoldDarkColor : Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMdLg),
                ),
              ),
              child: const Text(
                'Open Gram',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          
          const SizedBox(height: AppDimensions.spacingLg),
          
          // Dismiss link
          TextButton(
            onPressed: _dismiss,
            child: Text(
              'Go Back',
              style: TextStyle(
                fontSize: 14,
                color: textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      );
    }
    
    // Normal invite flow
    return Column(
      children: [
        // Join button (primary)
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _isJoining ? null : _joinGram,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: isDark ? AppTheme.scaffoldDarkColor : Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusMdLg),
              ),
              disabledBackgroundColor: AppTheme.primaryColor.withValues(alpha: 0.5),
            ),
            child: _isJoining
                ? const AppLoadingIndicator(
                    size: 20,
                    strokeWidth: 2,
                    color: Colors.white,
                  )
                : const Text(
                    'Join Gram',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
        
        const SizedBox(height: AppDimensions.spacingMd),
        
        // Preview button (secondary)
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton(
            onPressed: _previewGram,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primaryColor,
              side: BorderSide(
                color: AppTheme.primaryColor.withValues(alpha: 0.3),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusMdLg),
              ),
            ),
            child: const Text(
              'Preview First',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        
        const SizedBox(height: AppDimensions.spacingLg),
        
        // Dismiss link
        TextButton(
          onPressed: _dismiss,
          child: Text(
            'Not Now',
            style: TextStyle(
              fontSize: 14,
              color: textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  bool _isPrivateSpace(SpaceType? spaceType) {
    if (spaceType == null) return false;
    return isPrivateSpaceType(spaceType);
  }
}
