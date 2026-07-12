import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/shared/models/astrology_profile.dart';
import 'package:aurogram/features/astrology/domain/astrology_service.dart';
import 'package:aurogram/features/onboarding/presentation/widgets/star_field_painter.dart';
import 'package:aurogram/features/astrology/presentation/pages/setup/date_picker_section.dart';
import 'package:aurogram/features/astrology/presentation/pages/setup/time_picker_section.dart';
import 'package:aurogram/features/astrology/presentation/pages/setup/location_search_section.dart';
import 'package:aurogram/features/astrology/presentation/pages/setup/gender_selector_section.dart';

enum _ChatStep { welcome, date, time, location, gender, saving }

class ImmersiveSetupPage extends StatefulWidget {
  const ImmersiveSetupPage({super.key});

  @override
  State<ImmersiveSetupPage> createState() => _ImmersiveSetupPageState();
}

class _ImmersiveSetupPageState extends State<ImmersiveSetupPage> with TickerProviderStateMixin {
  final _service = AstrologyService();
  final _scrollController = ScrollController();
  
  _ChatStep _step = _ChatStep.welcome;
  final List<_ChatMessage> _messages = [];
  bool _isTyping = true;
  bool _saving = false;

  // Data
  AstrologyProfile? _existing;
  late int _day, _month, _year;
  late int _hour, _minute;
  bool _isAM = true;
  String? _place;
  double? _lat, _lng, _tzOffset;
  String? _tz, _gender;

  // Pickers controllers
  late FixedExtentScrollController _dayController;
  late FixedExtentScrollController _monthController;
  late FixedExtentScrollController _yearController;
  late FixedExtentScrollController _hourController;
  late FixedExtentScrollController _minuteController;
  late FixedExtentScrollController _ampmController;

  @override
  void initState() {
    super.initState();
    _day = 15; _month = 6; _year = 1995;
    _hour = 6; _minute = 0;
    
    _dayController = FixedExtentScrollController(initialItem: _day - 1);
    _monthController = FixedExtentScrollController(initialItem: _month - 1);
    _yearController = FixedExtentScrollController(initialItem: DateTime.now().year - _year);
    _hourController = FixedExtentScrollController(initialItem: _hour - 1);
    _minuteController = FixedExtentScrollController(initialItem: _minute);
    _ampmController = FixedExtentScrollController(initialItem: _isAM ? 0 : 1);

    _loadExisting();
    _startSequence();
  }

  Future<void> _loadExisting() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final p = await _service.getProfile(uid);
    if (p != null && mounted) {
      _existing = p;
      if (p.birthDate != null) {
        _day = p.birthDate!.day; _month = p.birthDate!.month; _year = p.birthDate!.year;
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
      _place = p.birthPlace; _lat = p.birthLatitude; _lng = p.birthLongitude;
      _tz = p.timeZone; _tzOffset = p.timeZoneOffset; _gender = p.gender;
      
      _dayController.jumpToItem(_day - 1);
      _monthController.jumpToItem(_month - 1);
      _yearController.jumpToItem(DateTime.now().year - _year);
      _hourController.jumpToItem(_hour - 1);
      _minuteController.jumpToItem(_minute);
      _ampmController.jumpToItem(_isAM ? 0 : 1);
    }
  }

  Future<void> _startSequence() async {
    await Future.delayed(const Duration(milliseconds: 500));
    _addSystemMessage("Welcome. To read your stars, I need to know when you entered the world.");
    await Future.delayed(const Duration(milliseconds: 1500));
    _addSystemMessage("What is your birth date?");
    setState(() { _isTyping = false; _step = _ChatStep.date; });
    _scrollToBottom();
  }

  void _addSystemMessage(String text, {Widget? widgetContent}) {
    setState(() {
      _messages.add(_ChatMessage(isSystem: true, text: text, widget: widgetContent));
    });
    _scrollToBottom();
  }

