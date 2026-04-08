import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:aurogram/utils/logging/app_logger.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:aurogram/config/api_endpoints.dart';
import 'package:aurogram/models/astrology_profile.dart';
import 'package:aurogram/services/astrology_service.dart';
import 'package:aurogram/widgets/ui/skeleton_widgets.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/utils/responsive.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:aurogram/pages/onboarding/onboarding_complete.dart';
import 'package:aurogram/pages/astrology/setup/date_picker_section.dart';
import 'package:aurogram/pages/astrology/setup/form_card_widget.dart';
import 'package:aurogram/pages/astrology/setup/gender_selector_section.dart';
import 'package:aurogram/pages/astrology/setup/location_search_section.dart';
import 'package:aurogram/pages/astrology/setup/save_button_section.dart';
import 'package:aurogram/pages/astrology/setup/time_picker_section.dart';
import 'package:aurogram/utils/theme/app_dimensions.dart';
import 'package:aurogram/widgets/common/snack_bar_service.dart';

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
                    padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingXxl),
                    child: _loading
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 80),
                            child: PulsingDots(color: c, size: 10),
                          )
                        : Column(
                            children: [
                              // Date section
                              SetupFormCard(
                                index: 0,
                                activeSection: _activeSection,
                                title: 'Birth Date',
                                subtitle: _formatSelectedDate(),
                                content: DatePickerSection(
                                  day: _day,
                                  month: _month,
                                  year: _year,
                                  primaryColor: c,
                                  dark: dark,
                                  dayController: _dayController,
                                  monthController: _monthController,
                                  yearController: _yearController,
                                  onDayChanged: (i) {
                                    final maxD = DateTime(_year, _month + 1, 0).day;
                                    final newDay = (i + 1).clamp(1, maxD);
                                    setState(() => _day = newDay);
                                    if (newDay != i + 1) {
                                      WidgetsBinding.instance.addPostFrameCallback((_) {
                                        if (mounted) _dayController.jumpToItem(newDay - 1);
                                      });
                                    }
                                  },
                                  onMonthChanged: (i) {
                                    _month = i + 1;
                                    final maxD = DateTime(_year, _month + 1, 0).day;
                                    final clampedDay = _day.clamp(1, maxD);
                                    setState(() => _day = clampedDay);
                                    WidgetsBinding.instance.addPostFrameCallback((_) {
                                      if (mounted && _dayController.selectedItem != clampedDay - 1) {
                                        _dayController.jumpToItem(clampedDay - 1);
                                      }
                                    });
                                  },
                                  onYearChanged: (i) {
                                    _year = DateTime.now().year - i;
                                    final maxD = DateTime(_year, _month + 1, 0).day;
                                    final clampedDay = _day.clamp(1, maxD);
                                    setState(() => _day = clampedDay);
                                    WidgetsBinding.instance.addPostFrameCallback((_) {
                                      if (mounted && _dayController.selectedItem != clampedDay - 1) {
                                        _dayController.jumpToItem(clampedDay - 1);
                                      }
                                    });
                                  },
                                ),
                                primaryColor: c,
                                dark: dark,
                                onToggle: (i) => setState(() {
                                  _activeSection =
                                      _activeSection == i ? -1 : i;
                                }),
                              ),
                              const SizedBox(height: AppDimensions.spacingXl),

                              // Time section
                              SetupFormCard(
                                index: 1,
                                activeSection: _activeSection,
                                title: 'Birth Time',
                                subtitle: _formatSelectedTime(),
                                content: TimePickerSection(
                                  hour: _hour,
                                  minute: _minute,
                                  isAM: _isAM,
                                  timeZone: _tz,
                                  primaryColor: c,
                                  dark: dark,
                                  hourController: _hourController,
                                  minuteController: _minuteController,
                                  ampmController: _ampmController,
                                  onHourChanged: (i) => setState(() => _hour = i + 1),
                                  onMinuteChanged: (i) => setState(() => _minute = i),
                                  onAmPmChanged: (i) => setState(() => _isAM = i == 0),
                                ),
                                primaryColor: c,
                                dark: dark,
                                onToggle: (i) => setState(() {
                                  _activeSection =
                                      _activeSection == i ? -1 : i;
                                }),
                              ),
                              const SizedBox(height: AppDimensions.spacingXl),

                              // Location section
                              SetupFormCard(
                                index: 2,
                                activeSection: _activeSection,
                                title: 'Birth Place',
                                subtitle: _place ?? 'Search for your city',
                                content: LocationSearchButton(
                                  place: _place,
                                  primaryColor: c,
                                  dark: dark,
                                  onTap: () => openLocationSearchOverlay(
                                    context: context,
                                    primaryColor: c,
                                    dark: dark,
                                    cardColor: dark ? Theme.of(context).colorScheme.surface : Colors.white,
                                    searchController: _searchController,
                                    resultsNotifier: _resultsNotifier,
                                    searchingNotifier: _searchingNotifier,
                                    onSearch: _search,
                                    onSelect: _select,
                                  ),
                                  onClear: () => setState(() {
                                    _place = null;
                                    _lat = null;
                                    _lng = null;
                                    _tz = null;
                                    _tzOffset = null;
                                    _searchController.clear();
                                  }),
                                ),
                                primaryColor: c,
                                dark: dark,
                                onToggle: (i) => setState(() {
                                  _activeSection =
                                      _activeSection == i ? -1 : i;
                                }),
                              ),
                              const SizedBox(height: AppDimensions.spacingXl),

                              // Gender section (required)
                              SetupFormCard(
                                index: 3,
                                activeSection: _activeSection,
                                title: 'Gender',
                                subtitle: _gender ?? 'Select your gender',
                                content: GenderSelectorSection(
                                  selectedGender: _gender,
                                  primaryColor: c,
                                  dark: dark,
                                  onGenderChanged: (v) => setState(() => _gender = v),
                                ),
                                primaryColor: c,
                                dark: dark,
                                onToggle: (i) => setState(() {
                                  _activeSection =
                                      _activeSection == i ? -1 : i;
                                }),
                              ),
                              const SizedBox(height: AppDimensions.spacingSection),

                              // Save button in flow (not positioned)
                              SetupSaveButtonWide(
                                primaryColor: c,
                                dark: dark,
                                canSave: _canSave,
                                saving: _saving,
                                hasExisting: _existing != null,
                                onSave: _save,
                              ),
                              const SizedBox(height: AppDimensions.spacingXxl),
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
                            const SizedBox(height: AppDimensions.spacingLg),

                            // Form sections
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 20),
                              child: Column(
                                children: [
                                  // Date section
                                  SetupFormCard(
                                    index: 0,
                                    activeSection: _activeSection,
                                    title: 'Birth Date',
                                    subtitle: _formatSelectedDate(),
                                    content: DatePickerSection(
                                      day: _day,
                                      month: _month,
                                      year: _year,
                                      primaryColor: c,
                                      dark: dark,
                                      dayController: _dayController,
                                      monthController: _monthController,
                                      yearController: _yearController,
                                      onDayChanged: (i) {
                                        final maxD = DateTime(_year, _month + 1, 0).day;
                                        final newDay = (i + 1).clamp(1, maxD);
                                        setState(() => _day = newDay);
                                        if (newDay != i + 1) {
                                          WidgetsBinding.instance.addPostFrameCallback((_) {
                                            if (mounted) _dayController.jumpToItem(newDay - 1);
                                          });
                                        }
                                      },
                                      onMonthChanged: (i) {
                                        _month = i + 1;
                                        final maxD = DateTime(_year, _month + 1, 0).day;
                                        final clampedDay = _day.clamp(1, maxD);
                                        setState(() => _day = clampedDay);
                                        WidgetsBinding.instance.addPostFrameCallback((_) {
                                          if (mounted && _dayController.selectedItem != clampedDay - 1) {
                                            _dayController.jumpToItem(clampedDay - 1);
                                          }
                                        });
                                      },
                                      onYearChanged: (i) {
                                        _year = DateTime.now().year - i;
                                        final maxD = DateTime(_year, _month + 1, 0).day;
                                        final clampedDay = _day.clamp(1, maxD);
                                        setState(() => _day = clampedDay);
                                        WidgetsBinding.instance.addPostFrameCallback((_) {
                                          if (mounted && _dayController.selectedItem != clampedDay - 1) {
                                            _dayController.jumpToItem(clampedDay - 1);
                                          }
                                        });
                                      },
                                    ),
                                    primaryColor: c,
                                    dark: dark,
                                    onToggle: (i) => setState(() {
                                      _activeSection =
                                          _activeSection == i ? -1 : i;
                                    }),
                                  ),

                                  const SizedBox(height: AppDimensions.spacingLg),

                                  // Time section
                                  SetupFormCard(
                                    index: 1,
                                    activeSection: _activeSection,
                                    title: 'Birth Time',
                                    subtitle: _formatSelectedTime(),
                                    content: TimePickerSection(
                                      hour: _hour,
                                      minute: _minute,
                                      isAM: _isAM,
                                      timeZone: _tz,
                                      primaryColor: c,
                                      dark: dark,
                                      hourController: _hourController,
                                      minuteController: _minuteController,
                                      ampmController: _ampmController,
                                      onHourChanged: (i) => setState(() => _hour = i + 1),
                                      onMinuteChanged: (i) => setState(() => _minute = i),
                                      onAmPmChanged: (i) => setState(() => _isAM = i == 0),
                                    ),
                                    primaryColor: c,
                                    dark: dark,
                                    onToggle: (i) => setState(() {
                                      _activeSection =
                                          _activeSection == i ? -1 : i;
                                    }),
                                  ),

                                  const SizedBox(height: AppDimensions.spacingLg),

                                  // Location section
                                  SetupFormCard(
                                    index: 2,
                                    activeSection: _activeSection,
                                    title: 'Birth Place',
                                    subtitle: _place ?? 'Search for your city',
                                    content: LocationSearchButton(
                                      place: _place,
                                      primaryColor: c,
                                      dark: dark,
                                      onTap: () => openLocationSearchOverlay(
                                        context: context,
                                        primaryColor: c,
                                        dark: dark,
                                        cardColor: dark ? Theme.of(context).colorScheme.surface : Colors.white,
                                        searchController: _searchController,
                                        resultsNotifier: _resultsNotifier,
                                        searchingNotifier: _searchingNotifier,
                                        onSearch: _search,
                                        onSelect: _select,
                                      ),
                                      onClear: () => setState(() {
                                        _place = null;
                                        _lat = null;
                                        _lng = null;
                                        _tz = null;
                                        _tzOffset = null;
                                        _searchController.clear();
                                      }),
                                    ),
                                    primaryColor: c,
                                    dark: dark,
                                    onToggle: (i) => setState(() {
                                      _activeSection =
                                          _activeSection == i ? -1 : i;
                                    }),
                                  ),

                                  const SizedBox(height: AppDimensions.spacingLg),

                                  // Gender section (required)
                                  SetupFormCard(
                                    index: 3,
                                    activeSection: _activeSection,
                                    title: 'Gender',
                                    subtitle: _gender ?? 'Select your gender',
                                    content: GenderSelectorSection(
                                      selectedGender: _gender,
                                      primaryColor: c,
                                      dark: dark,
                                      onGenderChanged: (v) => setState(() => _gender = v),
                                    ),
                                    primaryColor: c,
                                    dark: dark,
                                    onToggle: (i) => setState(() {
                                      _activeSection =
                                          _activeSection == i ? -1 : i;
                                    }),
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
        if (!_loading)
          SetupSaveButton(
            primaryColor: c,
            dark: dark,
            canSave: _canSave,
            saving: _saving,
            hasExisting: _existing != null,
            onSave: _save,
          ),
      ],
    );
  }

  Widget _buildHeader(Color c, bool dark) {
    return Container(
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
        final uri = Uri.parse('${ApiEndpoints.geocodingSearch}'
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
      } catch (_) {
        AppLogger.w('AstrologySetupPage: awardAstrologySetup call failed', category: LogCategory.general);
      }

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
        showCustomSnackBar(context, message: '$e', backgroundColor: Colors.red);
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
  // ignore: unused_element
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
  // ignore: unused_element
  List<String> get _years => List.generate(
      DateTime.now().year - 1920 + 1, (i) => '${DateTime.now().year - i}');
  // ignore: unused_element
  List<String> get _hours => List.generate(12, (i) => '${i + 1}');
  // ignore: unused_element
  List<String> get _minutes =>
      List.generate(60, (i) => i.toString().padLeft(2, '0'));
}

