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
import 'package:aurogram/utils/theme/header_style.dart';
import 'package:aurogram/utils/logging/app_logger.dart';

// Conditional import for dart:io
import 'dart:io'
    if (dart.library.html) 'package:aurogram/platform/io_stub.dart';
import 'package:aurogram/platform/file_helper.dart' as file_helper;
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
  dynamic _pickedImage;
  Uint8List? _pickedImageBytes;
  String? _webPreviewUrl;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 280),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
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
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _pickedImageBytes = bytes;
          _webPreviewUrl = pickedFile.path;
        });
      } else {
        setState(() => _pickedImage = File(pickedFile.path));
      }
    }
  }

  bool get _hasImage =>
      kIsWeb ? _pickedImageBytes != null : _pickedImage != null;

  Widget _buildImagePreview() {
    if (kIsWeb && _webPreviewUrl != null) {
      return Image.network(_webPreviewUrl!, fit: BoxFit.cover);
    } else if (!kIsWeb && _pickedImage != null) {
      return Image.file(file_helper.createIOFile(_pickedImage.path),
          fit: BoxFit.cover);
    }
    return const SizedBox.shrink();
  }

  Future<void> _handleCreate() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _progressMessage = "Creating your sub-gram...";
    });

    try {
      final newSpace = Space(
        name: _nameController.text.trim(),
        searchName: _nameController.text.trim().toLowerCase(),
        spaceType: _selectedSpaceType,
        description: _descriptionController.text.trim(),
        displayPicture: kIsWeb ? null : _pickedImage?.path,
        adminOnlyPosting: _adminOnlyPosting,
        limitedVisibility: isPrivateSpaceType(_selectedSpaceType),
      );

      String spaceId;
      if (kIsWeb) {
        spaceId = await SpaceService()
            .addSpaceWithBytes(newSpace, _pickedImageBytes, _updateProgress);
      } else {
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
    showCustomSnackBar(context, message: "Failed to create sub-gram. Please try again.");
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeHelper.isDarkMode(context);
    return Scaffold(
      extendBody: true,
      backgroundColor:
          isDark ? AppTheme.scaffoldDarkColor : AppTheme.scaffoldLightColor,
      appBar: AppHeaderStyle.buildStandardAppBar(
        context: context,
        title: 'new sub-gram',
        leadingWidget: AppHeaderStyle.buildCompactIconButton(
          icon: Icons.arrow_back_ios_new_rounded,
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Back',
        ),
        automaticallyImplyLeading: false,
      ),
      body: _isLoading ? _buildLoadingView(isDark) : _buildForm(context),
    );
  }

  Widget _buildLoadingView(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          PulsingDots(size: 10),
          const SizedBox(height: AppDimensions.spacingXl),
          Text(
            _progressMessage,
            textAlign: TextAlign.center,
            style: ThemeHelper.captionStyleFor(context),
          ),
        ],
      ),
    );
  }

  /// Max width for the form on tablet/desktop so content doesn't stretch.
  static const double _kFormMaxWidth = 440.0;

  Widget _buildForm(BuildContext context) {
    final isDark = ThemeHelper.isDarkMode(context);
    final padding = AppTheme.pagePadding(context);
    final spacing = AppTheme.sectionSpacing(context);
    final isWide = MediaQuery.sizeOf(context).width >= 600;

    final formContent = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionCard(
          context: context,
          isDark: isDark,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionLabel(context, 'Details'),
              SizedBox(height: spacing),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildImagePicker(context, isDark, compact: true),
                  SizedBox(width: AppDimensions.spacingLg),
                  Expanded(child: _buildNameField(context, isDark)),
                ],
              ),
              SizedBox(height: spacing),
              _buildDescriptionField(context, isDark),
            ],
          ),
        ),
        SizedBox(height: spacing),
        _buildSectionCard(
          context: context,
          isDark: isDark,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionLabel(context, 'Visibility'),
              SizedBox(height: spacing - 2),
              _buildGroupTypeSelector(context, isDark),
              SizedBox(height: spacing - 4),
              Text(
                'Type cannot be changed later.',
                style: ThemeHelper.captionStyleFor(context)
                    .copyWith(fontSize: AppTheme.fontSizeS),
              ),
            ],
          ),
        ),
        SizedBox(height: spacing),
        _buildSectionCard(
          context: context,
          isDark: isDark,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionLabel(context, 'Posting'),
              SizedBox(height: spacing - 2),
              _buildPostingPermissionSelector(context, isDark),
            ],
          ),
        ),
        SizedBox(height: AppDimensions.spacingLg),
        _buildCreateButton(context),
        SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
      ],
    );

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: FadeTransition(
        opacity: _animation,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              padding,
              isWide ? 28 : 20,
              padding,
              32,
            ),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _kFormMaxWidth),
                  child: formContent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String text) {
    return Text(
      text.toUpperCase(),
      style: ThemeHelper.captionStyleFor(context).copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
        fontSize: AppTheme.fontSizeS,
      ),
    );
  }

  Widget _buildSectionCard({
    required BuildContext context,
    required bool isDark,
    required Widget child,
  }) {
    return Container(
      padding: EdgeInsets.all(AppTheme.cardPadding(context)),
      decoration: ThemeHelper.cardDecorationFor(context),
      child: child,
    );
  }

  Widget _buildImagePicker(BuildContext context, bool isDark,
      {bool compact = false}) {
    final size = compact
        ? 56.0
        : AppTheme.responsiveValue<double>(
            context,
            mobile: 120,
            tablet: 136,
            desktop: 140,
          );
    final iconSize = compact
        ? 24.0
        : AppTheme.responsiveValue<double>(
            context,
            mobile: 36,
            tablet: 40,
            desktop: 42,
          );
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color:
              isDark ? AppTheme.surfaceDarkColor : AppTheme.surfaceLightColor,
          border: Border.all(
            color: isDark
                ? AppTheme.primaryColor.withValues(alpha: 0.4)
                : AppTheme.primaryColor.withValues(alpha: 0.2),
            width: compact ? 1.5 : 2,
          ),
          boxShadow: compact
              ? null
              : [
                  BoxShadow(
                    color: (isDark ? Colors.black : Colors.black26)
                        .withValues(alpha: isDark ? 0.4 : 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        clipBehavior: Clip.antiAlias,
        child: _hasImage
            ? _buildImagePreview()
            : Icon(
                CupertinoIcons.camera_fill,
                size: iconSize,
                color: isDark
                    ? AppTheme.textSecondaryDarkColor
                    : AppTheme.textSecondaryLightColor,
              ),
      ),
    );
  }

  InputDecoration _inputDecoration(
      BuildContext context, bool isDark, String label,
      {String? hint}) {
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : AppTheme.primaryColor.withValues(alpha: 0.2);
    final fillColor = isDark
        ? Colors.white.withValues(alpha: 0.04)
        : AppTheme.surfaceLightColor;
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: fillColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        borderSide: BorderSide(color: AppTheme.primaryColor, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        borderSide: const BorderSide(color: AppTheme.errorColor),
      ),
      labelStyle: ThemeHelper.captionStyleFor(context),
      hintStyle: ThemeHelper.captionStyleFor(context),
    );
  }

  Widget _buildNameField(BuildContext context, bool isDark) {
    return TextFormField(
      controller: _nameController,
      maxLines: 1,
      validator: (value) =>
          value?.trim().isEmpty ?? true ? 'Enter a sub-gram name' : null,
      style: ThemeHelper.bodyTextStyleFor(context).copyWith(
        fontSize: AppTheme.fontSizeRegular,
      ),
      decoration: _inputDecoration(context, isDark, 'Sub-gram name',
          hint: 'e.g. Weekend Vibes'),
    );
  }

  Widget _buildDescriptionField(BuildContext context, bool isDark) {
    return TextFormField(
      controller: _descriptionController,
      maxLines: 3,
      minLines: 1,
      style: ThemeHelper.bodyTextStyleFor(context).copyWith(
        fontSize: AppTheme.fontSizeBody,
      ),
      decoration: _inputDecoration(context, isDark, 'Description (optional)',
          hint: 'What’s this sub-gram about?'),
    );
  }

  Widget _buildGroupTypeSelector(BuildContext context, bool isDark) {
    return _buildChipSelector<SpaceType>(
      context: context,
      isDark: isDark,
      options: [
        _ChipOption(SpaceType.public, 'Public', CupertinoIcons.globe,
            AppTheme.grassGreen),
        _ChipOption(SpaceType.private, 'Private', CupertinoIcons.lock,
            AppTheme.warningColor),
      ],
      selected: _selectedSpaceType,
      onSelected: (v) => setState(() => _selectedSpaceType = v),
      description: _selectedSpaceType == SpaceType.public
          ? 'Anyone can find and join.'
          : 'Invite only. Content is private.',
    );
  }

  Widget _buildPostingPermissionSelector(BuildContext context, bool isDark) {
    return _buildChipSelector<bool>(
      context: context,
      isDark: isDark,
      options: [
        _ChipOption(false, 'All members', CupertinoIcons.person_3,
            AppTheme.primaryColor),
        _ChipOption(
            true,
            'Admins only',
            CupertinoIcons.person_crop_circle_badge_checkmark,
            AppTheme.pastelLavender),
      ],
      selected: _adminOnlyPosting,
      onSelected: (v) => setState(() => _adminOnlyPosting = v),
      description: _adminOnlyPosting
          ? 'Only admins can post; members can reply.'
          : 'Any member can create posts.',
    );
  }

  Widget _buildChipSelector<T>({
    required BuildContext context,
    required bool isDark,
    required List<_ChipOption<T>> options,
    required T selected,
    required ValueChanged<T> onSelected,
    required String description,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: options.asMap().entries.map((entry) {
            final i = entry.key;
            final opt = entry.value;
            final isSelected = selected == opt.value;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                    right: i == 0 ? 6 : 0,
                    left: i == options.length - 1 ? 6 : 0),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => onSelected(opt.value),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                        color: isSelected
                            ? opt.color.withValues(alpha: 0.15)
                            : (isDark
                                ? Colors.white.withValues(alpha: 0.04)
                                : AppTheme.surfaceLightColor),
                        border: Border.all(
                          color: isSelected
                              ? opt.color.withValues(alpha: 0.5)
                              : (isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : AppTheme.primaryColor
                                      .withValues(alpha: 0.15)),
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            opt.icon,
                            size: 20,
                            color: isSelected
                                ? opt.color
                                : (isDark
                                    ? AppTheme.textSecondaryDarkColor
                                    : AppTheme.textSecondaryLightColor),
                          ),
                          SizedBox(width: AppDimensions.spacingSm),
                          Flexible(
                            child: Text(
                              opt.label,
                              style: ThemeHelper.bodyTextStyleFor(context)
                                  .copyWith(
                                fontSize: AppTheme.fontSizeM,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                color: isSelected
                                    ? opt.color
                                    : (isDark
                                        ? AppTheme.textDarkColor
                                        : AppTheme.textLightColor),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        SizedBox(height: AppDimensions.spacingMdSm),
        Text(
          description,
          style: ThemeHelper.captionStyleFor(context)
              .copyWith(fontSize: AppTheme.fontSizeS),
        ),
      ],
    );
  }

  Widget _buildCreateButton(BuildContext context) {
    final isDark = ThemeHelper.isDarkMode(context);
    final cardColor = isDark ? AppTheme.cardDarkColor : AppTheme.cardLightColor;
    final foregroundColor =
        isDark ? AppTheme.textDarkColor : AppTheme.textLightColor;
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: _isLoading ? null : _handleCreate,
        style: FilledButton.styleFrom(
          backgroundColor: cardColor,
          foregroundColor: foregroundColor,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMdLg),
          ),
          elevation: 0,
        ),
        child: Text(
          'Create Sub-gram',
          style: TextStyle(
            fontSize: AppTheme.fontSizeL,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _ChipOption<T> {
  final T value;
  final String label;
  final IconData icon;
  final Color color;

  _ChipOption(this.value, this.label, this.icon, this.color);
}
