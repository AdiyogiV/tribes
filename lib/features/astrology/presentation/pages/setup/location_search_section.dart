import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:aurogram/core/config/api_endpoints.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';
import 'package:aurogram/shared/presentation/widgets/media/common_widgets.dart';

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
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            Icon(Icons.search_rounded, color: c.withValues(alpha: 0.5), size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                place ?? 'Tap to search city...',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: place != null ? FontWeight.w500 : FontWeight.w400,
                  color: place != null ? c : c.withValues(alpha: 0.5),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (place != null)
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onClear();
                },
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: c.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.close_rounded, size: 14, color: c.withValues(alpha: 0.7)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Opens the location search bottom sheet.
void openLocationSearchOverlay({
  required BuildContext context,
  required Color primaryColor,
  required bool dark,
  required Color cardColor,
  required Function(Map<String, dynamic>) onSelect,
}) {
  AppBottomSheet.show(
    context,
    child: LocationSearchSheet(
      primaryColor: primaryColor,
      isDark: dark,
      onSelect: onSelect,
    ),
  );
}

/// Self-contained location search sheet.
///
/// Owns its own TextEditingController, search state, and HTTP calls.
/// No notifiers passed from the parent — zero external rebuild triggers
/// so the cursor never resets while typing.
class LocationSearchSheet extends StatefulWidget {
  final Color primaryColor;
  final bool isDark;
  final Function(Map<String, dynamic>) onSelect;

  const LocationSearchSheet({
    super.key,
    required this.primaryColor,
    required this.isDark,
    required this.onSelect,
  });

  @override
  State<LocationSearchSheet> createState() => _LocationSearchSheetState();
}

class _LocationSearchSheetState extends State<LocationSearchSheet> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  List<Map<String, dynamic>> _results = [];
  Timer? _debounce;
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    if (q.trim().length < 2) {
      if (_results.isNotEmpty || _hasSearched) {
        setState(() {
          _results = [];
          _hasSearched = false;
        });
      }
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () => _doSearch(q.trim()));
  }

  Future<void> _doSearch(String q) async {
    try {
      final uri = Uri.parse(ApiEndpoints.geocodingSearch).replace(
        queryParameters: {'name': q, 'count': '8', 'language': 'en', 'format': 'json'},
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      if (!mounted) return;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final items = data['results'] as List? ?? [];
      setState(() {
        _hasSearched = true;
        _results = items
            .map((item) => {
                  'name': item['name'] ?? '',
                  'country': item['country'] ?? '',
                  'admin1': item['admin1'] ?? '',
                  'latitude': item['latitude'],
                  'longitude': item['longitude'],
                  'timezone': item['timezone'],
                  'population': item['population'] ?? 0,
                })
            .toList();
      });
    } catch (_) {
      if (mounted) setState(() { _results = []; _hasSearched = true; });
    }
  }

  void _clear() {
    _controller.clear();
    setState(() { _results = []; _hasSearched = false; });
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.primaryColor;
    final dark = widget.isDark;

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
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: c),
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
                    child: Icon(Icons.close_rounded, size: 20, color: c.withValues(alpha: 0.6)),
                  ),
                ),
              ],
            ),
          ),

          // Search field — no ValueListenableBuilders anywhere near it
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              autofocus: true,
              style: TextStyle(fontSize: 16, color: c, fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                hintText: 'Type city name...',
                hintStyle: TextStyle(color: c.withValues(alpha: 0.35), fontWeight: FontWeight.w400),
                filled: true,
                fillColor: c.withValues(alpha: 0.06),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                  borderSide: BorderSide(color: c.withValues(alpha: 0.1), width: 1.5),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                  borderSide: BorderSide(color: c.withValues(alpha: 0.1), width: 1.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                  borderSide: BorderSide(color: c.withValues(alpha: 0.3), width: 1.5),
                ),
                prefixIcon: Icon(Icons.search_rounded, color: c.withValues(alpha: 0.4), size: 22),
                suffixIcon: _controller.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear_rounded, size: 20, color: c.withValues(alpha: 0.4)),
                        onPressed: _clear,
                      )
                    : null,
              ),
              onChanged: _onChanged,
            ),
          ),

          // Results list or empty state
          Expanded(child: _buildBody(c, dark)),

          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  Widget _buildBody(Color c, bool dark) {
    if (_results.isNotEmpty) return _buildList(c, dark);

    final IconData icon;
    final String title;
    final String subtitle;

    if (!_hasSearched) {
      icon = Icons.location_searching_rounded;
      title = 'Search for your birth city';
      subtitle = 'Start typing to see results';
    } else {
      icon = Icons.location_off_rounded;
      title = 'No locations found';
      subtitle = 'Try a different city name';
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: c.withValues(alpha: 0.2)),
          const SizedBox(height: AppDimensions.spacingLg),
          Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: c.withValues(alpha: 0.4))),
          const SizedBox(height: AppDimensions.spacingSm),
          Text(subtitle, style: TextStyle(fontSize: 13, color: c.withValues(alpha: 0.3))),
        ],
      ),
    );
  }

  Widget _buildList(Color c, bool dark) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingLg,
        vertical: AppDimensions.paddingSm,
      ),
      itemCount: _results.length,
      itemBuilder: (_, i) {
        final r = _results[i];
        final name = r['name'] as String? ?? '';
        final admin1 = r['admin1'] as String? ?? '';
        final country = r['country'] as String? ?? '';
        final population = r['population'] as int? ?? 0;
        final subtitle = (admin1.isNotEmpty && admin1 != name) ? '$admin1, $country' : country;

        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Material(
            color: dark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(AppDimensions.radiusMdLg),
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                Navigator.pop(context);
                widget.onSelect(r);
              },
              borderRadius: BorderRadius.circular(AppDimensions.radiusMdLg),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: c.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                      ),
                      child: Icon(Icons.location_on_rounded, size: 20, color: c.withValues(alpha: 0.6)),
                    ),
                    const SizedBox(width: AppDimensions.spacingMdLg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.withValues(alpha: 0.9)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: AppDimensions.spacingXxs),
                          Text(
                            subtitle,
                            style: TextStyle(fontSize: 13, color: c.withValues(alpha: 0.5)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (population > 100000)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: c.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(AppDimensions.radiusSmMd),
                        ),
                        child: Text(
                          _formatPop(population),
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: c.withValues(alpha: 0.4)),
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

  String _formatPop(int pop) {
    if (pop >= 1000000) return '${(pop / 1000000).toStringAsFixed(1)}M';
    if (pop >= 1000) return '${(pop / 1000).toStringAsFixed(0)}K';
    return '$pop';
  }
}
