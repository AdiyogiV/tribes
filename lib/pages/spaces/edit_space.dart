import 'package:flutter/foundation.dart';
import 'package:aurogram/models/space_types.dart';
import 'package:aurogram/pages/spaces/space_screen.dart';
import 'package:aurogram/widgets/dialogs/login_bottom_sheet.dart';
import 'package:aurogram/widgets/ui/skeleton_widgets.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:aurogram/models/space.dart';
import 'package:aurogram/models/space_roles.dart';
import 'package:aurogram/pages/social/requests.dart';
import 'package:aurogram/pages/spaces/add_spaces_members.dart';
import 'package:aurogram/services/cache_service.dart';
import 'package:aurogram/services/database_service.dart';
import 'package:aurogram/services/data/space_db_service.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:aurogram/utils/theme/theme_helper.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/utils/logging/app_logger.dart';
import 'package:aurogram/utils/dependency_injection.dart';
import 'package:aurogram/widgets/spaces/space_members_list.dart';
import 'package:aurogram/services/space_service.dart';
import 'package:aurogram/services/share_service.dart';

// Conditional import for dart:io
import 'dart:io' if (dart.library.html) 'package:aurogram/platform/io_stub.dart';
import 'package:aurogram/utils/theme/app_dimensions.dart';
import 'package:aurogram/widgets/common/snack_bar_service.dart';

class EditSpace extends StatefulWidget {
  final String? space;
  const EditSpace({super.key, this.space});

  @override
  EditSpaceState createState() => EditSpaceState();
}

