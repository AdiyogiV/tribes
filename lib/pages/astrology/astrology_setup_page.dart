import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:aurogram/models/astrology_profile.dart';
import 'package:aurogram/services/astrology_service.dart';
import 'package:aurogram/widgets/ui/skeleton_widgets.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/utils/responsive.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:aurogram/pages/onboarding/onboarding_complete.dart';

// Intent class for Enter key handling
class _SaveIntent extends Intent {
  const _SaveIntent();
}

/// Beautifully redesigned astrology setup with celestial aesthetics
class AstrologySetupPage extends StatefulWidget {
  const AstrologySetupPage({super.key});

  @override
  State<AstrologySetupPage> createState() => _AstrologySetupPageState();
}

class _AstrologySetupPageState extends State<AstrologySetupPage> {
  final _service = AstrologyService();
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  final _scrollController = ScrollController();

  // Date/Time
  late int _day, _month, _year;
  late int _hour, _minute;
  bool _isAM = true;

  // Location
  String? _place;
  double? _lat, _lng;
  String? _tz;
  double? _tzOffset; // Numeric timezone offset in hours
  // Use ValueNotifiers for efficient updates to the search sheet
  final ValueNotifier<List<Map<String, dynamic>>> _resultsNotifier =
      ValueNotifier([]);
  final ValueNotifier<bool> _searchingNotifier = ValueNotifier(false);
  Timer? _debounce;

  // Gender (optional but helps with traditional compatibility)
  String? _gender; // "Male", "Female", "Non-binary", or null

  // State
  bool _saving = false;
  bool _loading = true;
  bool _navigatedToOnboarding =
      false; // Prevents re-navigation to OnboardingComplete
  AstrologyProfile? _existing;

  // UI state
  int _activeSection = 0; // 0: date, 1: time, 2: place

  // Persistent scroll controllers for pickers
  late FixedExtentScrollController _dayController;
  late FixedExtentScrollController _monthController;
  late FixedExtentScrollController _yearController;
  late FixedExtentScrollController _hourController;
  late FixedExtentScrollController _minuteController;
  late FixedExtentScrollController _ampmController;

