import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/core/config/api_endpoints.dart';
import 'package:aurogram/shared/models/astrology_profile.dart';
import 'package:aurogram/features/astrology/domain/astrology_service.dart';
import 'package:aurogram/features/onboarding/domain/baba_onboarding_tools.dart';
import 'package:aurogram/features/baba/domain/baba_tool_registry.dart';
import 'package:aurogram/features/baba/domain/baba_snapshot.dart';
import 'package:aurogram/features/baba/voice/voice_session_controller.dart';
import 'package:aurogram/features/astrology/presentation/pages/setup/date_picker_section.dart';
import 'package:aurogram/features/astrology/presentation/pages/setup/time_picker_section.dart';
import 'package:aurogram/features/astrology/presentation/pages/setup/location_search_section.dart';
import 'package:aurogram/features/astrology/presentation/pages/setup/birth_detail_normalizer.dart';
import 'package:aurogram/features/astrology/presentation/pages/setup/birth_form_widgets.dart';

/// Minimal, modern birth-details form.
///
/// Replaces the old chat-style step machine (welcome -> date -> time -> ...):
/// every field is visible at once so the user (or Baba) can fill them in ANY
/// order and review before submitting. Baba can co-fill by voice via the same
/// tool handlers, but he no longer drives a forced one-question-at-a-time
/// conversation and no longer auto-submits — after he fills, he and the form
/// "part ways": the user reviews and taps Reveal themselves.
class ImmersiveSetupPage extends StatefulWidget {
  const ImmersiveSetupPage({super.key});

  @override
  State<ImmersiveSetupPage> createState() => _ImmersiveSetupPageState();
}

