import 'package:aurogram/models/space.dart';
import 'package:aurogram/models/space_types.dart';
import 'package:aurogram/services/space_service.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/widgets/previewBoxes/gramPicture.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:aurogram/pages/login/handleLogin.dart';
import 'package:aurogram/pages/spaces/spaceScreen.dart';
import 'package:aurogram/services/auth_service.dart';

class InviteLandingPage extends StatefulWidget {
  final String? space;
  final String? invitee;

  const InviteLandingPage({Key? key, this.space, this.invitee})
      : super(key: key);

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

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (widget.space == null) {
      setState(() {
        _isLoading = false;
        _error = 'Invalid invite link';
      });
      return;
    }

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      
      // Load space data, inviter info, and membership status in parallel
      final futures = await Future.wait([
        FirebaseFirestore.instance
            .collection('spaces')
            .doc(widget.space)
            .get(),
        if (widget.invitee != null)
          FirebaseFirestore.instance
              .collection('users')
              .doc(widget.invitee)
              .get()
        else
          Future.value(null),
        // Check if current user is already a member
        if (currentUser != null)
          FirebaseFirestore.instance
              .collection('spaceRoles')
              .doc(widget.space)
              .collection('roles')
              .doc(currentUser.uid)
              .get()
        else
          Future.value(null),
      ]);

      final spaceDoc = futures[0] as DocumentSnapshot;
      final inviterDoc = futures.length > 1 ? futures[1] as DocumentSnapshot? : null;
      final memberDoc = futures.length > 2 ? futures[2] as DocumentSnapshot? : null;

      if (!spaceDoc.exists || spaceDoc.data() == null) {
        setState(() {
          _isLoading = false;
          _error = 'This gram no longer exists';
        });
        return;
      }

      String? inviterName;
      if (inviterDoc != null && inviterDoc.exists) {
        final data = inviterDoc.data() as Map<String, dynamic>?;
        inviterName = data?['name'] as String?;
      }

      // Check membership
      final isAlreadyMember = memberDoc != null && memberDoc.exists;

      setState(() {
        _spaceData = Space.fromJson(spaceDoc.data() as Map<String, dynamic>);
        _inviterName = inviterName;
        _isAlreadyMember = isAlreadyMember;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Failed to load gram details';
      });
    }
  }

  Future<void> _joinGram() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    
    // If not logged in, go to login first
    if (authService.status != Status.Authenticated) {
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
        Navigator.of(context, rootNavigator: true).pushReplacement(
          CupertinoPageRoute(
            builder: (context) => SpaceScreen(rid: widget.space!),
          ),
        );
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
    
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => SpaceScreen(rid: widget.space!),
      ),
    );
  }

  void _openGram() {
    HapticFeedback.mediumImpact();
    if (widget.space == null) return;
    
    // Replace current page with gram screen since user is already a member
    Navigator.of(context, rootNavigator: true).pushReplacement(
      CupertinoPageRoute(
        builder: (context) => SpaceScreen(rid: widget.space!),
      ),
    );
  }

  void _dismiss() {
    HapticFeedback.lightImpact();
    Navigator.of(context).pop();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.errorColor,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
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
              color: textSecondary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              _error ?? 'Something went wrong',
              style: TextStyle(
                fontSize: 16,
                color: textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
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
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          
          // Status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: _isAlreadyMember 
                  ? AppTheme.successColor.withOpacity(0.1)
                  : AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _isAlreadyMember 
                    ? AppTheme.successColor.withOpacity(0.2)
                    : AppTheme.primaryColor.withOpacity(0.2),
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
                const SizedBox(width: 10),
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
          
          const SizedBox(height: 32),
          
          // Gram card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
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
                
                const SizedBox(height: 16),
                
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
                  const SizedBox(height: 8),
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
                
                const SizedBox(height: 16),
                
                // Space type badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _spaceData?.spaceType != null && 
                           _isPrivateSpace(_spaceData!.spaceType)
                        ? AppTheme.warningColor.withOpacity(0.1)
                        : AppTheme.successColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
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
                      const SizedBox(width: 6),
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
          
          const SizedBox(height: 40),
          
          // Action buttons
          _buildActionButtons(isDark, cardColor, textPrimary, textSecondary),
          
          const SizedBox(height: 40),
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
                  borderRadius: BorderRadius.circular(14),
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
          
          const SizedBox(height: 16),
          
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
                borderRadius: BorderRadius.circular(14),
              ),
              disabledBackgroundColor: AppTheme.primaryColor.withOpacity(0.5),
            ),
            child: _isJoining
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
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
        
        const SizedBox(height: 12),
        
        // Preview button (secondary)
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton(
            onPressed: _previewGram,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primaryColor,
              side: BorderSide(
                color: AppTheme.primaryColor.withOpacity(0.3),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
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
        
        const SizedBox(height: 16),
        
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
