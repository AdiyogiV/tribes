import 'package:flutter/material.dart';
import 'package:aurogram/widgets/ui/common_widgets.dart';
import 'package:flutter/services.dart';
import 'package:aurogram/utils/theme/app_dimensions.dart';

/// Location search trigger button that opens the search overlay.
class LocationSearchButton extends StatelessWidget {
  final String? place;
  final Color primaryColor;
  final bool dark;
  final VoidCallback onTap;
  final VoidCallback onClear;

  const LocationSearchButton({
    super.key,
    required this.place,
    required this.primaryColor,
    required this.dark,
    required this.onTap,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final c = primaryColor;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(AppDimensions.radiusMdLg),
          border: Border.all(color: c.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            Icon(
              Icons.search_rounded,
              color: c.withValues(alpha: 0.4),
              size: 20,
            ),
            const SizedBox(width: AppDimensions.spacingMd),
            Expanded(
              child: Text(
                place ?? 'Tap to search city...',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight:
                      place != null ? FontWeight.w500 : FontWeight.w400,
                  color: place != null ? c : c.withValues(alpha: 0.35),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (place != null)
              GestureDetector(
                onTap: () {
                  onClear();
                  HapticFeedback.selectionClick();
                },
                child: Icon(
                  Icons.clear_rounded,
                  size: 18,
                  color: c.withValues(alpha: 0.4),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Shows the location search overlay as a modal bottom sheet.
void openLocationSearchOverlay({
  required BuildContext context,
  required Color primaryColor,
  required bool dark,
  required Color cardColor,
  required TextEditingController searchController,
  required ValueNotifier<List<Map<String, dynamic>>> resultsNotifier,
  required ValueNotifier<bool> searchingNotifier,
  required Function(String) onSearch,
  required Function(Map<String, dynamic>) onSelect,
}) {
  // Clear previous search
  searchController.clear();
  resultsNotifier.value = [];

  AppBottomSheet.show(
    context,
    child: LocationSearchSheet(
      primaryColor: primaryColor,
      isDark: dark,
      cardColor: cardColor,
      initialQuery: '',
      onSearch: onSearch,
      onSelect: onSelect,
      searchController: searchController,
      resultsNotifier: resultsNotifier,
      searchingNotifier: searchingNotifier,
      onClear: () {
        searchController.clear();
        resultsNotifier.value = [];
      },
    ),
  );
}

/// Fullscreen location search sheet for better UX.
/// Uses ValueListenableBuilder for efficient rebuilds (no polling timer).
class LocationSearchSheet extends StatefulWidget {
  final Color primaryColor;
  final bool isDark;
  final Color cardColor;
  final String initialQuery;
  final Function(String) onSearch;
  final Function(Map<String, dynamic>) onSelect;
  final TextEditingController searchController;
  final ValueNotifier<List<Map<String, dynamic>>> resultsNotifier;
  final ValueNotifier<bool> searchingNotifier;
  final VoidCallback onClear;

  const LocationSearchSheet({
    super.key,
    required this.primaryColor,
    required this.isDark,
    required this.cardColor,
    required this.initialQuery,
    required this.onSearch,
    required this.onSelect,
    required this.searchController,
    required this.resultsNotifier,
    required this.searchingNotifier,
    required this.onClear,
  });

  @override
  State<LocationSearchSheet> createState() => _LocationSearchSheetState();
}

class _LocationSearchSheetState extends State<LocationSearchSheet> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.primaryColor;
    final dark = widget.isDark;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: dark ? Theme.of(context).scaffoldBackgroundColor : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: c.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Search Location',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: c,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(AppDimensions.paddingSm),
                    decoration: BoxDecoration(
                      color: c.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: c.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Search field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Container(
              decoration: BoxDecoration(
                color: c.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                border: Border.all(
                  color: _focusNode.hasFocus
                      ? c.withValues(alpha: 0.3)
                      : c.withValues(alpha: 0.1),
                  width: 1.5,
                ),
              ),
              child: ValueListenableBuilder<bool>(
                valueListenable: widget.searchingNotifier,
                builder: (context, isSearching, _) {
                  return TextField(
                    controller: widget.searchController,
                    focusNode: _focusNode,
                    autofocus: true,
                    style: TextStyle(
                      fontSize: 16,
                      color: c,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Type city name...',
                      hintStyle: TextStyle(
                        color: c.withValues(alpha: 0.35),
                        fontWeight: FontWeight.w400,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 16,
                      ),
                      prefixIcon: Padding(
                        padding: const EdgeInsets.only(left: 14, right: 8),
                        child: Icon(
                          Icons.search_rounded,
                          color: c.withValues(alpha: 0.4),
                          size: 22,
                        ),
                      ),
                      prefixIconConstraints: const BoxConstraints(
                        minWidth: 44,
                        minHeight: 44,
                      ),
                      suffixIcon: isSearching
                          ? Padding(
                              padding: const EdgeInsets.all(AppDimensions.paddingMdLg),
                              child: AppLoadingIndicator(
                                size: 20,
                                strokeWidth: 2,
                                color: c.withValues(alpha: 0.5),
                              ),
                            )
                          : widget.searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: Icon(
                                    Icons.clear_rounded,
                                    size: 20,
                                    color: c.withValues(alpha: 0.4),
                                  ),
                                  onPressed: () {
                                    widget.onClear();
                                  },
                                )
                              : null,
                    ),
                    onChanged: (q) {
                      widget.onSearch(q);
                    },
                  );
                },
              ),
            ),
          ),

          // Results or empty state
          Expanded(
            child: ValueListenableBuilder<List<Map<String, dynamic>>>(
              valueListenable: widget.resultsNotifier,
              builder: (context, results, _) {
                return ValueListenableBuilder<bool>(
                  valueListenable: widget.searchingNotifier,
                  builder: (context, isSearching, _) {
                    return results.isEmpty
                        ? _buildEmptyState(c, isSearching)
                        : _buildResultsList(c, dark, results);
                  },
                );
              },
            ),
          ),

          // Bottom padding for keyboard
          SizedBox(
              height: bottomPadding > 0
                  ? 8
                  : MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  Widget _buildEmptyState(Color c, bool isSearching) {
    final query = widget.searchController.text;

    if (query.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.location_searching_rounded,
              size: 48,
              color: c.withValues(alpha: 0.2),
            ),
            const SizedBox(height: AppDimensions.spacingLg),
            Text(
              'Search for your birth city',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: c.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: AppDimensions.spacingSm),
            Text(
              'Start typing to see results',
              style: TextStyle(
                fontSize: 13,
                color: c.withValues(alpha: 0.3),
              ),
            ),
          ],
        ),
      );
    }

    if (isSearching) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppLoadingIndicator(
              size: 32,
              color: c.withValues(alpha: 0.4),
            ),
            const SizedBox(height: AppDimensions.spacingLg),
            Text(
              'Searching...',
              style: TextStyle(
                fontSize: 14,
                color: c.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      );
    }

    // No results found
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.location_off_rounded,
            size: 48,
            color: c.withValues(alpha: 0.2),
          ),
          const SizedBox(height: AppDimensions.spacingLg),
          Text(
            'No locations found',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: c.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: AppDimensions.spacingSm),
          Text(
            'Try a different city name',
            style: TextStyle(
              fontSize: 13,
              color: c.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsList(
      Color c, bool dark, List<Map<String, dynamic>> results) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingLg, vertical: AppDimensions.paddingSm),
      itemCount: results.length,
      itemBuilder: (_, i) {
        final r = results[i];
        final name = r['name'] as String? ?? '';
        final admin1 = r['admin1'] as String? ?? '';
        final country = r['country'] as String? ?? '';
        final population = r['population'] as int? ?? 0;

        // Build subtitle
        String subtitle = '';
        if (admin1.isNotEmpty && admin1 != name) {
          subtitle = '$admin1, $country';
        } else {
          subtitle = country;
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Material(
            color: dark
                ? Colors.white.withValues(alpha: 0.04)
                : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(AppDimensions.radiusMdLg),
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                widget.onSelect(r);
              },
              borderRadius: BorderRadius.circular(AppDimensions.radiusMdLg),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: c.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                      ),
                      child: Icon(
                        Icons.location_on_rounded,
                        size: 20,
                        color: c.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(width: AppDimensions.spacingMdLg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: c.withValues(alpha: 0.9),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: AppDimensions.spacingXxs),
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              color: c.withValues(alpha: 0.5),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (population > 100000)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: c.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(AppDimensions.radiusSmMd),
                        ),
                        child: Text(
                          _formatPopulation(population),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: c.withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatPopulation(int pop) {
    if (pop >= 1000000) {
      return '${(pop / 1000000).toStringAsFixed(1)}M';
    } else if (pop >= 1000) {
      return '${(pop / 1000).toStringAsFixed(0)}K';
    }
    return pop.toString();
  }
}
