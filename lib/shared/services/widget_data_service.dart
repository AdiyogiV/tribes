import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/features/astrology/presentation/widgets/cards/vedic_time_utils.dart';

/// Bridges panchang data from the Flutter app to native home screen widgets.
///
/// On **Android**, writes to `FlutterSharedPreferences` which is read by
/// [VedicDateWidgetProvider] in Kotlin.
///
/// On **iOS**, writes to standard UserDefaults (same keys the AuroWatch Widget
/// extension already reads — `auro_vedicDate`, `auro_samvatYear`).
///
/// Call [updateWidgetData] whenever fresh panchang/samvat data is available
/// (e.g. after daily insight load, after sky positions fetch, or when the
/// Baba page resolves its merged samvat).
class WidgetDataService {
  WidgetDataService._();
  static final instance = WidgetDataService._();

  /// Platform channel shared by iOS (AppDelegate) and Android (MainActivity).
  /// On iOS it pushes panchang into the App Group UserDefaults read by the
  /// AurogramWidget extension. On Android it refreshes / cancels the
  /// persistent lock-screen notification (the closest Android equivalent of
  /// an iOS lock-screen widget).
  static const _widgetChannel = MethodChannel('com.canay.dhaara/widget');

  // Pref key mirrored on Android — must match `PREF_ENABLED` in
  // VedicDateLockNotification.kt (without the "flutter." prefix that
  // shared_preferences adds automatically).
  static const _kLockNotifEnabled = 'widget_lockNotifEnabled';

  // Android keys (prefixed with "widget_" — Flutter's shared_preferences
  // automatically adds the "flutter." prefix when writing).
  static const _kLunarMonth = 'widget_lunarMonth';
  static const _kPaksha = 'widget_paksha';
  static const _kTithiName = 'widget_tithiName';
  static const _kVedicNumericDate = 'widget_vedicNumericDate';
  static const _kVedicDateFull = 'widget_vedicDateFull';
  static const _kSamvatYear = 'widget_samvatYear';

  // iOS keys (match existing AuroWatch Widget expectations)
  static const _kIosVedicDate = 'auro_vedicDate';
  static const _kIosSamvatYear = 'auro_samvatYear';

  /// Fingerprints of the last successful and currently in-flight writes.
  String? _lastWrittenDate;
  String? _pendingDate;

