import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/widgets/preview_boxes/gram_preview_box.dart';
import 'package:aurogram/widgets/ui/skeleton_widgets.dart';
import 'package:aurogram/models/space_types.dart';

/// Selection result from GramSelector
class GramSelection {
  final String gramId;
  final String? gramName;
  final bool showOnProfile;
  final GramType gramType;
  final bool isProfilePost; // True if posting to profile (not a space)

  GramSelection({
    required this.gramId,
    this.gramName,
    this.showOnProfile = true,
    this.gramType = GramType.open,
    this.isProfilePost = false,
  });
}

/// Widget for selecting which Gram to post to
/// Used in post creation flows (video, text, audio)
class GramSelector extends StatefulWidget {
  final String? initialGramId;
  final ValueChanged<GramSelection> onSelectionChanged;
  final bool showProfileToggle;

  const GramSelector({
    super.key,
    this.initialGramId,
    required this.onSelectionChanged,
    this.showProfileToggle = true,
  });

  @override
  State<GramSelector> createState() => _GramSelectorState();
}

class _GramSelectorState extends State<GramSelector> {
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  String? _selectedGramId;
  bool _showOnProfile = true;
  List<Map<String, dynamic>> _userGrams = [];
  bool _isLoading = true;
  bool _isProfileSelected = false; // True when "My Profile" is selected

  @override
  void initState() {
    super.initState();
    _selectedGramId = widget.initialGramId;
    _loadUserGrams();
  }

  Future<void> _loadUserGrams() async {
    if (_currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      // Get all spaces the user is a member of
      final userSpacesSnapshot = await FirebaseFirestore.instance
          .collection('userSpaces')
          .doc(_currentUser!.uid)
          .collection('spaces')
          .get();

      final grams = <Map<String, dynamic>>[];
      
      // Add "My Profile" option first
      grams.add({
        'id': 'profile',
        'isProfile': true,
        'name': 'My Profile',
      });

      // Add user's spaces
      for (final doc in userSpacesSnapshot.docs) {
        final spaceId = doc.id;
        final role = doc.data()['role'] as String?;
        // Only allow posting if user is creator, admin, or member (not just requested)
        if (role == 'creator' || role == 'admin' || role == 'member' || role == 'owner') {
          grams.add({
            'id': spaceId,
            'isProfile': false,
          });
        }
      }

      // If no gram selected, default to profile
      if (_selectedGramId == null && grams.isNotEmpty) {
        _selectedGramId = grams.first['id'] as String;
        _isProfileSelected = grams.first['isProfile'] as bool? ?? false;
      }

      if (mounted) {
        setState(() {
          _userGrams = grams;
          _isLoading = false;
        });

        // Notify initial selection
        if (_selectedGramId != null) {
          _notifySelection();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _notifySelection() {
    if (_selectedGramId != null) {
      widget.onSelectionChanged(GramSelection(
        gramId: _selectedGramId!,
        showOnProfile: _showOnProfile,
        gramType: GramType.public,
        isProfilePost: _isProfileSelected,
      ));
    }
  }

  void _showGramPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _GramPickerSheet(
        grams: _userGrams,
        selectedGramId: _selectedGramId,
        onGramSelected: (gramId) {
          // Find the selected gram to check if it's a profile post
          final selectedGram = _userGrams.firstWhere(
            (g) => g['id'] == gramId,
            orElse: () => {'isProfile': false},
          );
          setState(() {
            _selectedGramId = gramId;
            _isProfileSelected = selectedGram['isProfile'] as bool? ?? false;
          });
          _notifySelection();
          Navigator.of(context).pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: List.generate(3, (_) => const Padding(
            padding: EdgeInsets.only(right: 8),
            child: SkeletonBox(width: 80, height: 36, borderRadius: 18),
          )),
        ),
      );
    }

    if (_userGrams.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Text(
          'No grams available',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Gram selector
        GestureDetector(
          onTap: _showGramPicker,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isDark
                  ? Theme.of(context).colorScheme.surface
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.primaryColor.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.eco_outlined,
                  size: 20,
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(width: 10),
                Text(
                  'Post to:',
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _selectedGramId != null
                      ? GramPreviewBox(
                          gram: _selectedGramId!,
                          compact: true,
                        )
                      : Text(
                          'Select a gram',
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.5),
                          ),
                        ),
                ),
                Icon(
                  CupertinoIcons.chevron_down,
                  size: 16,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        ),

        // Show on profile toggle (only if not posting to own profile)
        if (widget.showProfileToggle &&
            _selectedGramId != null &&
            !_isProfileSelected)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                CupertinoSwitch(
                  value: _showOnProfile,
                  onChanged: (value) {
                    setState(() {
                      _showOnProfile = value;
                    });
                    _notifySelection();
                  },
                  activeTrackColor: AppTheme.primaryColor,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Also show on my profile',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Bottom sheet for selecting a gram
class _GramPickerSheet extends StatelessWidget {
  final List<Map<String, dynamic>> grams;
  final String? selectedGramId;
  final ValueChanged<String> onGramSelected;

  const _GramPickerSheet({
    required this.grams,
    this.selectedGramId,
    required this.onGramSelected,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Theme.of(context).colorScheme.surface
            : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Title
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Select Gram',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),

          // Gram list
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.5,
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: grams.length,
              padding: const EdgeInsets.only(bottom: 20),
              itemBuilder: (context, index) {
                final gram = grams[index];
                final gramId = gram['id'] as String;
                final isProfile = gram['isProfile'] as bool? ?? false;
                final isSelected = gramId == selectedGramId;

                return ListTile(
                  onTap: () => onGramSelected(gramId),
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isProfile
                          ? AppTheme.primaryColor.withValues(alpha: 0.1)
                          : Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isProfile ? Icons.person : Icons.eco_outlined,
                      color: isProfile
                          ? AppTheme.primaryColor
                          : Colors.grey.shade600,
                    ),
                  ),
                  title: isProfile
                      ? Text(
                          'My Profile',
                          style: TextStyle(
                            fontWeight:
                                isSelected ? FontWeight.w600 : FontWeight.normal,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        )
                      : GramPreviewBox(
                          gram: gramId,
                          compact: true,
                        ),
                  subtitle: isProfile
                      ? Text(
                          'Post to your profile feed',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.6),
                          ),
                        )
                      : null,
                  trailing: isSelected
                      ? Icon(
                          CupertinoIcons.checkmark_circle_fill,
                          color: AppTheme.primaryColor,
                        )
                      : null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}




