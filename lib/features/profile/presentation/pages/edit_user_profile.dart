import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:aurogram/features/profile/domain/user_service.dart';
import 'package:aurogram/core/di/injection.dart';
import 'package:aurogram/shared/data/repositories/user_repository.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:aurogram/shared/presentation/widgets/avatars/user_avatar.dart';
import 'package:aurogram/shared/presentation/widgets/loaders/skeleton_widgets.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/shared/presentation/widgets/universal/transparent_toolbox.dart';
import 'package:aurogram/shared/presentation/widgets/feedback/snack_bar_service.dart';

import 'package:aurogram/platform/file_helper.dart' as file_helper;
import 'package:aurogram/core/theme/app_dimensions.dart';

class EditProfile extends StatefulWidget {
  final String? uid;
  const EditProfile({super.key, this.uid});

  @override
  EditProfileState createState() => EditProfileState();
}

class EditProfileState extends State<EditProfile> {
  final _nameController = TextEditingController();
  final _nicknameController = TextEditingController();

  String? _displayPicture;
  String? _updatedDpPath;
  // For web: store image bytes instead of path
  Uint8List? _updatedDpBytes;
  // For web: blob URL for preview
  String? _webPreviewUrl;
  String? _currentNickname;
  bool _isNicknameAvailable = true; // ignore: unused_field
  Map<String, dynamic> _nicknamePairs = {};
  bool _saving = false;
  bool _loading = true;