class _ImmersiveSetupPageState extends State<ImmersiveSetupPage>
    with BabaScreenAware<ImmersiveSetupPage> {
  final _service = AstrologyService();
  final _voice = VoiceSessionController();

  // ── Draft state (co-authored by the pickers AND Baba's voice tools) ──────
  AstrologyProfile? _existing;
  int _day = 15, _month = 6, _year = 1995;
  int _hour = 6, _minute = 0;
  bool _isAM = true;
  bool _dateSet = false, _timeSet = false;
  String? _place;
  double? _lat, _lng, _tzOffset;
  String? _tz, _gender;
  bool _saving = false;
  bool _handingOffVoice = false;

  int get _hour24 =>
      _isAM ? (_hour == 12 ? 0 : _hour) : (_hour == 12 ? 12 : _hour + 12);

  bool get _canSubmit => _dateSet && _timeSet && _place != null;

  // ── Baba page awareness ──────────────────────────────────────────────────
  @override
  String get babaScreenKey => 'birthDetails';

  @override
  BabaSnapshot babaSnapshot() {
    // What is still needed drives BOTH the sub-step Baba is on and the actions
    // he can meaningfully take next — so he always knows the one right move
    // instead of guessing which field to ask for.
    final actions = <String>[];
    if (!_dateSet) actions.add(BabaOnboardingTools.setBirthDate);
    if (!_timeSet) actions.add(BabaOnboardingTools.setBirthTime);
    if (_place == null) actions.add(BabaOnboardingTools.setBirthPlace);
    if (_gender == null) actions.add(BabaOnboardingTools.setGender);
    if (_canSubmit) actions.add(BabaOnboardingTools.submitBirthDetails);
    final step = _saving
        ? 'saving'
        : !_dateSet
            ? 'collectDate'
            : !_timeSet
                ? 'collectTime'
                : _place == null
                    ? 'collectPlace'
                    : 'readyToSubmit';
    return BabaSnapshot(
      status: _saving ? BabaScreenStatus.loading : BabaScreenStatus.ready,
      step: step,
      headline: _saving
          ? 'Saving birth details and building the chart'
          : 'The birth-details setup form (date, time, place, gender)',
      facts: {
        'dateSet': _dateSet,
        if (_dateSet)
          'date':
              '$_year-${_month.toString().padLeft(2, '0')}-${_day.toString().padLeft(2, '0')}',
        'timeSet': _timeSet,
        if (_timeSet)
          'time':
              '${_hour24.toString().padLeft(2, '0')}:${_minute.toString().padLeft(2, '0')}',
        'placeSet': _place != null,
        if (_place != null) 'place': _place,
        if (_gender != null) 'gender': _gender,
        'canSubmit': _canSubmit,
        'voiceActive': _voiceActive,
      },
      canProceed: _canSubmit && !_saving,
      blockedReason: _saving
          ? 'the chart is being built'
          : _canSubmit
              ? null
              : 'still need ${actions.contains(BabaOnboardingTools.setBirthDate) ? 'date' : actions.contains(BabaOnboardingTools.setBirthTime) ? 'time' : 'place'}',
      availableActions: actions,
    );
  }

  @override
  void initState() {
    super.initState();
    _loadExisting();

    // FACTS ONLY. HOW Baba co-fills, confirms and submits is owned by the CX
    // playbook's Onboarding section (voice-relay/src/cx_tools.js) - the single
    // source of truth. Here we just tell him WHICH screen is now open and what
    // it contains, so he can act on it per the playbook.
    _voice.directiveOverride =
        '[SCREEN CONTEXT] screen=birthDetails (the birth-details setup form is '
        'now open, with fields for date, time, place and gender all visible). '
        'Lead per your playbook.';
    _voice.addListener(_onVoiceChanged);
    _bindBabaTools();
  }

  void _onVoiceChanged() {
    if (mounted) setState(() {});
  }

  bool get _voiceActive =>
      _voice.state == VoiceCallState.connecting ||
      _voice.state == VoiceCallState.listening ||
      _voice.state == VoiceCallState.thinking ||
      _voice.state == VoiceCallState.speaking;

  Future<void> _toggleVoice() async {
    HapticFeedback.mediumImpact();
    if (_voiceActive) {
      await _voice.hangUp();
    } else {
      await _voice.start();
    }
  }

  // ── Baba tool handlers (fill the same draft; tolerant of natural input) ───

  /// The GROUND TRUTH of the form after any action, so Baba can never drift
  /// from reality: what is captured, what is still missing, can we submit.
  /// Every set*/submit handler returns this so the model reads the real state
  /// instead of assuming its last action worked.
  Map<String, dynamic> _babaFormState() {
    final missing = <String>[
      if (!_dateSet) 'date',
      if (!_timeSet) 'time',
      if (_place == null) 'place',
    ];
    return {
      'captured': {
        'date': _dateSet,
        'time': _timeSet,
        'place': _place != null,
        'gender': _gender != null,
      },
      'missing': missing,
      'canSubmit': _canSubmit,
    };
  }

  void _bindBabaTools() {
    final reg = BabaToolRegistry.instance;

    reg.bindHandler(BabaOnboardingTools.setBirthDate, (args) async {
      final y = (args['year'] as num?)?.toInt();
      final mo = (args['month'] as num?)?.toInt();
      final d = (args['day'] as num?)?.toInt();
      if (y == null || mo == null || d == null) {
        return {'ok': false, 'set': false, 'reason': 'need year, month and day', ..._babaFormState()};
      }
      setState(() {
        _year = y;
        _month = mo;
        _day = d;
        _dateSet = true;
      });
      return {'ok': true, 'set': true, 'date': '$y-$mo-$d', ..._babaFormState()};
    });

    reg.bindHandler(BabaOnboardingTools.setBirthTime, (args) async {
      final h24 = (args['hour24'] as num?)?.toInt();
      final min = (args['minute'] as num?)?.toInt() ?? 0;
      if (h24 == null || h24 < 0 || h24 > 23) {
        return {'ok': false, 'set': false, 'reason': 'need hour24 (0-23)', ..._babaFormState()};
      }
      setState(() {
        _isAM = h24 < 12;
        _hour = h24 == 0 ? 12 : (h24 > 12 ? h24 - 12 : h24);
        _minute = min;
        _timeSet = true;
      });
      return {
        'ok': true,
        'set': true,
        'time':
            '${h24.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')}',
        ..._babaFormState(),
      };
    });

    reg.bindHandler(BabaOnboardingTools.setBirthPlace, (args) async {
      final city = (args['city'] as String?)?.trim();
      if (city == null || city.isEmpty) {
        return {'ok': false, 'set': false, 'reason': 'need a city name', ..._babaFormState()};
      }
      final geo = await _geocode(city);
      if (geo == null) {
        return {
          'ok': false,
          'set': false,
          'reason':
              'could not find "$city" - ask them to say the city in English',
          ..._babaFormState(),
        };
      }
      // The geocode is async — the user may have left the setup screen while it
      // was in flight. Touching setState after dispose throws; bail cleanly and
      // tell Baba the action didn't land instead of crashing.
      if (!mounted) {
        return {
          'ok': false,
          'set': false,
          'reason': 'the setup screen is no longer open',
        };
      }
      setState(() {
        _place = geo['label'] as String?;
        _lat = geo['lat'] as double?;
        _lng = geo['lng'] as double?;
        _tz = geo['tz'] as String?;
      });
      return {'ok': true, 'set': true, 'resolved': _place, ..._babaFormState()};
    });

    reg.bindHandler(BabaOnboardingTools.setGender, (args) async {
      final code = BirthDetailNormalizer.gender(args['gender'] as String?);
      if (code == null) {
        return {
          'ok': false,
          'set': false,
          'reason': 'gender must be male, female or other',
          ..._babaFormState(),
        };
      }
      setState(() => _gender = BirthDetailNormalizer.genderLabel(code));
      return {'ok': true, 'set': true, 'gender': _gender, ..._babaFormState()};
    });

    reg.bindHandler(BabaOnboardingTools.submitBirthDetails, (args) async {
      // Un-fakeable gate: refuse (with the exact missing fields) unless the
      // form is genuinely complete. This is what stops Baba claiming the chart
      // is being calculated when a field was silently dropped.
      if (!_canSubmit) {
        return {
          'ok': false,
          'submitted': false,
          'reason': 'CANNOT submit - still missing these fields; collect them '
              'first, do NOT say the chart is being prepared',
          ..._babaFormState(),
        };
      }
      await _saveProfile();
      return {'ok': true, 'submitted': true, ..._babaFormState()};
    });
  }

  /// Resolve a city to coordinates + IANA timezone (open-meteo).
  Future<Map<String, dynamic>?> _geocode(String query) async {
    try {
      final uri = Uri.parse(ApiEndpoints.geocodingSearch).replace(
        queryParameters: {
          'name': query,
          'count': '1',
          'language': 'en',
          'format': 'json',
        },
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 5));
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final items = data['results'] as List? ?? [];
      if (items.isEmpty) return null;
      final r = items.first as Map<String, dynamic>;
      final name = (r['name'] as String?) ?? query;
      final admin1 = (r['admin1'] as String?) ?? '';
      final country = (r['country'] as String?) ?? '';
      return {
        'label': [name, admin1, country].where((s) => s.isNotEmpty).join(', '),
        'lat': (r['latitude'] as num?)?.toDouble(),
        'lng': (r['longitude'] as num?)?.toDouble(),
        'tz': r['timezone'] as String?,
      };
    } catch (e) {
      AppLogger.w('Baba geocode failed: $e');
      return null;
    }
  }

  Future<void> _loadExisting() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final p = await _service.getProfile(uid);
    if (p != null && mounted) {
      setState(() {
        _existing = p;
        if (p.birthDate != null) {
          _day = p.birthDate!.day;
          _month = p.birthDate!.month;
          _year = p.birthDate!.year;
          _dateSet = true;
        }
        if (p.birthTime != null) {
          final parts = p.birthTime!.split(':');
          if (parts.length >= 2) {
            final h = int.tryParse(parts[0]) ?? 6;
            _minute = int.tryParse(parts[1]) ?? 0;
            _isAM = h < 12;
            _hour = h == 0 ? 12 : (h > 12 ? h - 12 : h);
            _timeSet = true;
          }
        }
        _place = p.birthPlace;
        _lat = p.birthLatitude;
        _lng = p.birthLongitude;
        _tz = p.timeZone;
        _tzOffset = p.timeZoneOffset;
        _gender = p.gender;
      });
    }
  }

  Future<void> _saveProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || !_canSubmit) return;
    setState(() => _saving = true);
    try {
      final p = AstrologyProfile(
        birthDate: DateTime(_year, _month, _day),
        birthYear: _year,
        birthMonth: _month,
        birthDay: _day,
        birthTime:
            '${_hour24.toString().padLeft(2, '0')}:${_minute.toString().padLeft(2, '0')}',
        birthPlace: _place!,
        birthLatitude: _lat,
        birthLongitude: _lng,
        timeZone: _tz,
        timeZoneOffset: _tzOffset,
        gender: _gender,
        isEnabled: true,
        visibility: AstroVisibility.public,
        createdAt: _existing?.createdAt ?? DateTime.now(),
      );
      await _service.saveProfile(p);
      _service.calculateAndSaveAll(uid);
      HapticFeedback.heavyImpact();
      if (mounted) {
        _handingOffVoice = true;
        context.pushReplacement('/onboarding/complete',
            extra: {'hasBirthDetails': true, 'isUpdate': _existing != null});
      }
    } catch (e) {
      AppLogger.e('Save error: $e');
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── UI ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = AppTheme.primaryColor;
    final dateLabel = _dateSet
        ? '${_day.toString().padLeft(2, '0')} ${_monthName(_month)} $_year'
        : null;
    final timeLabel = _timeSet
        ? '${_hour.toString().padLeft(2, '0')}:${_minute.toString().padLeft(2, '0')} ${_isAM ? 'AM' : 'PM'}'
        : null;

    return Scaffold(
      backgroundColor: Colors.black, // Immersive dark background
      appBar: AppBar(
        title: const Text(''),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Ambient generative AI glow based on voice state
          AnimatedPositioned(
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeInOut,
            top: _voiceActive ? 100 : -200,
            left: 0, right: 0,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 700),
              opacity: _voiceActive ? 0.2 : 0.0,
              child: Container(
                height: 400,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: primary, blurRadius: 150, spreadRadius: 100)
                  ]
                )
              )
            )
          ),

          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 40, 24, 400), // Massive bottom padding so user can always scroll up
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Text(
                      "Cosmic Origin",
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Dictate to Aurobhatt, or tap a field to enter manually.",
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white54,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Compact "Cosmic Passport" Card
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Row 1: Date & Time
                          Row(
                            children: [
                              Expanded(child: _buildCompactField(icon: Icons.calendar_today_rounded, title: "DATE", value: dateLabel, placeholder: "DD MM YYYY", isFilled: _dateSet, onTap: _openDatePicker)),
                              Container(width: 1, height: 70, color: Colors.white.withValues(alpha: 0.08)),
                              Expanded(child: _buildCompactField(icon: Icons.access_time_rounded, title: "TIME", value: timeLabel, placeholder: "HH:MM", isFilled: _timeSet, onTap: _openTimePicker)),
                            ],
                          ),
                          Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),
                          // Row 2: Place
                          _buildCompactField(icon: Icons.place_rounded, title: "PLACE", value: _place, placeholder: "City, Country", isFilled: _place != null, onTap: _openPlaceSearch),
                          Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),
                          // Row 3: Gender
                          _buildCompactField(icon: Icons.person_outline_rounded, title: "GENDER", value: _gender, placeholder: "Optional", isFilled: _gender != null, onTap: _openGenderSheet),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    // Action Area (Voice / Submit)
                    _buildActionArea(primary),
                  ],
                ),
              ),
            ),
          ),
          if (_saving)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x99000000),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCompactField({
    required IconData icon,
    required String title,
    required String? value,
    required String placeholder,
    required bool isFilled,
    required VoidCallback onTap,
  }) {
    final primary = AppTheme.primaryColor;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: isFilled ? primary : Colors.white38),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isFilled ? primary : Colors.white38,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              isFilled ? value! : placeholder,
              style: TextStyle(
                fontSize: 16,
                color: isFilled ? Colors.white : Colors.white24,
                fontWeight: isFilled ? FontWeight.w600 : FontWeight.w400,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionArea(Color primary) {
    // Submit always wins: once the chart is fillable, show it even mid-call so
    // the user can reveal the moment Baba finishes dictating.
    if (_canSubmit) {
      return SizedBox(
        height: 60,
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _saving ? null : _saveProfile,
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
          child: const Text('Reveal My Chart', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        ),
      );
    }

    // A call is live but not yet fillable: say NOTHING here. Aurobhatt's global
    // overlay (status pill + controls) already shows he's listening/speaking,
    // so a second "processing" bar is just redundant clutter that crowds the
    // form. Keeping this empty is what frees the vertical space.
    if (_voiceActive) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: _toggleVoice,
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.mic_rounded, color: primary),
            const SizedBox(width: 12),
            const Text(
              "Tap to dictate all details",
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openGenderSheet() async {
    String? selected = _gender;
    await BirthFormWidgets.pickerSheet(
      context: context,
      title: 'Gender (Optional)',
      child: StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Column(
            children: ['MALE', 'FEMALE', 'OTHER'].map((code) {
              final label = BirthDetailNormalizer.genderLabel(code);
              final isSelected = selected == label;
              return ListTile(
                title: Text(label, style: const TextStyle(color: Colors.white)),
                trailing: isSelected ? Icon(Icons.check, color: AppTheme.primaryColor) : null,
                onTap: () => setSheetState(() => selected = label),
              );
            }).toList(),
          );
        }
      ),
      onDone: () {
         if (selected != null) setState(() => _gender = selected);
      },
    );
  }

  String _monthName(int m) => const [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ][(m - 1).clamp(0, 11)];

  // ── Pickers (tap-to-open bottom sheets, reusing the wheel sections) ────────
  Future<void> _openDatePicker() async {
    final dayC = FixedExtentScrollController(initialItem: _day - 1);
    final monC = FixedExtentScrollController(initialItem: _month - 1);
    final yearC =
        FixedExtentScrollController(initialItem: DateTime.now().year - _year);
    var d = _day, mo = _month, y = _year;
    await BirthFormWidgets.pickerSheet(
      context: context,
      title: 'Birth date',
      child: DatePickerSection(
        day: _day, month: _month, year: _year,
        primaryColor: AppTheme.primaryColor, dark: false,
        dayController: dayC, monthController: monC, yearController: yearC,
        onDayChanged: (v) => d = v + 1,
        onMonthChanged: (v) => mo = v + 1,
        onYearChanged: (v) => y = DateTime.now().year - v,
      ),
      onDone: () => setState(() {
        _day = d;
        _month = mo;
        _year = y;
        _dateSet = true;
      }),
    );
    dayC.dispose();
    monC.dispose();
    yearC.dispose();
  }

  Future<void> _openTimePicker() async {
    final hourC = FixedExtentScrollController(initialItem: _hour - 1);
    final minC = FixedExtentScrollController(initialItem: _minute);
    final ampmC = FixedExtentScrollController(initialItem: _isAM ? 0 : 1);
    var h = _hour, mi = _minute, am = _isAM;
    await BirthFormWidgets.pickerSheet(
      context: context,
      title: 'Birth time',
      child: TimePickerSection(
        hour: _hour, minute: _minute, isAM: _isAM,
        primaryColor: AppTheme.primaryColor, dark: false,
        hourController: hourC, minuteController: minC, ampmController: ampmC,
        timeZone: _tz,
        onHourChanged: (v) => h = v + 1,
        onMinuteChanged: (v) => mi = v,
        onAmPmChanged: (v) => am = v == 0,
      ),
      onDone: () => setState(() {
        _hour = h;
        _minute = mi;
        _isAM = am;
        _timeSet = true;
      }),
    );
    hourC.dispose();
    minC.dispose();
    ampmC.dispose();
  }

  void _openPlaceSearch() {
    openLocationSearchOverlay(
      context: context,
      primaryColor: AppTheme.primaryColor,
      dark: Theme.of(context).brightness == Brightness.dark,
      cardColor: Theme.of(context).colorScheme.surface,
      onSelect: (r) {
        final name = (r['name'] as String?) ?? '';
        final admin1 = (r['admin1'] as String?) ?? '';
        final country = (r['country'] as String?) ?? '';
        setState(() {
          _place = [name, admin1, country].where((s) => s.isNotEmpty).join(', ');
          _lat = (r['latitude'] as num?)?.toDouble();
          _lng = (r['longitude'] as num?)?.toDouble();
          _tz = r['timezone'] as String?;
        });
      },
    );
  }

  @override
  void dispose() {
    final reg = BabaToolRegistry.instance;
    reg.unbindHandler(BabaOnboardingTools.setBirthDate);
    reg.unbindHandler(BabaOnboardingTools.setBirthTime);
    reg.unbindHandler(BabaOnboardingTools.setBirthPlace);
    reg.unbindHandler(BabaOnboardingTools.setGender);
    reg.unbindHandler(BabaOnboardingTools.submitBirthDetails);
    _voice.removeListener(_onVoiceChanged);
    _voice.directiveOverride = null;
    if (_voiceActive && !_handingOffVoice) _voice.hangUp();
    super.dispose();
  }
}