  void _addUserMessage(String text) {
    setState(() {
      _messages.add(_ChatMessage(isSystem: false, text: text));
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 200,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _confirmDate() {
    _addUserMessage("$_month/$_day/$_year");
    setState(() { _isTyping = true; _step = _ChatStep.time; });
    Future.delayed(const Duration(milliseconds: 1200), () {
      _addSystemMessage("And the exact time? (Even an estimate helps)");
      setState(() => _isTyping = false);
      _scrollToBottom();
    });
  }

  void _confirmTime() {
    final ampm = _isAM ? "AM" : "PM";
    final m = _minute.toString().padLeft(2, '0');
    _addUserMessage("$_hour:$m $ampm");
    setState(() { _isTyping = true; _step = _ChatStep.location; });
    Future.delayed(const Duration(milliseconds: 1200), () {
      _addSystemMessage("Lastly, where were you born?");
      setState(() => _isTyping = false);
      _scrollToBottom();
    });
  }

  void _confirmLocation() {
    if (_place == null) return;
    _addUserMessage(_place!);
    setState(() { _isTyping = true; _step = _ChatStep.gender; });
    Future.delayed(const Duration(milliseconds: 1200), () {
      _addSystemMessage("Almost done. How do you identify? (This helps with traditional chart reading)");
      setState(() => _isTyping = false);
      _scrollToBottom();
    });
  }

  void _confirmGender(String g) {
    _gender = g;
    _addUserMessage(g);
    setState(() { _isTyping = true; _step = _ChatStep.saving; });
    Future.delayed(const Duration(milliseconds: 1500), () {
      _addSystemMessage("Reading your cosmic blueprint...");
      _saveProfile();
    });
  }

  Future<void> _saveProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _saving = true);

    try {
      final hour24 = _isAM ? (_hour == 12 ? 0 : _hour) : (_hour == 12 ? 12 : _hour + 12);
      // Note: timeZoneOffset is derived server-side (astro_sync computeOffsetHours)
      // from the IANA timeZone name at the birth date, so DST is handled correctly.
      final p = AstrologyProfile(
        birthDate: DateTime(_year, _month, _day),
        birthYear: _year,
        birthMonth: _month,
        birthDay: _day,
        birthTime: '${hour24.toString().padLeft(2, '0')}:${_minute.toString().padLeft(2, '0')}',
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
      // Kick off backend chart calculation in the background.
      _service.calculateAndSaveAll(uid);
      HapticFeedback.heavyImpact();
      if (mounted) {
        context.pushReplacement('/onboarding/complete',
            extra: {'hasBirthDetails': true, 'isUpdate': false});
      }
    } catch (e) {
      AppLogger.e('Save error: $e');
      setState(() { _saving = false; _step = _ChatStep.gender; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = AppTheme.primaryColor;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: StarFieldPainter(rotation: 0.0, color: Colors.white.withValues(alpha: 0.15))),
          ),
          Positioned.fill(
            child: SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                      itemCount: _messages.length + (_isTyping ? 1 : 0) + 1, // +1 for the active input widget
                      itemBuilder: (context, index) {
                        if (index < _messages.length) {
                          return _buildChatBubble(_messages[index], primary);
                        }
                        if (index == _messages.length && _isTyping) {
                          return _buildTypingIndicator(primary);
                        }
                        if (index == _messages.length + (_isTyping ? 1 : 0)) {
                          return _buildActivePicker(primary, isDark);
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  _buildInputBar(primary),
                ],
              ),
            ),
          ),
          if (_saving)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildChatBubble(_ChatMessage msg, Color primary) {
    return Align(
      alignment: msg.isSystem ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: msg.isSystem ? Colors.white.withValues(alpha: 0.1) : primary.withValues(alpha: 0.8),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(msg.isSystem ? 0 : 16),
            bottomRight: Radius.circular(msg.isSystem ? 16 : 0),
          ),
        ),
        child: Text(msg.text, style: const TextStyle(color: Colors.white, fontSize: 16)),
      ),
    );
  }