  final _nicknamesCollection =
      FirebaseFirestore.instance.collection('nicknames');

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      locator<UserRepository>().getUser(widget.uid!),
      _nicknamesCollection.doc('pairs').get(),
    ]);

    final userDoc = results[0] as DocumentSnapshot;
    final pairsDoc = results[1] as DocumentSnapshot;

    _nameController.text = userDoc['name'];
    _currentNickname = userDoc['nickname'];
    _nicknameController.text = _currentNickname!;
    _displayPicture = userDoc['displayPicture'];

    if (pairsDoc.exists) {
      _nicknamePairs = pairsDoc.data() as Map<String, dynamic>;
    }

    if (mounted) setState(() => _loading = false);
  }

  // ignore: unused_element
  void _checkNickname(String nickname) {
    if (nickname.length < 4) {
      setState(() => _isNicknameAvailable = false);
      return;
    }
    if (nickname.toLowerCase() == _currentNickname) {
      setState(() => _isNicknameAvailable = true);
      return;
    }
    setState(() {
      _isNicknameAvailable =
          !_nicknamePairs.containsKey(nickname.toLowerCase());
    });
  }

  void _pickImage() {
    HapticFeedback.selectionClick();
    showCupertinoModalPopup(
      context: context,
      builder: (_) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            child: const Text('Take Photo'),
            onPressed: () {
              Navigator.pop(context);
              _getImage(ImageSource.camera);
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('Choose from Library'),
            onPressed: () {
              Navigator.pop(context);
              _getImage(ImageSource.gallery);
            },
          ),
          if (_updatedDpPath != null ||
              (_displayPicture != null && _displayPicture!.isNotEmpty))
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              child: const Text('Remove Photo'),
              onPressed: () {
                Navigator.pop(context);
                setState(() => _updatedDpPath = '');
              },
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: const Text('Cancel'),
          onPressed: () => Navigator.pop(context),
        ),
      ),
    );
  }

  Future<void> _getImage(ImageSource source) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    if (picked != null && mounted) {
      if (kIsWeb) {
        // On web, read bytes and use blob URL for preview
        final bytes = await picked.readAsBytes();
        setState(() {
          _updatedDpBytes = bytes;
          _webPreviewUrl = picked.path; // Blob URL for preview
          _updatedDpPath = 'web_image'; // Flag that we have a web image
        });
      } else {
        // On mobile, use file path
        setState(() => _updatedDpPath = picked.path);
      }
    }
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();

    final name = _nameController.text.trim();
    // Username editing removed - username is now backend-only
    // final nickname = _nicknameController.text.trim().toLowerCase();

    if (name.isEmpty) {
      _showError('Please enter your name');
      return;
    }
    // Username validation removed - username is now backend-only
    // if (nickname.length < 4) {
    //   _showError('Username must be at least 4 characters');
    //   return;
    // }
    // if (!_isNicknameAvailable) {
    //   _showError('Please choose an available username');
    //   return;
    // }

    setState(() => _saving = true);
    HapticFeedback.mediumImpact();

    // Username availability check removed - username is now backend-only
    // final pairsDoc = await _nicknamesCollection.doc('pairs').get();
    // if (pairsDoc.exists) {
    //   _nicknamePairs = pairsDoc.data() as Map<String, dynamic>;
    // }
    //
    // if (_nicknamePairs.containsKey(nickname) && nickname != _currentNickname) {
    //   setState(() => _saving = false);
    //   _showError('Username was just taken');
    //   return;
    // }

    // Determine what to pass for display picture
    dynamic dpSource;
    if (kIsWeb && _updatedDpBytes != null) {
      dpSource = _updatedDpBytes; // Pass bytes on web
    } else if (_updatedDpPath != null && _updatedDpPath != 'web_image') {
      dpSource = _updatedDpPath; // Pass file path on mobile
    } else if (_updatedDpPath == '') {
      dpSource = ''; // Empty string means remove photo
    }

    final success = await UserService().updateUserProfile(
      name: name,
      // Keep existing username - don't change it
      nickname: _currentNickname,
      displayPicture: dpSource,
    );

    if (success) {
      // Username change logic removed - username is now backend-only
      // if (nickname != _currentNickname) {
      //   await _nicknamesCollection.doc('pairs').update({
      //     _currentNickname!: FieldValue.delete(),
      //   });
      // }
      if (mounted) {
        HapticFeedback.heavyImpact();
        Navigator.pop(context, true);
      }
    } else {
      setState(() => _saving = false);
      _showError('Failed to save');
    }
  }

  void _showError(String msg) {
    showCustomSnackBar(context, message: msg, backgroundColor: AppTheme.errorColor);
  }

  // Username validation removed - username is now backend-only
  bool get _canSave => _nameController.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final c = AppTheme.primaryColor;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        extendBody: true,
        body: Stack(
          children: [
            // Main content
            _loading
                ? Center(
                    child: PulsingDots(color: c, size: 10))
                : SingleChildScrollView(
                    padding: EdgeInsets.only(bottom: 260),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Custom header matching app style
                        SafeArea(
                          bottom: false,
                          child: Container(
                            height: 60,
                            padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingLg),
                            child: Row(
                              children: [
                                // Back button
                                SizedBox(
                                  width: 40,
                                  child: IconButton(
                                    icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: c),
                                    onPressed: () => Navigator.pop(context),
                                    padding: EdgeInsets.zero,
                                  ),
                                ),
                                // Centered title
                                Expanded(
                                  child: Center(
                                    child: Text('edit profile', style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      color: c,
                                      letterSpacing: 1.2,
                                    )),
                                  ),
                                ),
                                // Spacer for symmetry
                                const SizedBox(width: 40),
                              ],
                            ),
                          ),
                        ),
                        // Avatar section
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: size.height -
                                MediaQuery.of(context).padding.top -
                                MediaQuery.of(context).padding.bottom -
                                260 -
                                60,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildProfileAvatar(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
            // Bottom toolboxes
            if (!_loading)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _buildBottomToolboxes(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileAvatar() {
    final hasNewImage = _updatedDpPath != null && _updatedDpPath!.isNotEmpty;
    final hasExistingImage =
        _displayPicture != null && _displayPicture!.isNotEmpty;
    final showImage = hasNewImage || (hasExistingImage && _updatedDpPath != '');

    return Center(
      child: GestureDetector(
        onTap: _pickImage,
        child: SizedBox(
          height: 160,
          width: 160,
          child: Stack(
            children: [
              Material(
                elevation: 4,
                shape: CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: Container(
                  width: 160,
                  height: 160,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.grey.shade100,
                  child: showImage
                      ? hasNewImage
                          ? _buildNewImagePreview()
                          : UserAvatar(
                              userId: widget.uid,
                              imageUrl: _displayPicture,
                              size: 160,
                            )
                      : Icon(
                          CupertinoIcons.person_fill,
                          size: 64,
                          color: AppTheme.primaryColor.withValues(alpha: 0.3),
                        ),
                ),
              ),
              Positioned(
                bottom: 4,
                right: 4,
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      width: 3,
                    ),
                  ),
                  child: Icon(
                    CupertinoIcons.camera_fill,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build preview for newly selected image
  /// Handles both web (bytes/blob URL) and mobile (file path)
  Widget _buildNewImagePreview() {
    if (kIsWeb) {
      // On web, use Image.network with blob URL or Image.memory with bytes
      if (_webPreviewUrl != null) {
        return Image.network(_webPreviewUrl!, fit: BoxFit.cover);
      } else if (_updatedDpBytes != null) {
        return Image.memory(_updatedDpBytes!, fit: BoxFit.cover);
      }
    } else {
      // On mobile, use Image.file
      if (_updatedDpPath != null && _updatedDpPath!.isNotEmpty) {
        return Image.file(file_helper.createIOFile(_updatedDpPath!), fit: BoxFit.cover);
      }
    }
    return const SizedBox.shrink();
  }

  Widget _buildBottomToolboxes() {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.zero,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Name entry toolbox
            _buildNameToolbox(),
            // Username entry toolbox - hidden from UI, username is backend-only
            // _buildUsernameToolbox(),
            // Save button toolbox
            _buildSaveToolbox(),
            // Cancel text
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Padding(
                padding: EdgeInsets.only(top: 8, bottom: 16),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: AppTheme.textSecondaryLightColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNameToolbox() {
    return TransparentToolbox(
      content: Row(
        children: [
          Icon(
            CupertinoIcons.person,
            color: AppTheme.primaryColor.withValues(alpha: 0.85),
            size: 22,
          ),
          SizedBox(width: AppDimensions.spacingMd),
          Expanded(
            child: TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                hintText: 'Your name',
                hintStyle: TextStyle(
                  color: AppTheme.primaryColor.withValues(alpha: 0.5),
                  fontSize: 16,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.zero,
              ),
              style: TextStyle(
                color: AppTheme.primaryColor.withValues(alpha: 0.85),
                fontSize: 16,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveToolbox() {
    return TransparentToolbox.button(
      text: 'Save Changes',
      onTap: _save,
      isLoading: _saving,
      enabled: _canSave,
      icon: CupertinoIcons.checkmark_alt,
    );
  }
}
