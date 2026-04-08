import 'package:flutter/material.dart';
import 'package:aurogram/widgets/ui/common_widgets.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/utils/theme/app_dimensions.dart';

/// Bottom sheet for selecting a gram to repost to
class GramSelectorSheet extends StatefulWidget {
  final Function(String gramId, String gramName) onGramSelected;
  final bool showProfileOption;

  const GramSelectorSheet({
    super.key,
    required this.onGramSelected,
    this.showProfileOption = true,
  });

  @override
  State<GramSelectorSheet> createState() => _GramSelectorSheetState();
}

class _GramSelectorSheetState extends State<GramSelectorSheet> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  List<Map<String, dynamic>> _grams = [];
  bool _loading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadGrams();
  }

  Future<void> _loadGrams() async {
    if (_currentUser == null) return;

    try {
      // User's grams are in userSpaces/{uid}/spaces (doc id = space id)
      final userSpacesSnapshot = await _firestore
          .collection('userSpaces')
          .doc(_currentUser!.uid)
          .collection('spaces')
          .where('role',
              whereIn: ['member', 'admin', 'creator', 'owner']).get();

      final gramIds = userSpacesSnapshot.docs.map((d) => d.id).toList();

      if (gramIds.isEmpty) {
        setState(() => _loading = false);
        return;
      }

      // Fetch gram details
      final grams = <Map<String, dynamic>>[];
      for (final gramId in gramIds) {
        final gramDoc = await _firestore.collection('spaces').doc(gramId).get();
        if (gramDoc.exists) {
          grams.add({
            'id': gramId,
            'name': gramDoc.data()?['name'] ?? 'Unnamed Gram',
            'image': gramDoc.data()?['displayPicture'] as String?,
            'memberCount': (gramDoc.data()?['members'] as List?)?.length ?? 0,
          });
        }
      }

      setState(() {
        _grams = grams;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredGrams {
    if (_searchQuery.isEmpty) return _grams;
    return _grams.where((gram) {
      final name = gram['name'] as String;
      return name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.scaffoldColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.textSecondaryColor.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.all(AppDimensions.paddingXl),
              child: Row(
                children: [
                  Text(
                    'Repost to...',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textColor,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close, color: AppTheme.textSecondaryColor),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Search bar
            if (_grams.length > 5)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search grams...',
                    prefixIcon:
                        Icon(Icons.search, color: AppTheme.textSecondaryColor),
                    filled: true,
                    fillColor: AppTheme.cardColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
              ),

            const SizedBox(height: AppDimensions.spacingMd),

            // Profile option
            if (widget.showProfileOption)
              _buildOption(
                icon: Icons.person_outline,
                title: 'My Profile',
                subtitle: 'Repost to your profile',
                onTap: () {
                  Navigator.pop(context);
                  widget.onGramSelected('profile', 'My Profile');
                },
              ),

            // Grams list
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(40),
                child: AppLoadingIndicator(),
              )
            else if (_filteredGrams.isEmpty)
              Padding(
                padding: const EdgeInsets.all(40),
                child: Text(
                  _searchQuery.isEmpty
                      ? 'No grams available'
                      : 'No grams found',
                  style: TextStyle(color: AppTheme.textSecondaryColor),
                ),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.5,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _filteredGrams.length,
                  itemBuilder: (context, index) {
                    final gram = _filteredGrams[index];
                    return _buildGramOption(
                      gramId: gram['id'] as String,
                      name: gram['name'] as String,
                      image: gram['image'] as String?,
                      memberCount: gram['memberCount'] as int,
                    );
                  },
                ),
              ),

            const SizedBox(height: AppDimensions.spacingXl),
          ],
        ),
      ),
    );
  }

  Widget _buildOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppTheme.accentColor.withValues(alpha: 0.1),
        child: Icon(icon, color: AppTheme.accentColor),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: AppTheme.textColor,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 13,
          color: AppTheme.textSecondaryColor,
        ),
      ),
      onTap: onTap,
    );
  }

  Widget _buildGramOption({
    required String gramId,
    required String name,
    String? image,
    required int memberCount,
  }) {
    return ListTile(
      leading: CircleAvatar(
        backgroundImage:
            image != null ? CachedNetworkImageProvider(image) : null,
        backgroundColor: AppTheme.cardColor,
        child: image == null
            ? Icon(Icons.groups, color: AppTheme.textSecondaryColor, size: 20)
            : null,
      ),
      title: Text(
        name,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: AppTheme.textColor,
        ),
      ),
      subtitle: Text(
        '$memberCount ${memberCount == 1 ? 'member' : 'members'}',
        style: TextStyle(
          fontSize: 13,
          color: AppTheme.textSecondaryColor,
        ),
      ),
      onTap: () {
        Navigator.pop(context);
        widget.onGramSelected(gramId, name);
      },
    );
  }
}

/// Show the gram selector sheet
Future<void> showGramSelector({
  required BuildContext context,
  required Function(String gramId, String gramName) onGramSelected,
  bool showProfileOption = true,
}) {
  return AppBottomSheet.show(
    context,
    child: GramSelectorSheet(
      onGramSelected: onGramSelected,
      showProfileOption: showProfileOption,
    ),
  );
}
