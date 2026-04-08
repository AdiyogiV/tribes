import 'package:aurogram/core/theme/app_dimensions.dart';
import 'package:flutter/material.dart';
import 'package:aurogram/shared/presentation/widgets/media/common_widgets.dart';
import 'package:aurogram/shared/models/space.dart';
import 'package:aurogram/features/spaces/presentation/grams/grams_empty_state.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/core/theme/header_style.dart';
import 'package:aurogram/features/feed/presentation/widgets/embedded_theatre_view.dart';
import 'package:aurogram/shared/presentation/widgets/universal/transparent_toolbox.dart';

/// Desktop master-detail layout for grams: list on left, detail on right.
class GramsDesktopLayout extends StatelessWidget {
  final bool isRefreshing;
  final String? selectedGramId;
  final Space? selectedGram;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onShowCreationDialog;
  final VoidCallback onClearSelection;
  final Future<void> Function() onRefresh;
  final Widget uploadIndicator;
  final Widget gramList;

  const GramsDesktopLayout({
    super.key,
    required this.isRefreshing,
    required this.selectedGramId,
    required this.selectedGram,
    required this.searchController,
    required this.searchFocusNode,
    required this.onSearchChanged,
    required this.onShowCreationDialog,
    required this.onClearSelection,
    required this.onRefresh,
    required this.uploadIndicator,
    required this.gramList,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dividerColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);

    return Row(
      children: [
        // Left panel - Gram list (fixed width)
        SizedBox(
          width: 340,
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? AppTheme.cardDarkColor : Colors.white,
              border: Border(
                right: BorderSide(color: dividerColor, width: 1),
              ),
            ),
            child: Stack(
              children: [
                RefreshIndicator(
                  onRefresh: onRefresh,
                  color: AppTheme.primaryColor,
                  child: GestureDetector(
                    onTap: () => searchFocusNode.unfocus(),
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      cacheExtent: 600,
                      slivers: [
                        AppHeaderStyle.buildWideLayoutHeaderSliver(
                          context,
                          title: 'Grams',
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isRefreshing)
                                AppLoadingIndicator(
                                  size: 20,
                                  strokeWidth: 2,
                                ),
                              const SizedBox(width: AppDimensions.spacingSm),
                              uploadIndicator,
                              const SizedBox(width: AppDimensions.spacingSm),
                              IconButton(
                                onPressed: onShowCreationDialog,
                                icon: Icon(
                                  Icons.add_rounded,
                                  color: AppTheme.primaryColor,
                                  size: 24,
                                ),
                                tooltip: 'Create Gram',
                              ),
                            ],
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: AnimatedOpacity(
                            opacity: isRefreshing ? 0.7 : 1.0,
                            duration: const Duration(milliseconds: 200),
                            child: gramList,
                          ),
                        ),
                        SliverToBoxAdapter(child: SizedBox(height: 80)),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: TransparentToolbox.search(
                    searchController: searchController,
                    focusNode: searchFocusNode,
                    onSearchChanged: onSearchChanged,
                    hintText: 'Search grams',
                  ),
                ),
              ],
            ),
          ),
        ),

        // Right panel - Gram posts/content view (fills remaining space)
        Expanded(
          child: selectedGramId != null && selectedGram != null
              ? EmbeddedTheatreView(
                  key: ValueKey(selectedGramId),
                  spaceId: selectedGramId!,
                  space: selectedGram,
                  onBack: onClearSelection,
                )
              : GramsEmptyDetailState(isDark: isDark),
        ),
      ],
    );
  }
}
