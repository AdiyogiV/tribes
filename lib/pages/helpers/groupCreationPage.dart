import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:aurogram/pages/spaces/spaceScreen.dart';
import 'package:aurogram/models/space.dart';
import 'package:aurogram/models/space_types.dart';
import 'package:aurogram/services/space_service.dart';
import 'package:aurogram/widgets/ui/skeleton_widgets.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/utils/theme/theme_helper.dart';
import 'package:aurogram/utils/logging/app_logger.dart';

class SpaceCreationPage extends StatefulWidget {
  const SpaceCreationPage({Key? key}) : super(key: key);

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
      setState(() => _pickedImage = File(pickedFile.path));
    }
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
        displayPicture: _pickedImage?.path,
        adminOnlyPosting: _adminOnlyPosting,
        // Private groups are always hidden, public groups are always searchable
        limitedVisibility: isPrivateSpaceType(_selectedSpaceType),
      );

      final spaceId = await SpaceService().addSpace(newSpace, _updateProgress);
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
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to create group. Please try again.")));
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
          const SizedBox(height: 16),
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
                  SizedBox(height: 24),
                  _buildImagePicker(),
                  SizedBox(height: 40),
                  _buildNameField(),
                  SizedBox(height: 20),
                  _buildDescriptionField(),
                  SizedBox(height: 24),
                  Divider(),
                  SizedBox(height: 24),
                  _buildGroupTypeSelector(),
                  SizedBox(height: 8),
                  _buildGroupTypeWarning(),
                  SizedBox(height: 24),
                  _buildPostingPermissionSelector(),
                  SizedBox(height: 24),
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
              image: _pickedImage != null
                  ? DecorationImage(
                      image: FileImage(_pickedImage!), fit: BoxFit.cover)
                  : null,
            ),
            child: _pickedImage == null
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
          _selectedSpaceType = option as SpaceType;
        });
      },
      description: _selectedSpaceType == SpaceType.public
          ? 'Anyone can find and join this gram. All content is visible to the public.'
          : 'Only approved members can access this group. Content is private.',
    );
  }

  Widget _buildGroupTypeWarning() {
    return Container(
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppTheme.warningColor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(CupertinoIcons.info_circle, color: AppTheme.warningColor),
          SizedBox(width: 8),
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
          setState(() => _adminOnlyPosting = option as bool),
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
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
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
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(option.icon,
                              color: isSelected
                                  ? option.color
                                  : AppTheme.textLightColor),
                          SizedBox(width: 8),
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
        SizedBox(height: 8),
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
