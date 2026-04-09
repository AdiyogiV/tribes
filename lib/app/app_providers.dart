import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:aurogram/core/di/injection.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/shared/providers/theme_provider.dart';
import 'package:aurogram/features/auth/auth_service.dart';
import 'package:aurogram/shared/services/media/speech_recognition_service.dart';
import 'package:aurogram/shared/services/media/audio_input_service.dart';
import 'package:aurogram/features/ai_chat/domain/ai_chat_service.dart';
import 'package:aurogram/shared/services/location_service.dart';
import 'package:aurogram/features/feed/domain/feed_controller.dart';
import 'package:aurogram/features/ai_chat/domain/ai_chat_provider.dart';

/// Wraps the app widget tree with all required ChangeNotifierProviders.
class AppProviders {
  AppProviders._();

  static Widget wrap({required Widget child}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: locator<AuthService>()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => SpeechRecognitionService()),
        ChangeNotifierProvider(create: (_) => AudioInputService()),
        ChangeNotifierProvider(create: (_) => FeedController()),
        ChangeNotifierProvider(create: (_) => _createAiChatProvider()),
      ],
      child: child,
    );
  }

  static AiChatProvider _createAiChatProvider() {
    try {
      AiChatService? aiService;
      LocationService? locationService;

      try {
        aiService = locator<AiChatService>();
      } catch (e) {
        AppLogger.w('Failed to get AiChatService, using fallback: $e');
        aiService = AiChatService();
      }

      try {
        locationService = locator<LocationService>();
      } catch (e) {
        AppLogger.w('Failed to get LocationService, using fallback: $e');
        locationService = LocationService();
      }

      return AiChatProvider(
        service: aiService,
        locationService: locationService,
      );
    } catch (e) {
      AppLogger.e('Error creating AiChatProvider: $e');
      return AiChatProvider(
        service: AiChatService(),
        locationService: LocationService(),
      );
    }
  }
}