  Widget _buildTypingIndicator(Color primary) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16), topRight: Radius.circular(16),
            bottomLeft: Radius.circular(0), bottomRight: Radius.circular(16),
          ),
        ),
        child: const SizedBox(
          width: 40, height: 10,
          child: Center(child: Text("...", style: TextStyle(color: Colors.white, letterSpacing: 2))),
        ),
      ),
    );
  }

  Widget _buildActivePicker(Color primary, bool isDark) {
    if (_isTyping || _saving) return const SizedBox.shrink();

    Widget content;
    VoidCallback onNext;
    String btnText;

    switch (_step) {
      case _ChatStep.date:
        content = DatePickerSection(
          day: _day, month: _month, year: _year,
          primaryColor: primary, dark: true,
          dayController: _dayController, monthController: _monthController, yearController: _yearController,
          onDayChanged: (v) => _day = v + 1,
          onMonthChanged: (v) => _month = v + 1,
          onYearChanged: (v) => _year = DateTime.now().year - v,
        );
        onNext = _confirmDate;
        btnText = "Confirm Date";
        break;
      case _ChatStep.time:
        content = TimePickerSection(
          hour: _hour, minute: _minute, isAM: _isAM,
          primaryColor: primary, dark: true,
          hourController: _hourController, minuteController: _minuteController, ampmController: _ampmController,
          timeZone: _tz,
          onHourChanged: (v) => _hour = v + 1,
          onMinuteChanged: (v) => _minute = v,
          onAmPmChanged: (v) => _isAM = v == 0,
        );
        onNext = _confirmTime;
        btnText = "Confirm Time";
        break;
      case _ChatStep.location:
        return Padding(
          padding: const EdgeInsets.only(bottom: 24.0, top: 12.0),
          child: LocationSearchButton(
            place: _place,
            primaryColor: primary,
            dark: true,
            onClear: () => setState(() {
              _place = null; _lat = null; _lng = null; _tz = null; _tzOffset = null;
            }),
            onTap: () => openLocationSearchOverlay(
              context: context,
              primaryColor: primary,
              dark: true,
              cardColor: Colors.black,
              onSelect: (r) {
                final name = (r['name'] as String?) ?? '';
                final admin1 = (r['admin1'] as String?) ?? '';
                final country = (r['country'] as String?) ?? '';
                final label =
                    [name, admin1, country].where((s) => s.isNotEmpty).join(', ');
                setState(() {
                  _place = label;
                  _lat = (r['latitude'] as num?)?.toDouble();
                  _lng = (r['longitude'] as num?)?.toDouble();
                  _tz = r['timezone'] as String?;
                });
                _confirmLocation();
              },
            ),
          ),
        );
      case _ChatStep.gender:
        return Padding(
          padding: const EdgeInsets.only(bottom: 24.0, top: 12.0),
          child: GenderSelectorSection(
            selectedGender: _gender, primaryColor: primary, dark: true,
            onGenderChanged: (g) => _confirmGender(g),
          ),
        );
      default:
        return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0, top: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          content,
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onNext,
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: Text(btnText, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar(Color primary) {
    // A fake disabled voice/text input to maintain the chat illusion
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(24),
              ),
              alignment: Alignment.centerLeft,
              child: Text("Use the cards above to answer...", style: TextStyle(color: Colors.white.withValues(alpha: 0.4))),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            height: 48, width: 48,
            decoration: BoxDecoration(shape: BoxShape.circle, color: primary.withValues(alpha: 0.2)),
            child: Icon(Icons.mic, color: primary),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _dayController.dispose(); _monthController.dispose(); _yearController.dispose();
    _hourController.dispose(); _minuteController.dispose(); _ampmController.dispose();
    super.dispose();
  }
}

class _ChatMessage {
  final bool isSystem;
  final String text;
  final Widget? widget;
  _ChatMessage({required this.isSystem, required this.text, this.widget});
}