  @override
  void initState() {
    super.initState();
    _day = 15;
    _month = 6;
    _year = 1995;
    _hour = 6;
    _minute = 0;

    // Initialize scroll controllers with default positions
    _dayController = FixedExtentScrollController(initialItem: _day - 1);
    _monthController = FixedExtentScrollController(initialItem: _month - 1);
    _yearController =
        FixedExtentScrollController(initialItem: DateTime.now().year - _year);
    _hourController = FixedExtentScrollController(initialItem: _hour - 1);
    _minuteController = FixedExtentScrollController(initialItem: _minute);
    _ampmController = FixedExtentScrollController(initialItem: _isAM ? 0 : 1);

    _load();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    final p = await _service.getProfile(uid);
    if (mounted) {
      setState(() {
        _loading = false;
        if (p != null) {
          _existing = p;
          if (p.birthDate != null) {
            _day = p.birthDate!.day;
            _month = p.birthDate!.month;
            _year = p.birthDate!.year;
          }
          if (p.birthTime != null) {
            final parts = p.birthTime!.split(':');
            if (parts.length >= 2) {
              final h = int.tryParse(parts[0]) ?? 6;
              _minute = int.tryParse(parts[1]) ?? 0;
              _isAM = h < 12;
              _hour = h == 0 ? 12 : (h > 12 ? h - 12 : h);
            }
          }
          _place = p.birthPlace;
          _lat = p.birthLatitude;
          _lng = p.birthLongitude;
          _tz = p.timeZone;
          _tzOffset = p.timeZoneOffset;
          _gender = p.gender;
          if (_place != null) _searchController.text = _place!;
        }
      });

      // Jump controllers to loaded positions after frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _dayController.jumpToItem(_day - 1);
          _monthController.jumpToItem(_month - 1);
          _yearController.jumpToItem(DateTime.now().year - _year);
          _hourController.jumpToItem(_hour - 1);
          _minuteController.jumpToItem(_minute);
          _ampmController.jumpToItem(_isAM ? 0 : 1);
        }
      });
    }
  }

  int get _hour24 =>
      _isAM ? (_hour == 12 ? 0 : _hour) : (_hour == 12 ? 12 : _hour + 12);
  bool get _canSave => _lat != null && _gender != null;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    _scrollController.dispose();
    // Dispose picker controllers
    _dayController.dispose();
    _monthController.dispose();
    _yearController.dispose();
    _hourController.dispose();
    _minuteController.dispose();
    _ampmController.dispose();
    // Dispose search notifiers
    _resultsNotifier.dispose();
    _searchingNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.primaryColor;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Shortcuts(
      shortcuts: {
        if (_canSave && !_saving)
          LogicalKeySet(LogicalKeyboardKey.enter): _SaveIntent(),
      },
      child: Actions(
        actions: {
          _SaveIntent: CallbackAction<_SaveIntent>(
            onInvoke: (_) {
              if (_canSave && !_saving) {
                _save();
              }
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            body: GestureDetector(
              onTap: () => _searchFocus.unfocus(),
              behavior: HitTestBehavior.opaque,
              child: ResponsiveBuilder(
                builder: (context, isMobile, isTablet, isDesktop) {
                  final isWideScreen = isTablet || isDesktop;

                  if (isWideScreen) {
                    return _buildWideLayout(c, dark, isDesktop);
                  }
                  return _buildMobileLayout(c, dark);
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Wide screen layout (tablet/desktop) - centered card style
  Widget _buildWideLayout(Color c, bool dark, bool isDesktop) {
    return Column(
      children: [
        // Header - full width
        SafeArea(
          bottom: false,
          child: _buildHeader(c, dark),
        ),

        // Scrollable content area - full width with scrollbar on right edge
        Expanded(
          child: Scrollbar(
            controller: _scrollController,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: isDesktop ? 600 : 560),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _loading
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 80),
                            child: PulsingDots(color: c, size: 10),
                          )
                        : Column(
                            children: [
                              // Date section
                              _buildFormCard(
                                index: 0,
                                title: 'Birth Date',
                                subtitle: _formatSelectedDate(),
                                content: _buildDatePickers(c, dark),
                                c: c,
                                dark: dark,
                              ),
                              const SizedBox(height: 20),

                              // Time section
                              _buildFormCard(
                                index: 1,
                                title: 'Birth Time',
                                subtitle: _formatSelectedTime(),
                                content: _buildTimePickers(c, dark),
                                c: c,
                                dark: dark,
                              ),
                              const SizedBox(height: 20),

                              // Location section
                              _buildFormCard(
                                index: 2,
                                title: 'Birth Place',
                                subtitle: _place ?? 'Search for your city',
                                content: _buildLocationSearch(c, dark),
                                c: c,
                                dark: dark,
                              ),
                              const SizedBox(height: 20),

                              // Gender section (required)
                              _buildFormCard(
                                index: 3,
                                title: 'Gender',
                                subtitle: _gender ?? 'Select your gender',
                                content: _buildGenderSelector(c, dark),
                                c: c,
                                dark: dark,
                              ),
                              const SizedBox(height: 32),

                              // Save button in flow (not positioned)
                              _buildSaveButtonWide(c, dark),
                              const SizedBox(height: 24),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Mobile layout - original vertical stack with positioned bottom
  Widget _buildMobileLayout(Color c, bool dark) {
    return Stack(
      children: [
        // Main content
        SafeArea(
          child: Column(
            children: [
              // Header
              _buildHeader(c, dark),

              // Scrollable content
              Expanded(
                child: _loading
                    ? Center(
                        child: PulsingDots(color: c, size: 10),
                      )
                    : SingleChildScrollView(
                        controller: _scrollController,
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          children: [
                            const SizedBox(height: 16),

                            // Form sections
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 20),
                              child: Column(
                                children: [
                                  // Date section
                                  _buildFormCard(
                                    index: 0,
                                    title: 'Birth Date',
                                    subtitle: _formatSelectedDate(),
                                    content: _buildDatePickers(c, dark),
                                    c: c,
                                    dark: dark,
                                  ),

                                  const SizedBox(height: 16),

                                  // Time section
                                  _buildFormCard(
                                    index: 1,
                                    title: 'Birth Time',
                                    subtitle: _formatSelectedTime(),
                                    content: _buildTimePickers(c, dark),
                                    c: c,
                                    dark: dark,
                                  ),

                                  const SizedBox(height: 16),

                                  // Location section
                                  _buildFormCard(
                                    index: 2,
                                    title: 'Birth Place',
                                    subtitle: _place ?? 'Search for your city',
                                    content: _buildLocationSearch(c, dark),
                                    c: c,
                                    dark: dark,
                                  ),

                                  const SizedBox(height: 16),

                                  // Gender section (required)
                                  _buildFormCard(
                                    index: 3,
                                    title: 'Gender',
                                    subtitle: _gender ?? 'Select your gender',
                                    content: _buildGenderSelector(c, dark),
                                    c: c,
                                    dark: dark,
                                  ),

                                  const SizedBox(height: 120),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),

        // Bottom save button
        if (!_loading) _buildSaveButton(c, dark),
      ],
    );
  }

  Widget _buildHeader(Color c, bool dark) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16),
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
          // Centered title - matching app header style
          Expanded(
            child: Center(
              child: Text(
                'birth details',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: c,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
          // Delete button or spacer for symmetry
          SizedBox(
            width: 40,
            child: _existing != null
                ? IconButton(
                    onPressed: _delete,
                    icon: Icon(Icons.delete_outline_rounded,
                        size: 20, color: Colors.red.shade400),
                    padding: EdgeInsets.zero,
                  )
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard({
    required int index,
    required String title,
    required String subtitle,
    required Widget content,
    required Color c,
    required bool dark,
  }) {
    final isActive = _activeSection == index;
    final cardColor =
        dark ? Theme.of(context).colorScheme.surface : Colors.white;

    return Material(
      color: cardColor,
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () {
          setState(() {
            // Toggle: close if already open, open otherwise
            _activeSection = _activeSection == index ? -1 : index;
          });
          HapticFeedback.selectionClick();
        },
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  // Title & subtitle
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: c,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: c.withValues(alpha: 0.5),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // Expand indicator
                  AnimatedRotation(
                    turns: isActive ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: c.withValues(alpha: 0.4),
                      size: 24,
                    ),
                  ),
                ],
              ),

              // Content (animated)
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: content,
                ),
                crossFadeState: isActive
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 250),
                sizeCurve: Curves.easeOutCubic,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDatePickers(Color c, bool dark) {
    return Container(
      height: 140,
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          // Day
          Expanded(
            flex: 2,
            child: _buildPicker(
              items: _days,
              controller: _dayController,
              onChanged: (i) {
                final maxD = DateTime(_year, _month + 1, 0).day;
                final newDay = (i + 1).clamp(1, maxD);
                setState(() => _day = newDay);
                // If day was clamped, adjust the controller position
                if (newDay != i + 1) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) _dayController.jumpToItem(newDay - 1);
                  });
                }
              },
              c: c,
              dark: dark,
              label: 'Day',
            ),
          ),
          _buildPickerDivider(c),
          // Month
          Expanded(
            flex: 3,
            child: _buildPicker(
              items: _months,
              controller: _monthController,
              onChanged: (i) {
                _month = i + 1;
                final maxD = DateTime(_year, _month + 1, 0).day;
                final clampedDay = _day.clamp(1, maxD);
                setState(() => _day = clampedDay);
                // Adjust day controller if day was clamped
                if (clampedDay != _day ||
                    _dayController.selectedItem != clampedDay - 1) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted &&
                        _dayController.selectedItem != clampedDay - 1) {
                      _dayController.jumpToItem(clampedDay - 1);
                    }
                  });
                }
              },
              c: c,
              dark: dark,
              label: 'Month',
            ),
          ),
          _buildPickerDivider(c),
          // Year
          Expanded(
            flex: 3,
            child: _buildPicker(
              items: _years,
              controller: _yearController,
              onChanged: (i) {
                _year = DateTime.now().year - i;
                final maxD = DateTime(_year, _month + 1, 0).day;
                final clampedDay = _day.clamp(1, maxD);
                setState(() => _day = clampedDay);
                // Adjust day controller if day was clamped
                if (_dayController.selectedItem != clampedDay - 1) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted &&
                        _dayController.selectedItem != clampedDay - 1) {
                      _dayController.jumpToItem(clampedDay - 1);
                    }
                  });
                }
              },
              c: c,
              dark: dark,
              label: 'Year',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimePickers(Color c, bool dark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 140,
          decoration: BoxDecoration(
            color: c.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              // Hour
              Expanded(
                flex: 2,
                child: _buildPicker(
                  items: _hours,
                  controller: _hourController,
                  onChanged: (i) => setState(() => _hour = i + 1),
                  c: c,
                  dark: dark,
                  label: 'Hour',
                ),
              ),
              // Colon separator
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Text(
                  ':',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: c.withValues(alpha: 0.4),
                  ),
                ),
              ),
              // Minute
              Expanded(
                flex: 2,
                child: _buildPicker(
                  items: _minutes,
                  controller: _minuteController,
                  onChanged: (i) => setState(() => _minute = i),
                  c: c,
                  dark: dark,
                  label: 'Min',
                ),
              ),
              _buildPickerDivider(c),
              // AM/PM
              Expanded(
                flex: 2,
                child: _buildPicker(
                  items: const ['AM', 'PM'],
                  controller: _ampmController,
                  onChanged: (i) => setState(() => _isAM = i == 0),
                  c: c,
                  dark: dark,
                  label: '',
                  isMeridiem: true,
                ),
              ),
            ],
          ),
        ),
        // Timezone display (only when set)
        if (_tz != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              children: [
                Icon(
                  Icons.schedule_rounded,
                  size: 14,
                  color: c.withValues(alpha: 0.4),
                ),
                const SizedBox(width: 6),
                Text(
                  _tz!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: c.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildPickerDivider(Color c) {
    return Container(
      width: 1,
      height: 60,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: c.withValues(alpha: 0.08),
    );
  }

  Widget _buildPicker({
    required List<String> items,
    required FixedExtentScrollController controller,
    required Function(int) onChanged,
    required Color c,
    required bool dark,
    required String label,
    bool isMeridiem = false,
  }) {
    return Column(
      children: [
        if (label.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: c.withValues(alpha: 0.4),
                letterSpacing: 0.5,
              ),
            ),
          ),
        Expanded(
          child: CupertinoPicker(
            scrollController: controller,
            itemExtent: 36,
            diameterRatio: 1.1,
            squeeze: 1.0,
            selectionOverlay: Container(
              decoration: BoxDecoration(
                color: c.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onSelectedItemChanged: (i) {
              HapticFeedback.selectionClick();
              onChanged(i);
            },
            children: items
                .map((s) => Center(
                      child: Text(
                        s,
                        style: TextStyle(
                          fontSize: isMeridiem ? 14 : 18,
                          fontWeight: FontWeight.w600,
                          color: c,
                        ),
                      ),
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildLocationSearch(Color c, bool dark) {
    final cardColor =
        dark ? Theme.of(context).colorScheme.surface : Colors.white;

    return GestureDetector(
      onTap: () => _openLocationSearchOverlay(c, dark, cardColor),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            Icon(
              Icons.search_rounded,
              color: c.withValues(alpha: 0.4),
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _place ?? 'Tap to search city...',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight:
                      _place != null ? FontWeight.w500 : FontWeight.w400,
                  color: _place != null ? c : c.withValues(alpha: 0.35),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (_place != null)
              GestureDetector(
                onTap: () {
                  setState(() {
                    _place = null;
                    _lat = null;
                    _lng = null;
                    _tz = null;
                    _tzOffset = null;
                    _searchController.clear();
                  });
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

  void _openLocationSearchOverlay(Color c, bool dark, Color cardColor) {
    // Clear previous search
    _searchController.clear();
    _resultsNotifier.value = [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _LocationSearchSheet(
        primaryColor: c,
        isDark: dark,
        cardColor: cardColor,
        initialQuery: '',
        onSearch: _search,
        onSelect: _select,
        searchController: _searchController,
        resultsNotifier: _resultsNotifier,
        searchingNotifier: _searchingNotifier,
        onClear: () {
          _searchController.clear();
          _resultsNotifier.value = [];
        },
      ),
    );
  }

  Widget _buildGenderSelector(Color c, bool dark) {
    // Use simple tappable chips instead of CupertinoSlidingSegmentedControl
    // to avoid layout issues with AnimatedCrossFade
    Widget buildChip(String value, String label) {
      final isSelected = _gender == value;
      return Expanded(
        child: GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _gender = value);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? c.withValues(alpha: 0.15)
                  : c.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color:
                    isSelected ? c.withValues(alpha: 0.3) : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? c : c.withValues(alpha: 0.5),
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        buildChip('Male', 'Male'),
        const SizedBox(width: 10),
        buildChip('Female', 'Female'),
        const SizedBox(width: 10),
        buildChip('Non-binary', 'Other'),
      ],
    );
  }

  Widget _buildSaveButton(Color c, bool dark) {
    final cardColor =
        dark ? Theme.of(context).colorScheme.surface : Colors.white;

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          MediaQuery.of(context).padding.bottom + 16,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0),
              Theme.of(context).scaffoldBackgroundColor,
            ],
          ),
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          child: Material(
            color: cardColor,
            elevation: _canSave ? 2 : 0,
            shadowColor: Colors.black.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              onTap: _canSave && !_saving ? _save : null,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _saving
                      ? PulsingDots(color: c, size: 6)
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _existing != null
                                  ? Icons.save_rounded
                                  : Icons.auto_awesome_rounded,
                              size: 20,
                              color: _canSave ? c : c.withValues(alpha: 0.4),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              _existing != null
                                  ? 'Save Changes'
                                  : 'Calculate Birth Chart',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: _canSave ? c : c.withValues(alpha: 0.4),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Save button for wide layout (in flow, not positioned)
  Widget _buildSaveButtonWide(Color c, bool dark) {
    final cardColor =
        dark ? Theme.of(context).colorScheme.surface : Colors.white;

    return Material(
      color: cardColor,
      elevation: _canSave ? 2 : 0,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: _canSave && !_saving ? _save : null,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _saving
                ? PulsingDots(color: c, size: 6)
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _existing != null
                            ? Icons.save_rounded
                            : Icons.auto_awesome_rounded,
                        size: 22,
                        color: _canSave ? c : c.withValues(alpha: 0.4),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _existing != null
                            ? 'Save Changes'
                            : 'Calculate Birth Chart',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: _canSave ? c : c.withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  String _formatSelectedDate() {
    return '$_day ${_months[_month - 1]} $_year';
  }

  String _formatSelectedTime() {
    final h = _hour.toString();
    final m = _minute.toString().padLeft(2, '0');
    return '$h:$m ${_isAM ? 'AM' : 'PM'}';
  }

  /// Fast location search using Open-Meteo Geocoding API (direct call, no Firebase)
  void _search(String q) {
    _debounce?.cancel();
    if (q.length < 2) {
      _resultsNotifier.value = [];
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 150), () async {
      if (!mounted) return;
      _searchingNotifier.value = true;

      try {
        // Direct API call - much faster than Firebase Functions
        final uri = Uri.parse('https://geocoding-api.open-meteo.com/v1/search'
            '?name=${Uri.encodeComponent(q.trim())}'
            '&count=8&language=en&format=json');

        final response = await http.get(uri).timeout(
              const Duration(seconds: 5),
              onTimeout: () => http.Response('{}', 408),
            );

        if (!mounted) return;

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final results = data['results'] as List? ?? [];

          _resultsNotifier.value = results
              .map((item) => {
                    'name': item['name'] ?? '',
                    'country': item['country'] ?? '',
                    'admin1': item['admin1'] ?? '', // State/Province
                    'latitude': item['latitude'],
                    'longitude': item['longitude'],
                    'timezone': item['timezone'],
                    'population': item['population'] ?? 0,
                  })
              .toList();
          _searchingNotifier.value = false;
        } else {
          _resultsNotifier.value = [];
          _searchingNotifier.value = false;
        }
      } catch (e) {
        if (mounted) {
          _resultsNotifier.value = [];
          _searchingNotifier.value = false;
        }
      }
    });
  }

  void _select(Map<String, dynamic> r) {
    final admin1 = r['admin1'] as String? ?? '';
    final country = r['country'] as String? ?? '';
    final cityName = r['name'] as String? ?? '';

    // Build display name: City, State/Province, Country
    String displayName;
    if (admin1.isNotEmpty && admin1 != cityName) {
      displayName = '$cityName, $admin1, $country';
    } else {
      displayName = '$cityName, $country';
    }

    _searchController.text = displayName;
    Navigator.pop(context); // Close the search overlay

    setState(() {
      _place = displayName;
      _lat = (r['latitude'] as num).toDouble();
      _lng = (r['longitude'] as num).toDouble();
      _tz = r['timezone'] as String?;
      _tzOffset = (r['timezoneOffset'] as num?)?.toDouble();
    });
    _resultsNotifier.value = [];
    HapticFeedback.mediumImpact();
  }

  Future<void> _save() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _saving = true);
    HapticFeedback.mediumImpact();

    // Track if this is a new setup (not editing existing)
    // Check if profile has CALCULATED data (signs), not just if profile exists
    // This handles edge cases like partial account deletion where profile exists but is incomplete
    final isNewSetup = _existing == null || !(_existing!.hasCalculatedData);

    try {
      var tz = _tz;
      if (tz == null && _lat != null && _lng != null) {
        tz = await _service.resolveTimeZone(_lat!, _lng!);
      }

      final profile = AstrologyProfile(
        birthDate: DateTime(_year, _month, _day),
        birthYear: _year,
        birthMonth: _month,
        birthDay: _day,
        birthTime:
            '${_hour24.toString().padLeft(2, '0')}:${_minute.toString().padLeft(2, '0')}',
        birthPlace: _place,
        birthLatitude: _lat,
        birthLongitude: _lng,
        timeZone: tz,
        timeZoneOffset: _tzOffset, // Numeric offset for API compatibility
        gender: _gender, // Optional - helps with traditional compatibility
        isEnabled: true,
        visibility: AstroVisibility
            .public, // Always public - basic signs visible to others, details only to user
        createdAt: _existing?.createdAt ?? DateTime.now(),
      );

      // Save profile first
      await _service.saveProfile(profile);

      // Aura: award astrology setup (+10) via backend (fire-and-forget)
      try {
        await FirebaseFunctions.instanceFor(region: 'asia-southeast2')
            .httpsCallable('awardAstrologySetup')
            .call();
      } catch (_) {}

      if (mounted) {
        HapticFeedback.heavyImpact();

        if (!_navigatedToOnboarding) {
          // Mark as navigated to prevent re-pushing if user backs out
          _navigatedToOnboarding = true;
          _saving = false; // Reset so user can edit if they back out

          // Push to cards reveal page (both for new setup and updates)
          // For updates: isUpdate=true shows card reveal then returns
          // For new setup: isUpdate=false shows full onboarding flow
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => OnboardingComplete(
                hasBirthDetails: true,
                isUpdate: !isNewSetup,
              ),
            ),
          );
        }
      }

      // Calculate in background (fire and forget)
      _service.calculateAndSaveAll(uid);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _delete() async {
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Delete Birth Data?'),
        content: const Text(
          'This will remove all your astrology data including your birth chart and insights.',
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context, false),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Delete'),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _service.deleteProfile();
      if (mounted) Navigator.pop(context, true);
    }
  }

  // Data lists
  List<String> get _days => List.generate(31, (i) => '${i + 1}');
  List<String> get _months => const [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December'
      ];
  List<String> get _years => List.generate(
      DateTime.now().year - 1920 + 1, (i) => '${DateTime.now().year - i}');
  List<String> get _hours => List.generate(12, (i) => '${i + 1}');
  List<String> get _minutes =>
      List.generate(60, (i) => i.toString().padLeft(2, '0'));
}

/// Fullscreen location search sheet for better UX
/// Uses ValueListenableBuilder for efficient rebuilds (no polling timer)
class _LocationSearchSheet extends StatefulWidget {
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

  const _LocationSearchSheet({
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
  State<_LocationSearchSheet> createState() => _LocationSearchSheetState();
}

class _LocationSearchSheetState extends State<_LocationSearchSheet> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Auto-focus the search field
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
                    padding: const EdgeInsets.all(8),
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

          // Search field with ValueListenableBuilder for efficient rebuilds
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Container(
              decoration: BoxDecoration(
                color: c.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(16),
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
                              padding: const EdgeInsets.all(14),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(
                                      c.withValues(alpha: 0.5)),
                                ),
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

          // Results or empty state - uses ValueListenableBuilder for efficient rebuilds
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
            const SizedBox(height: 16),
            Text(
              'Search for your birth city',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: c.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 8),
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
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation(c.withValues(alpha: 0.4)),
              ),
            ),
            const SizedBox(height: 16),
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
          const SizedBox(height: 16),
          Text(
            'No locations found',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: c.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 8),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                widget.onSelect(r);
              },
              borderRadius: BorderRadius.circular(14),
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
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.location_on_rounded,
                        size: 20,
                        color: c.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(width: 14),
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
                          const SizedBox(height: 2),
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
                          borderRadius: BorderRadius.circular(6),
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