  /// Push the current panchang data to the native widget layer.
  ///
  /// [samvat] is the merged samvat/panchang map (same shape as
  /// `nakshatraSamvat` in BabaCosmicContent).
  ///
  /// Returns `true` if data was actually written (i.e. it changed).
  Future<bool> updateWidgetData(Map<String, dynamic>? samvat) async {
    if (samvat == null || samvat.isEmpty) {
      AppLogger.w('WidgetDataService: samvat is null or empty, skipping',
          category: LogCategory.general);
      return false;
    }

    // Build the same display strings the card widgets use.
    final fullVedicDate = VedicTimeUtils.buildFullVedicDate(samvat);
    final numericDate = VedicTimeUtils.buildVedicNumericDate(samvat);
    final samvatYear = VedicTimeUtils.buildSamvatYearNameOnly(samvat);

    // Extract individual components for the Android widget layout.
    final lunarMonth = samvat['lunar_month_full_name']?.toString() ??
        samvat['lunar_month_name']?.toString() ??
        samvat['lunarMonthFull']?.toString() ??
        samvat['lunarMonth']?.toString();

    final rawPaksha = samvat['paksha']?.toString() ??
        samvat['tithiPaksha']?.toString() ??
        '';
    String? paksha;
    if (rawPaksha.toLowerCase().contains('shukla')) {
      paksha = 'Shukla';
    } else if (rawPaksha.toLowerCase().contains('krishna')) {
      paksha = 'Krishna';
    }

    // Extract tithi name without paksha prefix.
    String? tithiName;
    if (fullVedicDate != null) {
      var remaining = fullVedicDate;
      if (lunarMonth != null) {
        remaining = remaining.replaceFirst(lunarMonth, '').trim();
      }
      if (paksha != null) {
        remaining = remaining.replaceFirst(paksha, '').trim();
      }
      if (remaining.isNotEmpty) tithiName = remaining;
    }

    // De-duplicate: skip write if the full date string hasn't changed.
    final dateFingerprint = '$fullVedicDate|$numericDate';
    if (dateFingerprint == _lastWrittenDate ||
        dateFingerprint == _pendingDate) {
      return false;
    }
    // Claim the fingerprint before the first await. Rebuilds can otherwise
    // start duplicate preferences and platform-channel writes concurrently.
    _pendingDate = dateFingerprint;

    try {
      final prefs = await SharedPreferences.getInstance();

      // Android widget keys
      if (lunarMonth != null) await prefs.setString(_kLunarMonth, lunarMonth);
      if (paksha != null) await prefs.setString(_kPaksha, paksha);
      if (tithiName != null) await prefs.setString(_kTithiName, tithiName);
      if (numericDate != null) {
        await prefs.setString(_kVedicNumericDate, numericDate);
      }
      if (fullVedicDate != null) {
        await prefs.setString(_kVedicDateFull, fullVedicDate);
      }
      if (samvatYear != null) {
        await prefs.setString(_kSamvatYear, samvatYear);
      }

      // iOS widget keys (shared with AuroWatch Widget extension)
      if (!kIsWeb && Platform.isIOS) {
        if (fullVedicDate != null) {
          await prefs.setString(_kIosVedicDate, fullVedicDate);
        }
        if (samvatYear != null) {
          await prefs.setString(_kIosSamvatYear, samvatYear);
        }

        // Push to the App Group UserDefaults that the home-screen widget
        // extension reads from. Standard SharedPreferences lives in the
        // app's private container and is invisible to the widget process.
        try {
          await _widgetChannel.invokeMethod<bool>('updateWidgetData', {
            'widget_lunarMonth': lunarMonth,
            'widget_paksha': paksha,
            'widget_tithiName': tithiName,
            'widget_vedicNumericDate': numericDate,
            'widget_vedicDateFull': fullVedicDate,
            'widget_samvatYear': samvatYear,
          });
        } on PlatformException catch (e) {
          AppLogger.w('WidgetDataService: iOS App Group write failed: ${e.code}',
              category: LogCategory.general,
              data: {'message': e.message});
        } on MissingPluginException {
          // Channel not yet wired (e.g., older build). Safe to ignore.
        }
      }

      // Android: nudge the persistent lock-screen notification (if the user
      // opted in) so its Ghati·Pala / Tithi values reflect the new write.
      if (!kIsWeb && Platform.isAndroid) {
        try {
          await _widgetChannel.invokeMethod<bool>('refreshLockNotification');
        } on PlatformException catch (e) {
          AppLogger.w('WidgetDataService: Android lock notif refresh failed: ${e.code}',
              category: LogCategory.general,
              data: {'message': e.message});
        } on MissingPluginException {
          // Pre-update build without the channel wired — safe to ignore.
        }
      }

      _lastWrittenDate = dateFingerprint;
      _pendingDate = null;

      AppLogger.i('WidgetDataService: wrote panchang to SharedPreferences',
          category: LogCategory.general,
          data: {
            'lunarMonth': lunarMonth,
            'paksha': paksha,
            'tithiName': tithiName,
            'numericDate': numericDate,
            'fullVedicDate': fullVedicDate,
            'samvatYear': samvatYear,
          });

      return true;
    } catch (e) {
      if (_pendingDate == dateFingerprint) _pendingDate = null;
      AppLogger.w('WidgetDataService: failed to write widget data: $e',
          category: LogCategory.general,
          data: {'error': e.toString()});
      return false;
    }
  }

  /// Whether the Android persistent lock-screen notification is currently
  /// opted into. Returns false on non-Android platforms.
  Future<bool> isLockNotificationEnabled() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kLockNotifEnabled) ?? false;
  }

  /// Opt the user into / out of the Android persistent lock-screen notification.
  /// On iOS this is a no-op — iOS users add a lock-screen widget via the
  /// system Customize UI instead.
  ///
  /// Caller is responsible for ensuring `POST_NOTIFICATIONS` permission is
  /// granted on Android 13+ before calling with `enabled: true`.
  Future<void> setLockNotificationEnabled(bool enabled) async {
    if (kIsWeb || !Platform.isAndroid) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kLockNotifEnabled, enabled);
    try {
      await _widgetChannel.invokeMethod<bool>(
        enabled ? 'refreshLockNotification' : 'cancelLockNotification',
      );
    } on PlatformException catch (e) {
      AppLogger.w('WidgetDataService: lock notif toggle failed: ${e.code}',
          category: LogCategory.general, data: {'message': e.message});
    } on MissingPluginException {
      // Channel not wired in this build — pref is persisted regardless.
    }
  }
}
