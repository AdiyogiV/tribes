import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:aurogram/pages/spaces/space_screen.dart';
import 'package:aurogram/models/space.dart';
import 'package:aurogram/models/space_types.dart';
import 'package:aurogram/services/space_service.dart';
import 'package:aurogram/widgets/ui/skeleton_widgets.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/utils/theme/theme_helper.dart';
import 'package:aurogram/utils/logging/app_logger.dart';

// Conditional import for dart:io
import 'dart:io' if (dart.library.html) 'package:aurogram/platform/io_stub.dart';
import 'package:aurogram/utils/theme/app_dimensions.dart';
import 'package:aurogram/widgets/common/snack_bar_service.dart';

class SpaceCreationPage extends StatefulWidget {
  const SpaceCreationPage({super.key});

  @override
  SpaceCreationPageState createState() => SpaceCreationPageState();
}

class SpaceCreationPageState extends State<SpaceCreationPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _picker = ImagePicker();

  late AnimationController _animationController;
  late Animation<double> _animation;

  bool _isLoading = false;
  String _progressMessage = '';
  SpaceType _selectedSpaceType = SpaceType.public;
  bool _adminOnlyPosting = false;
  File? _pickedImage;
  // For web: store image bytes
  Uint8List? _pickedImageBytes;
  // For web: blob URL for preview
  String? _webPreviewUrl;

  @override
  void initState() {
    super.initState();
    _setupAnimation();
  }

  void _setupAnimation() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null && mounted) {
      if (kIsWeb) {
        // On web, read bytes and use blob URL for preview
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _pickedImageBytes = bytes;
          _webPreviewUrl = pickedFile.path;
        });
      } else {
        // On mobile, use file
        setState(() => _pickedImage = File(pickedFile.path));
      }
    }
  }

  /// Check if an image has been selected (works for both web and mobile)
  bool get _hasImage => kIsWeb ? _pickedImageBytes != null : _pickedImage != null;

  /// Get the appropriate ImageProvider based on platform
  ImageProvider _getImageProvider() {
    if (kIsWeb && _webPreviewUrl != null) {
      return NetworkImage(_webPreviewUrl!);
    } else if (!kIsWeb && _pickedImage != null) {
      return FileImage(_pickedImage!);
    }
    return const AssetImage('assets/placeholder.png');
  }

  Future<void> _handleCreate() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _progressMessage = "Creating your group...";
    });

    try {
      final newSpace = Space(
        name: _nameController.text.trim(),
        searchName: _nameController.text.trim().toLowerCase(),
        spaceType: _selectedSpaceType,
        description: _descriptionController.text.trim(),
        displayPicture: kIsWeb ? null : _pickedImage?.path,
        adminOnlyPosting: _adminOnlyPosting,
        // Private groups are always hidden, public groups are always searchable
        limitedVisibility: isPrivateSpaceType(_selectedSpaceType),
      );

      String spaceId;
      if (kIsWeb) {
        // Use bytes-based upload on web
        spaceId = await SpaceService()
            .addSpaceWithBytes(newSpace, _pickedImageBytes, _updateProgress);
      } else {
        // Use file path on mobile
        spaceId = await SpaceService().addSpace(newSpace, _updateProgress);
      }
      _navigateToSpaceScreen(spaceId);
    } catch (e) {
      _handleError(e);
    }
  }

  void _updateProgress(String message) {
    if (mounted) setState(() => _progressMessage = message);
  }

  void _navigateToSpaceScreen(String spaceId) {
    Navigator.of(context).pushReplacement(
        CupertinoPageRoute(builder: (context) => SpaceScreen(rid: spaceId)));
  }

  void _handleError(dynamic error) {
    AppLogger.e('Error creating Group',
        category: LogCategory.general, data: {'error': error.toString()});
    setState(() {
      _isLoading = false;
      _progressMessage = "Error: ${error.toString()}";
    });
    showCustomSnackBar(context, message: "Failed to create group. Please try again.");
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      child: CupertinoPageScaffold(
        navigationBar: _buildNavigationBar(),
        child: _isLoading ? _buildLoadingView() : _buildForm(),
      ),
    );
  }

  CupertinoNavigationBar _buildNavigationBar() {
    return CupertinoNavigationBar(
      middle: Text(
        'Create New Gram',
        style: TextStyle(
            color: CupertinoTheme.of(context).primaryContrastingColor),
      ),
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          PulsingDots(size: 10),
          const SizedBox(height: AppDimensions.spacingLg),
          Text(_progressMessage, textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Stack(
        children: [
          FadeTransition(
            opacity: _animation,
            child: Form(
              key: _formKey,
              child: ListView(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                children: [
                  SizedBox(height: AppDimensions.spacingXxl),
                  _buildImagePicker(),
                  SizedBox(height: AppDimensions.spacingLargeSection),
                  _buildNameField(),
                  SizedBox(height: AppDimensions.spacingXl),
                  _buildDescriptionField(),
                  SizedBox(height: AppDimensions.spacingXxl),
                  Divider(),
                  SizedBox(height: AppDimensions.spacingXxl),
                  _buildGroupTypeSelector(),
                  SizedBox(height: AppDimensions.spacingSm),
                  _buildGroupTypeWarning(),
                  SizedBox(height: AppDimensions.spacingXxl),
                  _buildPostingPermissionSelector(),
                  SizedBox(height: AppDimensions.spacingXxl),
                  Divider(),
                  SizedBox(height: 500), // Space for FAB
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 16,
            right: 16,
            child: _buildFAB(),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePicker() {
    return GestureDetector(
      onTap: _pickImage,
      child: Center(
        child: Material(
          shape: CircleBorder(),
          elevation: 1,
          child: Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              image: _hasImage
                  ? DecorationImage(
                      image: _getImageProvider(), fit: BoxFit.cover)
                  : null,
            ),
            child: !_hasImage
                ? Icon(CupertinoIcons.camera, size: 40)
                : null,
          ),
        ),
      ),
    );
  }

  Widget _buildNameField() {
    return _buildTextField(
      maxLines: 1,
      controller: _nameController,
      label: 'Gram Name',
      validator: (value) =>
          value?.isEmpty ?? true ? 'Please enter a group name' : null,
    );
  }

  Widget _buildDescriptionField() {
    return _buildTextField(
      controller: _descriptionController,
      label: 'Description (optional)',
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    int maxLines = 5,
    int minLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      minLines: minLines,
      validator: validator,
      decoration: ThemeHelper.inputDecoration(labelText: label),
    );
  }

  Widget _buildGroupTypeSelector() {
    return _buildSelector(
      title: 'Gram Type',
      options: [
        SelectorOption(SpaceType.public, 'Public', CupertinoIcons.globe,
            AppTheme.successColor),
        SelectorOption(SpaceType.private, 'Private', CupertinoIcons.lock,
            AppTheme.warningColor),
      ],
      selectedOption: _selectedSpaceType,
      onOptionSelected: (option) {
        setState(() {
          _selectedSpaceType = option;
        });
      },
      description: _selectedSpaceType == SpaceType.public
          ? 'Anyone can find and join this gram. All content is visible to the public.'
          : 'Only approved members can access this group. Content is private.',
    );
  }

  Widget _buildGroupTypeWarning() {
    return Container(
      padding: EdgeInsets.all(AppDimensions.paddingSm),
      decoration: BoxDecoration(
        color: AppTheme.warningColor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
      ),
      child: Row(
        children: [
          Icon(CupertinoIcons.info_circle, color: AppTheme.warningColor),
          SizedBox(width: AppDimensions.spacingSm),
          Expanded(
            child: Text(
              'Gram type is permanent, it cannot be changed later.',
              style: TextStyle(
                color: AppTheme.textLightColor,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostingPermissionSelector() {
    return _buildSelector(
      title: 'Posting Permissions',
      options: [
        SelectorOption(false, 'All Members', CupertinoIcons.person_3,
            AppTheme.primaryColor),
        SelectorOption(
            true,
            'Admins Only',
            CupertinoIcons.person_crop_circle_badge_checkmark,
            AppTheme.pastelLavender),
      ],
      selectedOption: _adminOnlyPosting,
      onOptionSelected: (option) =>
          setState(() => _adminOnlyPosting = option),
      description: _adminOnlyPosting
          ? 'Only administrators can post on the group feed, members can reply.'
          : 'Any member can create posts in this group.',
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
        Text(
          title,
          style: ThemeHelper.subheadingStyle,
        ),
        SizedBox(height: AppDimensions.spacingSm),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
            border: Border.all(color: AppTheme.primaryLightColor),
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
                            ? option.color.withValues(alpha: 0.2)
                            : AppTheme.scaffoldLightColor,
                        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(option.icon,
                              color: isSelected
                                  ? option.color
                                  : AppTheme.textLightColor),
                          SizedBox(width: AppDimensions.spacingSm),
                          Text(
                            option.label,
                            style: TextStyle(
                              color: isSelected
                                  ? option.color
                                  : AppTheme.textLightColor,
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
          style: TextStyle(color: AppTheme.textLightColor, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildFAB() {
    return SafeArea(
      child: FloatingActionButton.extended(
        onPressed: _handleCreate,
        icon: Icon(CupertinoIcons.add),
        label: Text("Create Group"),
        elevation: ThemeHelper.fabTheme.elevation,
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: AppTheme.textDarkColor,
        shape: ThemeHelper.fabTheme.shape,
      ),
    );
  }
}

class SelectorOption<T> {
  final T value;
  final String label;
  final IconData icon;
  final Color color;

  SelectorOption(this.value, this.label, this.icon, this.color);
}