class EditSpaceState extends State<EditSpace>
    with SingleTickerProviderStateMixin {
  User? user = FirebaseAuth.instance.currentUser;
  bool isAdmin = false;
  String? spaceName;
  String? userName;
  // Using dynamic to avoid type conflicts between dart:io.File and stub File
  dynamic _imageFile;
  String? _imageFilePath;
  // For web: store image bytes
  Uint8List? _imageBytes;
  // For web: blob URL for preview
  String? _webPreviewUrl;
  SpaceRoles? role;
  bool updating = false;
  Space? space;
  late AnimationController _fabController;
  late Animation<double> _fabAnimation;
  bool _isFabOpen = false;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final RefreshController _refreshController =
      RefreshController(initialRefresh: false);

  bool _adminOnlyPosting = false;

  @override
  void initState() {
    super.initState();
    _setupFabAnimation();
    getSpaceBox();
  }

  void _setupFabAnimation() {
    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fabAnimation = CurvedAnimation(
      parent: _fabController,
      curve: Curves.easeInOut,
    );
  }

  Future<void> getSpaceBox() async {
    if (widget.space == null || widget.space!.isEmpty) {
      if (mounted) setState(() {});
      return;
    }
    isAdmin = await DatabaseService().isAdmin(widget.space!);
    final spaceDbService = locator<SpaceDbService>();
    final String? currentUserId = user?.uid;
    if (currentUserId == null) {
      if (mounted) setState(() {});
      return;
    }
    role = await spaceDbService.getSpaceRole(widget.space!, currentUserId);
    space = await spaceDbService.getSpace(widget.space!);
    if (space == null) {
      if (mounted) setState(() {});
      return;
    }
    spaceName = space!.name;
    if (user != null) {
      DocumentSnapshot authorDocuments =
          await DatabaseService().getUser(user!.uid);
      final Map<String, dynamic>? authorData =
          authorDocuments.data() as Map<String, dynamic>?;
      userName = authorData?['name']?.toString();
    }

    _nameController.text = space!.name ?? '';
    var imagePath = space?.displayPicture;
    final cacheService = locator<CacheService>();
    _imageFile = await cacheService.getFile(imagePath);
    _bioController.text = space!.description ?? '';
    _adminOnlyPosting = space!.adminOnlyPosting;

    if (mounted) setState(() {});
  }

  Future<void> onSavePressed() async {
    if (mounted) {
      setState(() {
        updating = true;
      });
    }

    space!.name = _nameController.text.trim();
    space!.description = _bioController.text.trim();
    // On web, don't set displayPicture path - we'll pass bytes separately
    space!.displayPicture = kIsWeb ? null : _imageFilePath;
    space!.adminOnlyPosting = _adminOnlyPosting;
    // Private groups are always hidden, public groups are always searchable
    space!.limitedVisibility = isPrivateSpaceType(space!.spaceType);

    final spaceDbService = locator<SpaceDbService>();
    await spaceDbService.updateSpace(space!, imageBytes: _imageBytes);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _onImageButtonPressed() async {
    try {
      final pickedFile =
          await ImagePicker().pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        if (kIsWeb) {
          // On web, read bytes and use blob URL for preview
          _imageBytes = await pickedFile.readAsBytes();
          _webPreviewUrl = pickedFile.path;
          _imageFilePath = 'web_image'; // Flag that we have a web image
        } else {
          // On mobile, use file
          _imageFilePath = pickedFile.path;
          _imageFile = File(_imageFilePath!);
        }
        if (mounted) setState(() {});
      }
    } catch (e) {
      AppLogger.e('Error picking image',
          category: LogCategory.media, data: {'error': e.toString()});
    }
  }

  void _toggleFab() {
    setState(() {
      _isFabOpen = !_isFabOpen;
      if (_isFabOpen) {
        _fabController.forward();
      } else {
        _fabController.reverse();
      }
    });
  }

  List<Widget> _buildFabActions() {
    List<Widget> actions = [];

    if (role == SpaceRoles.creator) {
      actions.addAll([
        _buildFabAction(Icons.exit_to_app_rounded, 'Requests', Colors.orange,
            _showRequests),
        _buildFabAction(
            Icons.delete, 'Delete All Posts', Colors.red, _deleteSpace),
      ]);
    } else if (role == SpaceRoles.admin) {
      actions.addAll([
        _buildFabAction(Icons.exit_to_app_rounded, 'Requests', Colors.orange,
            _showRequests),
        _buildFabAction(
            Icons.exit_to_app_rounded, 'Leave', Colors.grey, _leaveSpace),
      ]);
    } else if (role == SpaceRoles.member) {
      actions.add(_buildFabAction(
          Icons.exit_to_app_rounded, 'Leave', Colors.grey, _leaveSpace));
    } else if (role == SpaceRoles.requested) {
      actions.add(_buildFabAction(
          Icons.cancel, 'Cancel Request', Colors.red, _cancelRequest));
    } else {
      actions.add(_buildFabAction(Icons.add, 'Join', AppTheme.primaryColor, _joinSpace));
    }

    return actions;
  }

  Widget _buildFabAction(
      IconData icon, String label, Color color, VoidCallback onPressed) {
    return ScaleTransition(
      scale: _fabAnimation,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: FloatingActionButton.extended(
          heroTag: label,
          onPressed: () {
            _toggleFab();
            if (user == null) {
              showLoginBottomSheet(context);
              return;
            }
            onPressed();
          },
          backgroundColor: color,
          foregroundColor: Colors.white,
          icon: Icon(icon),
          label: Text(label),
        ),
      ),
    );
  }

  void _deleteSpace() {
    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) => CupertinoAlertDialog(
        title: Text('Delete All Posts'),
        content: Text(
            'Are you sure you want to delete all posts from this gram? This action cannot be undone.'),
        actions: <Widget>[
          CupertinoDialogAction(
            child: Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.of(context).pop();
              _performSpaceDeletion();
            },
            child: Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _performSpaceDeletion() async {
    try {
      setState(() {
        updating = true;
      });
      final spaceService = locator<SpaceService>();
      bool success = await spaceService.clearAllPostsInSpace(widget.space!);
      if (success && mounted) {
        Navigator.of(context).pushReplacement(
          CupertinoPageRoute(
              builder: (context) => SpaceScreen(rid: widget.space!)),
        );
      } else {
        throw Exception("Failed to delete gram");
      }
    } catch (e) {
      AppLogger.e('Error deleting space',
          category: LogCategory.general, data: {'error': e.toString()});
      _showErrorDialog(
          'An error occurred while deleting the gram. Please try again.');
    } finally {
      setState(() {
        updating = false;
      });
    }
  }

  void _showRequests() {
    Navigator.of(context).push(
      CupertinoPageRoute(builder: (context) => Requests(space: widget.space!)),
    );
  }

  void _leaveSpace() {
    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) => CupertinoAlertDialog(
        title: Text('Leave Gram'),
        content: Text(
            'Are you sure you want to leave this gram? You will no longer have access to its content.'),
        actions: <Widget>[
          CupertinoDialogAction(
            child: Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.of(context).pop();
              _performLeaveSpace();
            },
            child: Text('Leave'),
          ),
        ],
      ),
    );
  }

  Future<void> _performLeaveSpace() async {
    try {
      setState(() {
        updating = true;
      });
      
      await locator<SpaceDbService>().removeSpaceMember(widget.space!, user!.uid);
      
      if (mounted) {
        // Show success message
        showCustomSnackBar(context, message: 'You have left the gram', backgroundColor: Colors.green, duration: const Duration(seconds: 2));
        
        // Navigate back to home/grams tab
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      AppLogger.e('Error leaving space',
          category: LogCategory.general, data: {'error': e.toString()});
      if (mounted) {
        setState(() {
          updating = false;
        });
        _showErrorDialog('An error occurred while leaving the gram. Please try again.');
      }
    }
  }

  void _cancelRequest() {
    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) => CupertinoAlertDialog(
        title: Text('Cancel Request'),
        content: Text('Are you sure you want to cancel your join request?'),
        actions: <Widget>[
          CupertinoDialogAction(
            child: Text('No'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.of(context).pop();
              await locator<SpaceDbService>().removeSpaceMember(widget.space!, user!.uid);
              if (mounted) {
                setState(() {
                  role = null;
                });
                showCustomSnackBar(context, message: 'Join request cancelled', backgroundColor: Colors.orange, duration: const Duration(seconds: 2));
                getSpaceBox();
              }
            },
            child: Text('Cancel Request'),
          ),
        ],
      ),
    );
  }

  void _joinSpace() async {
    await locator<SpaceDbService>().requestToJoinSpace(widget.space!);
    if (mounted) {
      setState(() {
        role = SpaceRoles.requested;
      });
      showCustomSnackBar(context, message: 'Join request sent', backgroundColor: AppTheme.primaryColor, duration: const Duration(seconds: 2));
      getSpaceBox();
    }
  }

  void _inviteMembers() {
    Navigator.of(context).push(
      CupertinoPageRoute(
          builder: (context) => AddSpacesMember(space: widget.space!)),
    );
  }

  Future<void> _shareLink() async {
    if (widget.space == null || space == null) return;
    
    // Get member count from Firestore
    int memberCount = 0;
    try {
      final rolesSnapshot = await FirebaseFirestore.instance
          .collection('spaceRoles')
          .doc(widget.space!)
          .collection('roles')
          .get();
      memberCount = rolesSnapshot.docs.length;
    } catch (e) {
      // Ignore error, just use 0
    }

    ShareService.showGramCardPreview(
      context: context,
      spaceId: widget.space!,
      gramName: space!.name ?? 'Gram',
      description: space!.description,
      displayPicture: kIsWeb ? null : _imageFile,
      displayPictureUrl: space?.displayPicture,
      memberCount: memberCount,
      isPrivate: space!.isPrivate,
      inviterName: userName,
      inviterId: user?.uid,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      floatingActionButton: _buildFloatingActionButton(),
      body: SmartRefresher(
        onRefresh: _onRefresh,
        onLoading: _onLoading,
        enablePullDown: true,
        controller: _refreshController,
        header: ThemeHelper.refreshHeader,
        child: CupertinoPageScaffold(
          navigationBar: CupertinoNavigationBar(
            backgroundColor: Colors.white,
            border: Border(bottom: BorderSide(color: Colors.transparent)),
            middle: Text(
              'Gram Settings',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            trailing: isAdmin ? _buildSaveButton() : null,
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              child: Form(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    SizedBox(height: AppDimensions.spacingXl),
                    _buildImageContainer(),
                    SizedBox(height: AppDimensions.spacingSm),
                    Center(child: _buildVisibilityIndicator()),
                    SizedBox(height: AppDimensions.spacingXxl),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 15.0),
                      child: _buildDetailsSection(),
                    ),
                    SizedBox(height: AppDimensions.spacingXl),
                    if (isAdmin || role == SpaceRoles.creator) ...[
                      _buildAdminSettings(),
                      SizedBox(height: AppDimensions.spacingXl),
                    ],
                    getCrew()
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    return SizedBox(
      width: 200,
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          _buildMainFab(),
          if (!_isFabOpen &&
              (role == SpaceRoles.creator || role == SpaceRoles.admin))
            Positioned(
              bottom: 65,
              right: 0,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  FloatingActionButton.extended(
                    heroTag: 'inviteButton',
                    onPressed: _inviteMembers,
                    icon: Icon(Icons.add),
                    label: Text('Add Members'),
                    backgroundColor: Colors.amber,
                  ),
                  SizedBox(height: AppDimensions.spacingMdSm),
                  FloatingActionButton.extended(
                    heroTag: 'sharelink',
                    onPressed: _shareLink,
                    icon: Icon(Icons.share),
                    label: Text('Share Link'),
                    backgroundColor: Colors.amber,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMainFab() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        ..._buildFabActions(),
        FloatingActionButton(
          heroTag: 'mainFab',
          onPressed: _toggleFab,
          child: AnimatedIcon(
            icon: AnimatedIcons.menu_close,
            progress: _fabAnimation,
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return updating
        ? const PulsingDots(size: 6)
        : GestureDetector(
            onTap: onSavePressed,
            child: Text(
              'Save',
              style: TextStyle(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.bold),
            ),
          );
  }

  Widget _buildImageContainer() {
    double pWidth = MediaQuery.of(context).size.width * 0.4;
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: GestureDetector(
        onTap: () {
          if (isAdmin) _onImageButtonPressed();
        },
        child: Align(
          alignment: Alignment.center,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(5.0),
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              width: pWidth,
              height: pWidth,
              child: _buildSpaceImage(),
            ),
          ),
        ),
      ),
    );
  }

  /// Build the space image based on platform
  Widget _buildSpaceImage() {
    // Web: check for web preview first
    if (kIsWeb && _webPreviewUrl != null) {
      return Image.network(_webPreviewUrl!, fit: BoxFit.cover);
    }
    // Mobile: check for file
    if (!kIsWeb && _imageFile != null) {
      return Image.file(_imageFile!, fit: BoxFit.cover);
    }
    // Fallback to network image from existing space
    if (space?.displayPicture != null && space!.displayPicture!.startsWith('http')) {
      return Image.network(space!.displayPicture!, fit: BoxFit.cover);
    }
    // Default placeholder
    return Image.asset('assets/images/2.png', fit: BoxFit.cover);
  }

  Widget _buildDetailsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _buildCupertinoTextField(_nameController, 'Gram Name'),
        SizedBox(height: AppDimensions.spacingMdSm),
        _buildCupertinoTextField(_bioController, 'Description', fontSize: 14),
      ],
    );
  }

  Widget _buildCupertinoTextField(
      TextEditingController controller, String placeholder,
      {double fontSize = 16.0}) {
    return CupertinoTextField(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10.0),
      ),
      controller: controller,
      placeholder: placeholder,
      readOnly: !isAdmin,
      style: TextStyle(fontSize: fontSize),
    );
  }

  Widget _buildAdminSettings() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 30),
          Divider(),
          SizedBox(height: 30),
          _buildPostingPermissionSelector(),
          SizedBox(height: 30),
          Divider(),
          SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildPostingPermissionSelector() {
    return _buildSelector<bool>(
      title: 'Posting Permissions',
      options: [
        SelectorOption(false, 'All Members', CupertinoIcons.person_3,
            AppTheme.primaryColor),
        SelectorOption(
            true,
            'Admins Only',
            CupertinoIcons.person_crop_circle_badge_checkmark,
            AppTheme.accentColor),
      ],
      selectedOption: _adminOnlyPosting,
      onOptionSelected: (option) => setState(() => _adminOnlyPosting = option),
      description: _adminOnlyPosting
          ? 'Only administrators can post on the gram feed, members can reply.'
          : 'Any member can create posts in this gram.',
    );
  }

  Widget _buildSelector<T>({
    required String title,
    required List<SelectorOption<T>> options,
    required T selectedOption,
    required Function(T) onOptionSelected,
    required String description,
    bool isDisabled = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
        SizedBox(height: AppDimensions.spacingSm),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
            border: Border.all(color: CupertinoColors.systemGrey4),
          ),
          child: Row(
            children: options.map((option) {
              final isSelected = selectedOption == option.value;
              return Expanded(
                child: GestureDetector(
                  onTap:
                      isDisabled ? null : () => onOptionSelected(option.value),
                  child: Opacity(
                    opacity: isDisabled && !isSelected ? 0.3 : 1.0,
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 15),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? option.color.withValues(alpha: 0.12)
                            : CupertinoColors.systemBackground,
                        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(option.icon,
                              color: isSelected
                                  ? option.color
                                  : CupertinoColors.systemGrey),
                          SizedBox(width: AppDimensions.spacingSm),
                          Text(
                            option.label,
                            style: TextStyle(
                              color: isSelected
                                  ? option.color
                                  : CupertinoColors.systemGrey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        SizedBox(height: AppDimensions.spacingSm),
        Text(
          description,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: CupertinoColors.systemGrey,
                fontSize: 14,
              ),
        ),
      ],
    );
  }

  Widget _buildVisibilityIndicator() {
    if (space == null) return SizedBox.shrink();

    final isPrivate = isPrivateSpaceType(space!.spaceType);
    final String label = isPrivate ? 'Private' : 'Public';
    final Color color = isPrivate
        ? AppTheme.accentColor
        : Theme.of(context).colorScheme.primary;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(isPrivate ? CupertinoIcons.lock_fill : CupertinoIcons.globe,
                  size: 16, color: color),
              SizedBox(width: AppDimensions.spacingSmMd),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget getCrew() {
    return SpaceMembersList(
      spaceId: widget.space!,
      isAdmin: isAdmin,
      showAdminActions: isAdmin,
      onRoleChanged: (_, __) => setState(() {}),
      onMemberRemoved: (_) => setState(() {}),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
    );
  }

  void _showErrorDialog(String message) {
    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) => CupertinoAlertDialog(
        title: Text('Error'),
        content: Text(message),
        actions: <Widget>[
          CupertinoDialogAction(
            child: Text('OK'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  void _onRefresh() async {
    await getSpaceBox();
    _refreshController.refreshCompleted();
  }

  void _onLoading() async {
    _refreshController.loadComplete();
  }

  @override
  void dispose() {
    _fabController.dispose();
    _refreshController.dispose();
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }
}

class SelectorOption<T> {
  final T value;
  final String label;
  final IconData icon;
  final Color color;

  SelectorOption(this.value, this.label, this.icon, this.color);
}
